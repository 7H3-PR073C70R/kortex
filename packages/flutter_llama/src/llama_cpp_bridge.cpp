/*
 * Flutter Llama - llama.cpp Bridge (Portable C++ for FFI)
 * 
 * Provides an extern "C" API compatible with dart:ffi on Windows, Linux, and macOS.
 */

#include <string>
#include <vector>
#include <mutex>
#include <iostream>
#include <algorithm>
#include <cstring>
#include <cstdarg>
#include <cstdio>

#include <type_traits>
#include "llama.h"

#if defined(_WIN32)
#define FLUTTER_LLAMA_EXPORT __declspec(dllexport)
#else
#define FLUTTER_LLAMA_EXPORT __attribute__((visibility("default")))
#endif

// Helper to call llama_sampler_init_penalties with 4 or 5 args depending on llama.h version
template <typename F>
static auto call_penalties(F fn, int32_t n_vocab, int32_t last_n, float repeat, float freq, float present) {
    if constexpr (std::is_invocable_v<F, int32_t, int32_t, float, float, float>) {
        return fn(n_vocab, last_n, repeat, freq, present);
    } else {
        return fn(last_n, repeat, freq, present);
    }
}

// Global state
static llama_model* g_model = nullptr;
static llama_context* g_context = nullptr;
static const llama_vocab* g_vocab = nullptr;
static llama_sampler* g_sampler = nullptr;
static std::mutex g_mutex;
static bool g_should_stop = false;
static int g_stream_n_pos = 0;
static int g_stream_n_generated = 0;
static int g_stream_max_tokens = 0;

static void log_info(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    printf("[llama_cpp_bridge] ");
    vprintf(fmt, args);
    printf("\n");
    fflush(stdout);
    va_end(args);
}

static void log_error(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    fprintf(stderr, "[llama_cpp_bridge ERROR] ");
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    fflush(stderr);
    va_end(args);
}

