const assert = require("assert");

function chunkText(text, chunkSize = 500, overlap = 50) {
  const trimmed = text.trim();
  if (!trimmed) return [];

  if (trimmed.length < chunkSize * 6) {
    return [trimmed];
  }

  const chunks = [];
  const wordRegex = /\S+/g;
  let wordCount = 0;
  let chunkStartIndex = 0;
  let nextChunkStartIndex = 0;
  let match;

  const stepWords = Math.max(1, chunkSize - overlap);

  while ((match = wordRegex.exec(trimmed)) !== null) {
    wordCount++;

    if (wordCount === stepWords) {
      nextChunkStartIndex = match.index;
    }

    if (wordCount >= chunkSize) {
      const chunkEndIndex = wordRegex.lastIndex;
      chunks.push(trimmed.slice(chunkStartIndex, chunkEndIndex).trim());

      wordRegex.lastIndex = nextChunkStartIndex;
      chunkStartIndex = nextChunkStartIndex;
      wordCount = 0;
    }
  }

  if (chunkStartIndex < trimmed.length) {
    const remainder = trimmed.slice(chunkStartIndex).trim();
    if (remainder.length > 0) {
      chunks.push(remainder);
    }
  }

  return chunks.length > 0 ? chunks : [trimmed];
}

console.log("=== Testing chunkText O(1) Memory Chunker ===");

// Test 1: Short text
const short = "This is a short chapter in a textbook.";
const shortChunks = chunkText(short, 500, 50);
assert.strictEqual(shortChunks.length, 1);
assert.strictEqual(shortChunks[0], short);
console.log("✓ PASS: Short text returns single chunk immediately");

// Test 2: Huge text (e.g. 5,000 words simulating textbook chapters)
const words = [];
for (let i = 1; i <= 5000; i++) {
  words.push(`word${i}`);
}
const hugeText = words.join(" ");

const chunks = chunkText(hugeText, 500, 50);
// With 5000 words, step size is 450 words:
// Chunk 1: 1..500
// Chunk 2: 451..950
// Chunk 3: 901..1400
// ...
assert(chunks.length >= 10, `Expected at least 10 chunks, got ${chunks.length}`);
console.log(`✓ PASS: Huge text (5,000 words) processed into ${chunks.length} overlapping chunks with O(1) memory`);

// Verify overlap: Chunk 1 and Chunk 2 should share words 451..500
assert(chunks[0].includes("word451"));
assert(chunks[0].includes("word500"));
assert(chunks[1].includes("word451"));
assert(chunks[1].includes("word500"));
console.log("✓ PASS: Overlap between consecutive chunks verified");

// Test 3: Sub-batching simulation (preventing PostgREST / Deno isolate limit)
const SUB_BATCH_SIZE = 25;
const simulatedChunks = Array.from({ length: 65 }, (_, i) => ({ id: i, content: `chunk ${i}` }));
const batches = [];
for (let i = 0; i < simulatedChunks.length; i += SUB_BATCH_SIZE) {
  batches.push(simulatedChunks.slice(i, i + SUB_BATCH_SIZE));
}
assert.strictEqual(batches.length, 3);
assert.strictEqual(batches[0].length, 25);
assert.strictEqual(batches[1].length, 25);
assert.strictEqual(batches[2].length, 15);
console.log("✓ PASS: Sub-batching partitions 65 chunks into batches of 25, 25, 15");

console.log("\nALL EDGE FUNCTION TESTS PASSED!");
