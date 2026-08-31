export interface MarkdownChunk {
  id: string;
  headerPath: string;
  headerLevel: number;
  content: string;
  wordCount: number;
  hasTable: boolean;
  hasMath: boolean;
  hasCode: boolean;
}

export interface ChunkerOptions {
  maxChunkWords?: number;
  minChunkWords?: number;
  overlapWords?: number;
}

/**
 * Layout-aware Markdown chunker that hierarchically segments text by Markdown
 * headers (`#`, `##`, `###`) while preserving tables, LaTeX formulas, and code
 * blocks as atomic chunks.
 */
export function chunkMarkdown(
  markdown: string,
  options?: ChunkerOptions
): MarkdownChunk[] {
  const maxChunkWords = options?.maxChunkWords ?? 450;
  const minChunkWords = options?.minChunkWords ?? 50;

  const lines = markdown.split("\n");
  const sections: {
    header: string;
    level: number;
    headerPath: string;
    lines: string[];
  }[] = [];

  let currentHeader = "Introduction";
  let currentLevel = 1;
  const headerStack: { title: string; level: number }[] = [
    { title: "Document", level: 0 },
  ];
  let currentSectionLines: string[] = [];

  const headerRegex = /^(#{1,6})\s+(.+)$/;

  for (const line of lines) {
    const headerMatch = line.match(headerRegex);

    if (headerMatch) {
      if (currentSectionLines.length > 0) {
        sections.push({
          header: currentHeader,
          level: currentLevel,
          headerPath: headerStack.map((h) => h.title).join(" > "),
          lines: [...currentSectionLines],
        });
        currentSectionLines = [];
      }

      const hashes = headerMatch[1];
      const title = headerMatch[2].trim();
      currentLevel = hashes.length;
      currentHeader = title;

      while (
        headerStack.length > 1 &&
        headerStack[headerStack.length - 1].level >= currentLevel
      ) {
        headerStack.pop();
      }
      headerStack.push({ title, level: currentLevel });
    } else {
      currentSectionLines.push(line);
    }
  }

  if (currentSectionLines.length > 0) {
    sections.push({
      header: currentHeader,
      level: currentLevel,
      headerPath: headerStack.map((h) => h.title).join(" > "),
      lines: [...currentSectionLines],
    });
  }

  const chunks: MarkdownChunk[] = [];
  let chunkCounter = 1;

  for (const sec of sections) {
    const sectionText = sec.lines.join("\n").trim();
    if (!sectionText) continue;

    const blocks = splitIntoAtomicBlocks(sectionText);
    let currentBlockAccumulator: string[] = [];
    let currentWordCount = 0;

    for (const block of blocks) {
      const blockWords = countWords(block);

      if (
        currentWordCount + blockWords > maxChunkWords &&
        currentBlockAccumulator.length > 0
      ) {
        const chunkText = currentBlockAccumulator.join("\n\n").trim();
        if (chunkText) {
          chunks.push({
            id: `chunk_${chunkCounter++}`,
            headerPath: sec.headerPath,
            headerLevel: sec.level,
            content: `# ${sec.header}\n\n${chunkText}`,
            wordCount: countWords(chunkText),
            hasTable: /\|[\s\S]*?\|/.test(chunkText),
            hasMath: /\$\$[\s\S]*?\$\$|\$[^\$]+\$/.test(chunkText),
            hasCode: /```[\s\S]*?```/.test(chunkText),
          });
        }
        currentBlockAccumulator = [block];
        currentWordCount = blockWords;
      } else {
        currentBlockAccumulator.push(block);
        currentWordCount += blockWords;
      }
    }

    if (currentBlockAccumulator.length > 0) {
      const chunkText = currentBlockAccumulator.join("\n\n").trim();
      if (chunkText) {
        chunks.push({
          id: `chunk_${chunkCounter++}`,
          headerPath: sec.headerPath,
          headerLevel: sec.level,
          content: `# ${sec.header}\n\n${chunkText}`,
          wordCount: countWords(chunkText),
          hasTable: /\|[\s\S]*?\|/.test(chunkText),
          hasMath: /\$\$[\s\S]*?\$\$|\$[^\$]+\$/.test(chunkText),
          hasCode: /```[\s\S]*?```/.test(chunkText),
        });
      }
    }
  }

  return chunks;
}

/**
 * Splits text into paragraphs while preserving Markdown tables, code blocks,
 * and block LaTeX formulas as single atomic units.
 */
function splitIntoAtomicBlocks(text: string): string[] {
  const blocks: string[] = [];
  const lines = text.split("\n");
  let currentBlock: string[] = [];
  let inCodeBlock = false;
  let inMathBlock = false;
  let inTable = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Code block detection
    if (trimmed.startsWith("```")) {
      inCodeBlock = !inCodeBlock;
      currentBlock.push(line);
      if (!inCodeBlock) {
        blocks.push(currentBlock.join("\n"));
        currentBlock = [];
      }
      continue;
    }

    // LaTeX block detection
    if (trimmed.startsWith("$$")) {
      if (inMathBlock || trimmed.endsWith("$$") && trimmed.length > 2) {
        currentBlock.push(line);
        blocks.push(currentBlock.join("\n"));
        currentBlock = [];
        inMathBlock = false;
        continue;
      } else {
        inMathBlock = true;
        currentBlock.push(line);
        continue;
      }
    }

    // Markdown Table detection
    if (trimmed.startsWith("|") && trimmed.endsWith("|")) {
      inTable = true;
      currentBlock.push(line);
      continue;
    } else if (inTable) {
      inTable = false;
      blocks.push(currentBlock.join("\n"));
      currentBlock = [];
    }

    if (inCodeBlock || inMathBlock) {
      currentBlock.push(line);
      continue;
    }

    if (trimmed === "") {
      if (currentBlock.length > 0) {
        blocks.push(currentBlock.join("\n"));
        currentBlock = [];
      }
    } else {
      currentBlock.push(line);
    }
  }

  if (currentBlock.length > 0) {
    blocks.push(currentBlock.join("\n"));
  }

  return blocks;
}

function countWords(str: string): number {
  return str.trim().split(/\s+/).filter(Boolean).length;
}
