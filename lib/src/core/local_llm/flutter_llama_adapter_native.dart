// Native adapter: re-exports all flutter_llama symbols used by the app.
// This file is ONLY included on non-web platforms via conditional import.
export 'package:flutter_llama/flutter_llama.dart'
    show
        DownloadProgress,
        DownloadProgressCallback,
        FlutterLlama,
        GenerationParams,
        LlamaConfig,
        LlamaResponse,
        ModelDownloadException,
        ModelManager,
        ModelNotFoundException,
        ModelSource,
        ModelSourceExtension,
        PresetModel,
        PresetModels;