extern "C" {

FLUTTER_LLAMA_EXPORT bool llama_init_model(
    const char* model_path,
    int32_t n_threads,
    int32_t n_gpu_layers,
    int32_t context_size,
    int32_t batch_size,
    bool use_gpu,
    bool verbose
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (!model_path) {
        log_error("model_path is null");
        return false;
    }

    llama_backend_init();

    log_info("Initializing model: %s", model_path);
    log_info("Threads: %d, GPU layers: %d, Context: %d", 
             n_threads, n_gpu_layers, context_size);
    
    // Free existing model if any
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    if (g_context) {
        llama_free(g_context);
        g_context = nullptr;
    }
    if (g_model) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
    
    // Set up model parameters
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = use_gpu ? n_gpu_layers : 0;
    
    // Load model
    g_model = llama_model_load_from_file(model_path, model_params);
    if (!g_model) {
        log_error("Failed to load model from: %s", model_path);
        return false;
    }
    
    // Get vocab
    g_vocab = llama_model_get_vocab(g_model);
    
    // Create context
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = context_size;
    ctx_params.n_batch = batch_size;
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;
    
    g_context = llama_init_from_model(g_model, ctx_params);
    if (!g_context) {
        log_error("Failed to create context");
        llama_model_free(g_model);
        g_model = nullptr;
        return false;
    }
    
    // Initialize sampler chain
    auto sparams = llama_sampler_chain_default_params();
    sparams.no_perf = false;
    g_sampler = llama_sampler_chain_init(sparams);
    
    // Add samplers with cross-version penalty initialization
    const int32_t n_vocab = g_vocab ? llama_vocab_n_tokens(g_vocab) : 32000;
    llama_sampler_chain_add(g_sampler, call_penalties(llama_sampler_init_penalties, n_vocab, 64, 1.15f, 0.0f, 0.0f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(0.8f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_p(0.95f, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(1234));
    
    log_info("Model loaded successfully. Context size: %d", llama_n_ctx(g_context));
    return true;
}

FLUTTER_LLAMA_EXPORT bool llama_generate(
    const char* prompt,
    float temperature,
    float top_p,
    int32_t top_k,
    int32_t max_tokens,
    float repeat_penalty,
    char* output,
    int32_t output_size,
    int32_t* tokens_generated
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (!g_model || !g_context || !g_vocab) {
        log_error("Model not loaded");
        return false;
    }
    
    log_info("Generating with prompt: %.50s...", prompt);
    
    std::string prompt_text(prompt);
    
    // Tokenize prompt with BOS token if required (add_special = true, parse_special = true)
    const int n_prompt = -llama_tokenize(g_vocab, prompt_text.c_str(), (int32_t)prompt_text.size(), NULL, 0, true, true);
    if (n_prompt <= 0) {
        log_error("Failed to calculate prompt token count");
        return false;
    }
    std::vector<llama_token> prompt_tokens(n_prompt);
    
    if (llama_tokenize(g_vocab, prompt_text.c_str(), (int32_t)prompt_text.size(), prompt_tokens.data(), (int32_t)prompt_tokens.size(), true, true) < 0) {
        log_error("Failed to tokenize prompt");
        return false;
    }
    
    // Clear KV cache before evaluating new sequence
    llama_memory_t mem = llama_get_memory(g_context);
    llama_memory_clear(mem, true);
    
    // Truncate prompt if it exceeds context limit
    const uint32_t n_ctx = llama_n_ctx(g_context);
    if (prompt_tokens.size() >= n_ctx) {
        size_t keep = n_ctx > 128 ? (n_ctx - 128) : (n_ctx / 2);
        prompt_tokens.erase(prompt_tokens.begin(), prompt_tokens.end() - keep);
    }
    
    // Decode prompt in chunks of n_batch with explicit positions
    const uint32_t n_batch = llama_n_batch(g_context);
    for (size_t i = 0; i < prompt_tokens.size(); i += n_batch) {
        const int32_t n_eval = (int32_t)std::min((size_t)n_batch, prompt_tokens.size() - i);
        llama_batch batch = llama_batch_init(n_eval, 0, 1);
        for (int32_t j = 0; j < n_eval; ++j) {
            batch.token[j] = prompt_tokens[i + j];
            batch.pos[j] = (llama_pos)(i + j);
            batch.n_seq_id[j] = 1;
            batch.seq_id[j][0] = 0;
            batch.logits[j] = (i + j == prompt_tokens.size() - 1) ? 1 : 0;
        }
        batch.n_tokens = n_eval;

        int res = llama_decode(g_context, batch);
        llama_batch_free(batch);
        if (res != 0) {
            log_error("Failed to decode prompt chunk at offset %zu", i);
            return false;
        }
    }
    
    // Update sampler with new parameters
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    
    auto sparams = llama_sampler_chain_default_params();
    g_sampler = llama_sampler_chain_init(sparams);
    const int32_t n_vocab = g_vocab ? llama_vocab_n_tokens(g_vocab) : 32000;
    llama_sampler_chain_add(g_sampler, call_penalties(llama_sampler_init_penalties, n_vocab, 64, repeat_penalty > 1.0f ? repeat_penalty : 1.15f, 0.0f, 0.0f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_k(top_k));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_p(top_p, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(1234));
    
    for (size_t i = 0; i < prompt_tokens.size(); ++i) {
        llama_sampler_accept(g_sampler, prompt_tokens[i]);
    }
    
    // Generate tokens
    std::string result;
    int n_gen = 0;
    int n_pos = (int)prompt_tokens.size();
    
    g_should_stop = false;
    
    for (int i = 0; i < max_tokens; i++) {
        if (g_should_stop) {
            log_info("Generation stopped by user");
            break;
        }
        
        // Sample next token and register in sampler
        llama_token new_token = llama_sampler_sample(g_sampler, g_context, -1);
        llama_sampler_accept(g_sampler, new_token);
        
        // Check for EOS
        if (llama_vocab_is_eog(g_vocab, new_token)) {
            log_info("EOS token reached");
            break;
        }
        
        // Convert token to text
        char token_str[256] = {0};
        int n = llama_token_to_piece(g_vocab, new_token, token_str, sizeof(token_str) - 1, 0, true);
        if (n > 0) {
            token_str[n] = '\0';
            std::string piece(token_str);
            if (piece.find("<|im_end|>") != std::string::npos ||
                piece.find("<|endoftext|>") != std::string::npos ||
                piece.find("<|im_start|>") != std::string::npos ||
                piece.find("<|eot_id|>") != std::string::npos ||
                piece.find("</s>") != std::string::npos) {
                break;
            }
            result.append(piece);
        }
        
        // Prepare batch for single generated token at position n_pos
        llama_batch batch = llama_batch_init(1, 0, 1);
        batch.token[0] = new_token;
        batch.pos[0] = (llama_pos)n_pos;
        batch.n_seq_id[0] = 1;
        batch.seq_id[0][0] = 0;
        batch.logits[0] = 1;
        batch.n_tokens = 1;

        n_pos++;
        
        int res = llama_decode(g_context, batch);
        llama_batch_free(batch);
        if (res != 0) {
            log_error("Failed to decode token");
            break;
        }
        
        n_gen++;
    }
    
    // Copy result
    size_t copy_len = std::min(result.length(), (size_t)(output_size - 1));
    memcpy(output, result.c_str(), copy_len);
    output[copy_len] = '\0';
    *tokens_generated = n_gen;
    
    log_info("Generated %d tokens", n_gen);
    return true;
}

FLUTTER_LLAMA_EXPORT void llama_generate_stream_init(
    const char* prompt,
    float temperature,
    float top_p,
    int32_t top_k,
    int32_t max_tokens,
    float repeat_penalty
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    log_info("Initializing stream generation");
    
    if (!g_model || !g_context || !g_vocab) {
        log_error("Model not loaded");
        return;
    }
    
    g_should_stop = false;
    g_stream_n_pos = 0;
    g_stream_n_generated = 0;
    g_stream_max_tokens = max_tokens;
    
    std::string prompt_text(prompt);
    
    // Tokenize prompt
    const int n_prompt = -llama_tokenize(g_vocab, prompt_text.c_str(), (int32_t)prompt_text.size(), NULL, 0, true, true);
    if (n_prompt <= 0) {
        log_error("Failed to calculate prompt token count");
        return;
    }
    std::vector<llama_token> prompt_tokens(n_prompt);
    
    if (llama_tokenize(g_vocab, prompt_text.c_str(), (int32_t)prompt_text.size(), prompt_tokens.data(), (int32_t)prompt_tokens.size(), true, true) < 0) {
        log_error("Failed to tokenize prompt");
        return;
    }
    
    // Clear KV cache before evaluating new sequence
    llama_memory_t mem = llama_get_memory(g_context);
    llama_memory_clear(mem, true);
    
    // Truncate prompt if it exceeds context limit
    const uint32_t n_ctx = llama_n_ctx(g_context);
    if (prompt_tokens.size() >= n_ctx) {
        size_t keep = n_ctx > 128 ? (n_ctx - 128) : (n_ctx / 2);
        prompt_tokens.erase(prompt_tokens.begin(), prompt_tokens.end() - keep);
    }
    
    // Decode prompt in chunks of n_batch with explicit positions
    const uint32_t n_batch = llama_n_batch(g_context);
    for (size_t i = 0; i < prompt_tokens.size(); i += n_batch) {
        const int32_t n_eval = (int32_t)std::min((size_t)n_batch, prompt_tokens.size() - i);
        llama_batch batch = llama_batch_init(n_eval, 0, 1);
        for (int32_t j = 0; j < n_eval; ++j) {
            batch.token[j] = prompt_tokens[i + j];
            batch.pos[j] = (llama_pos)(i + j);
            batch.n_seq_id[j] = 1;
            batch.seq_id[j][0] = 0;
            batch.logits[j] = (i + j == prompt_tokens.size() - 1) ? 1 : 0;
        }
        batch.n_tokens = n_eval;

        int res = llama_decode(g_context, batch);
        llama_batch_free(batch);
        if (res != 0) {
            log_error("Failed to decode prompt chunk at offset %zu", i);
            return;
        }
    }
    
    // Update sampler
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    
    auto sparams = llama_sampler_chain_default_params();
    g_sampler = llama_sampler_chain_init(sparams);
    const int32_t n_vocab = g_vocab ? llama_vocab_n_tokens(g_vocab) : 32000;
    llama_sampler_chain_add(g_sampler, call_penalties(llama_sampler_init_penalties, n_vocab, 64, repeat_penalty > 1.0f ? repeat_penalty : 1.15f, 0.0f, 0.0f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_k(top_k));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_p(top_p, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(1234));
    
    for (size_t i = 0; i < prompt_tokens.size(); ++i) {
        llama_sampler_accept(g_sampler, prompt_tokens[i]);
    }
    
    g_stream_n_pos = (int)prompt_tokens.size();
    log_info("Stream initialized with %zu prompt tokens", prompt_tokens.size());
}

FLUTTER_LLAMA_EXPORT bool llama_generate_stream_next(
    char* output,
    int32_t output_size
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (g_should_stop || !g_model || !g_context || !g_sampler || !g_vocab) {
        return false;
    }
    
    if (g_stream_n_generated >= g_stream_max_tokens) {
        return false;
    }
    
    const uint32_t n_ctx = llama_n_ctx(g_context);
    if (g_stream_n_pos >= (int)n_ctx - 1) {
        log_info("Stream context limit reached (%d)", g_stream_n_pos);
        return false;
    }
    
    llama_token new_token = llama_sampler_sample(g_sampler, g_context, -1);
    llama_sampler_accept(g_sampler, new_token);
    
    if (llama_vocab_is_eog(g_vocab, new_token)) {
        log_info("Stream EOS token reached");
        return false;
    }
    
    char token_str[256] = {0};
    int n = llama_token_to_piece(g_vocab, new_token, token_str, sizeof(token_str) - 1, 0, true);
    if (n <= 0) {
        return false;
    }
    
    token_str[n] = '\0';
    std::string piece(token_str);
    
    if (piece.find("<|im_end|>") != std::string::npos ||
        piece.find("<|endoftext|>") != std::string::npos ||
        piece.find("<|im_start|>") != std::string::npos ||
        piece.find("<|eot_id|>") != std::string::npos ||
        piece.find("</s>") != std::string::npos) {
        log_info("Stream ChatML stop token reached");
        return false;
    }
    
    llama_batch batch = llama_batch_init(1, 0, 1);
    batch.token[0] = new_token;
    batch.pos[0] = (llama_pos)g_stream_n_pos;
    batch.n_seq_id[0] = 1;
    batch.seq_id[0][0] = 0;
    batch.logits[0] = 1;
    batch.n_tokens = 1;

    g_stream_n_pos++;
    g_stream_n_generated++;
    
    int res = llama_decode(g_context, batch);
    llama_batch_free(batch);
    if (res != 0) {
        log_error("Failed to decode token in stream");
        return false;
    }
    
    size_t copy_len = std::min(piece.length(), (size_t)(output_size - 1));
    memcpy(output, piece.c_str(), copy_len);
    output[copy_len] = '\0';
    
    return true;
}

FLUTTER_LLAMA_EXPORT void llama_generate_stream_end() {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    log_info("Ending stream generation");
    g_stream_n_pos = 0;
    g_stream_n_generated = 0;
    g_stream_max_tokens = 0;
}

FLUTTER_LLAMA_EXPORT void llama_get_model_info(
    int64_t* n_params,
    int32_t* n_layers,
    int32_t* context_size
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (!g_model || !g_context) {
        *n_params = 0;
        *n_layers = 0;
        *context_size = 0;
        return;
    }
    
    *n_params = llama_model_n_params(g_model);
    *n_layers = llama_model_n_layer(g_model);
    *context_size = llama_n_ctx(g_context);
}

FLUTTER_LLAMA_EXPORT void llama_cpp_bridge_free_model() {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    log_info("Freeing model");
    
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    
    if (g_context) {
        llama_free(g_context);
        g_context = nullptr;
    }
    
    if (g_model) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
    
    g_vocab = nullptr;
    llama_backend_free();
    log_info("Model freed successfully");
}

FLUTTER_LLAMA_EXPORT void llama_stop_generation() {
    std::lock_guard<std::mutex> lock(g_mutex);
    log_info("Stopping generation");
    g_should_stop = true;
}

} // extern "C"
