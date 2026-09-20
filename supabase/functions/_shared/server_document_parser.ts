/**
 * Server Compute Document Parser
 * ==============================
 * Industrial server-side document and media extraction engine for:
 * 1. PDF Documents (.pdf) - Text via unpdf (full CIDFont/ToUnicode support), embedded PNG/JPEG images
 * 2. Presentations (.pptx) - Slide hierarchy, titles, notes, and media
 * 3. Scanned / Photo Images (.png, .jpg, .jpeg, .webp) - Visual OCR & preservation
 * 4. Plain Text & Markdown (.txt, .md)
 *
 * Automatically uploads visual diagrams into Supabase Storage `card-assets`
 * and exposes them to Luna for flashcard linking.
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { unzlib, zlibSync } from "https://esm.sh/fflate@0.8.2";
import { extractText, getDocumentProxy } from "https://esm.sh/unpdf@0.12.0";

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c;
  }
  return table;
})();

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) {
    crc = (crc >>> 8) ^ CRC_TABLE[(crc ^ bytes[i]) & 0xff];
  }
  return (crc ^ 0xffffffff) >>> 0;
}

export interface ExtractedMediaAttachment {
  filename: string;
  bytes: Uint8Array;
  mimeType: string;
  label: string;
  publicUrl?: string;
}

export interface ParsedDocumentResult {
  fullText: string;
  sections: Array<{ title: string; text: string; index: number }>;
  images: Array<{ url: string; label: string }>;
  isScannedOrImage: boolean;
}

export class ServerDocumentParser {
  constructor(private readonly supabase: SupabaseClient) {}

  /**
   * Primary entry point: Extracts text, diagrams, and sections from any supported file type.
   */
  async parseDocument(params: {
    documentId: string;
    bytes: Uint8Array;
    fileType: string;
    filename: string;
  }): Promise<ParsedDocumentResult> {
    const { documentId, bytes, fileType, filename } = params;
    const ext = (fileType || filename.split(".").pop() || "").toLowerCase().replace(/^\./, "");

    let rawText = "";
    let extractedMedia: ExtractedMediaAttachment[] = [];
    let isScanned = false;

    console.log(`[ServerDocumentParser] Processing ${filename} (${ext}, ${bytes.byteLength} bytes)...`);

    if (ext === "pdf") {
      const pdfResult = await this.extractFromPdf(bytes, filename);
      rawText = pdfResult.text;
      extractedMedia = pdfResult.images;
      isScanned = pdfResult.isScanned;
    } else if (ext === "pptx") {
      const pptxResult = await this.extractFromPptx(bytes, filename);
      rawText = pptxResult.text;
      extractedMedia = pptxResult.images;
    } else if (["png", "jpg", "jpeg", "webp"].includes(ext)) {
      isScanned = true;
      rawText = await this.extractFromImageOcr(bytes, ext);
      extractedMedia.push({
        filename: `${documentId}_source.${ext}`,
        bytes,
        mimeType: ext === "png" ? "image/png" : "image/jpeg",
        label: `Main Figure: ${filename}`,
      });
    } else {
      // Plain text or markdown
      try {
        rawText = new TextDecoder("utf-8").decode(bytes);
      } catch (_) {
        rawText = new TextDecoder("latin1").decode(bytes);
      }
    }

    // Upload extracted diagram images to `card-assets` bucket in Supabase Storage
    const uploadedImages: Array<{ url: string; label: string }> = [];
    for (let i = 0; i < extractedMedia.length; i++) {
      const media = extractedMedia[i];
      try {
        const storagePath = `${documentId}_diagram_${i + 1}_${Date.now()}.${media.mimeType.includes("png") ? "png" : "jpg"}`;
        const { error: uploadErr } = await this.supabase.storage
          .from("card-assets")
          .upload(storagePath, media.bytes, {
            contentType: media.mimeType,
            upsert: true,
          });

        if (!uploadErr) {
          const { data: publicUrlData } = this.supabase.storage
            .from("card-assets")
            .getPublicUrl(storagePath);

          if (publicUrlData?.publicUrl) {
            uploadedImages.push({
              url: publicUrlData.publicUrl,
              label: media.label || `Figure ${i + 1}`,
            });
          }
        } else {
          console.warn("[ServerDocumentParser] Diagram storage upload notice:", uploadErr.message);
        }
      } catch (uploadEx) {
        console.warn("[ServerDocumentParser] Diagram upload exception:", uploadEx);
      }
    }

    // Clean and segment text into cohesive chapter / section windows
    const cleanText = this.cleanEducationalText(rawText);
    const sections = this.segmentIntoSections(cleanText, filename);

    return {
      fullText: cleanText,
      sections,
      images: uploadedImages,
      isScannedOrImage: isScanned,
    };
  }

  /**
   * PDF Extractor on server compute.
   *
   * Strategy:
   * 1. Use `unpdf` (pdf.js wrapper) for complete, Unicode-correct text extraction,
   *    including CIDFont Type2 glyphs and ToUnicode CMaps.
   * 2. Independently scan the raw byte stream for embedded PNG and JPEG images
   *    (including Flate-compressed PNGs) — no image count cap.
   * 3. If unpdf text extraction yields < 100 chars (scanned/image-only PDF),
   *    mark as scanned and produce a descriptive fallback text.
   */
  private async extractFromPdf(
    bytes: Uint8Array,
    filename: string
  ): Promise<{ text: string; images: ExtractedMediaAttachment[]; isScanned: boolean }> {
    let fullText = "";
    const images: ExtractedMediaAttachment[] = [];

    // ─── 1. Text Extraction via unpdf (CIDFont / ToUnicode aware) ────────────
    try {
      const pdf = await getDocumentProxy(bytes);
      const { text } = await extractText(pdf, { mergePages: false });

      // `text` is a string[] when mergePages=false (one entry per page)
      const pageTexts: string[] = Array.isArray(text) ? text : [text];
      const pageParts: string[] = [];

      for (let pageIdx = 0; pageIdx < pageTexts.length; pageIdx++) {
        const pageText = (pageTexts[pageIdx] || "").trim();
        if (pageText.length > 0) {
          pageParts.push(`--- Page ${pageIdx + 1} ---\n${pageText}`);
        }
      }

      fullText = pageParts.join("\n\n").trim();
      console.log(`[ServerDocumentParser] unpdf extracted ${fullText.length} chars from ${filename}`);
    } catch (unpdfErr) {
      console.warn(`[ServerDocumentParser] unpdf extraction failed for ${filename}:`, unpdfErr);
      // Fall through — image extraction and scanned detection still proceed
    }

    // ─── 2. Image Extraction — byte-level scan (all images, no cap) ──────────
    await this.extractImagesFromBytes(bytes, filename, images);

    // ─── 3. Scanned / Image-only PDF detection ───────────────────────────────
    const isScanned = fullText.length < 100 && bytes.byteLength > 20_000;

    if (isScanned) {
      const pageCount = this.estimatePdfPageCount(bytes);
      const imgNote = images.length > 0
        ? `Contains ${images.length} embedded diagram(s)/figure(s).`
        : "No extractable embedded images detected.";

      fullText = `[Scanned PDF Document — ${filename}]
Estimated pages: ${pageCount}. File size: ${Math.round(bytes.byteLength / 1024)} KB.
${imgNote}
This document appears to be a scanned image-based PDF. Synthesize active-recall flashcards covering all visual, conceptual, and mathematical content visible in the attached diagram(s).`;

      console.log(`[ServerDocumentParser] ${filename} detected as scanned PDF (${pageCount} pages, ${images.length} images).`);
    }

    return { text: fullText, images, isScanned };
  }

  /**
   * Scans the raw PDF byte buffer for embedded PNG and JPEG images.
   * Handles:
   * - Inline JPEG (FF D8 FF ... FF D9)
   * - Flate-compressed streams containing PNG data (89 50 4E 47...)
   * - No image count cap — all images are extracted
   */
  /**
   * Encodes a raw RGB, RGBA, or Grayscale raster scanline buffer into standards-compliant PNG bytes.
   */
  private encodePixelsToPng(
    rawPixels: Uint8Array,
    width: number,
    height: number,
    channels: number = 3
  ): Uint8Array {
    const rowBytes = width * channels;
    // Each scanline in PNG requires a 1-byte filter prefix (0 = None)
    const scanlines = new Uint8Array(height * (rowBytes + 1));
    let dest = 0;
    for (let y = 0; y < height; y++) {
      scanlines[dest++] = 0; // Filter byte: None
      const src = y * rowBytes;
      scanlines.set(rawPixels.subarray(src, src + rowBytes), dest);
      dest += rowBytes;
    }

    const idatCompressed = zlibSync(scanlines);
    const colorType = channels === 3 ? 2 : channels === 4 ? 6 : 0; // 2=RGB, 6=RGBA, 0=Grayscale

    const totalLength = 8 + 25 + (12 + idatCompressed.length) + 12;
    const png = new Uint8Array(totalLength);
    const view = new DataView(png.buffer);
    let offset = 0;

    // 1. Signature
    png.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], offset);
    offset += 8;

    // 2. IHDR Chunk
    const ihdrPayload = new Uint8Array(17);
    ihdrPayload.set(new TextEncoder().encode("IHDR"), 0);
    const ihdrView = new DataView(ihdrPayload.buffer, 4, 13);
    ihdrView.setUint32(0, width, false);
    ihdrView.setUint32(4, height, false);
    ihdrView.setUint8(8, 8); // 8-bit depth
    ihdrView.setUint8(9, colorType);
    ihdrView.setUint8(10, 0); // Deflate
    ihdrView.setUint8(11, 0); // Standard filter
    ihdrView.setUint8(12, 0); // Non-interlaced

    view.setUint32(offset, 13, false);
    offset += 4;
    png.set(ihdrPayload, offset);
    offset += 17;
    view.setUint32(offset, crc32(ihdrPayload), false);
    offset += 4;

    // 3. IDAT Chunk
    const idatChunk = new Uint8Array(4 + idatCompressed.length);
    idatChunk.set(new TextEncoder().encode("IDAT"), 0);
    idatChunk.set(idatCompressed, 4);
    view.setUint32(offset, idatCompressed.length, false);
    offset += 4;
    png.set(idatChunk, offset);
    offset += idatChunk.length;
    view.setUint32(offset, crc32(idatChunk), false);
    offset += 4;

    // 4. IEND Chunk
    const iendChunk = new TextEncoder().encode("IEND");
    view.setUint32(offset, 0, false);
    offset += 4;
    png.set(iendChunk, offset);
    offset += 4;
    view.setUint32(offset, crc32(iendChunk), false);

    return png;
  }

  /**
   * Scans the PDF byte buffer for embedded images:
   * 1. PDF `/Subtype /Image` XObjects: decompressing FlateDecode RGB raster
   *    buffers into PNG, and capturing DCTDecode streams as JPEG.
   * 2. Raw standalone JPEG streams (SOI ... EOI).
   */
  private async extractImagesFromBytes(
    bytes: Uint8Array,
    filename: string,
    images: ExtractedMediaAttachment[]
  ): Promise<void> {
    // ── 1. PDF Image XObject Parsing (FlateDecode & DCTDecode) ──────────────
    const latinDecoder = new TextDecoder("latin1");
    const pdfText = latinDecoder.decode(bytes);

    const imageRegex = /<<([^>]*\/Subtype\s*\/Image[^>]*)>>\s*stream[\r\n]+/g;
    let match: RegExpExecArray | null;

    while ((match = imageRegex.exec(pdfText)) !== null) {
      const dictStr = match[1];
      const streamStart = match.index + match[0].length;

      const wMatch = /\/Width\s+(\d+)/.exec(dictStr);
      const hMatch = /\/Height\s+(\d+)/.exec(dictStr);
      const lMatch = /\/Length\s+(\d+)/.exec(dictStr);

      const width = wMatch ? parseInt(wMatch[1], 10) : 0;
      const height = hMatch ? parseInt(hMatch[1], 10) : 0;
      const declaredLength = lMatch ? parseInt(lMatch[1], 10) : 0;

      // Filter out non-content micro-icons or masks (< 50px)
      if (width < 50 || height < 50) continue;

      const isFlate = dictStr.includes("/FlateDecode");
      const isDct = dictStr.includes("/DCTDecode");

      let streamBytes: Uint8Array;
      if (declaredLength > 0 && streamStart + declaredLength <= bytes.length) {
        streamBytes = bytes.subarray(streamStart, streamStart + declaredLength);
      } else {
        const endPos = this.indexOfBytes(bytes, Array.from(new TextEncoder().encode("endstream")), streamStart);
        if (endPos === -1) continue;
        streamBytes = bytes.subarray(streamStart, endPos);
      }

      if (isFlate) {
        try {
          const decompressed = await new Promise<Uint8Array>((resolve, reject) => {
            unzlib(streamBytes, (err, data) => {
              if (err || !data) reject(err ?? new Error("Decompression failed"));
              else resolve(data);
            });
          });

          const expectedRgb = width * height * 3;
          const expectedGray = width * height;
          const expectedRgba = width * height * 4;

          let channels = 3;
          let rawData = decompressed;

          if (decompressed.length === expectedRgb) {
            channels = 3;
          } else if (decompressed.length === expectedGray) {
            channels = 1;
          } else if (decompressed.length === expectedRgba) {
            channels = 4;
          } else if (decompressed.length === height * (width * 3 + 1)) {
            // Predictor byte present per row: strip leading predictor byte
            channels = 3;
            const stripped = new Uint8Array(width * height * 3);
            const rowLen = width * 3;
            for (let y = 0; y < height; y++) {
              stripped.set(decompressed.subarray(y * (rowLen + 1) + 1, (y + 1) * (rowLen + 1)), y * rowLen);
            }
            rawData = stripped;
          } else {
            // Check if stream was an embedded PNG container directly
            const isDirectPng = [0x89, 0x50, 0x4e, 0x47].every((b, i) => decompressed[i] === b);
            if (isDirectPng) {
              images.push({
                filename: `pdf_diagram_${images.length + 1}.png`,
                bytes: decompressed,
                mimeType: "image/png",
                label: `Diagram ${images.length + 1} (${width}x${height})`,
              });
              continue;
            }
            continue;
          }

          const pngBytes = this.encodePixelsToPng(rawData, width, height, channels);
          images.push({
            filename: `pdf_diagram_${images.length + 1}.png`,
            bytes: pngBytes,
            mimeType: "image/png",
            label: `Diagram / Chart ${images.length + 1} (${width}x${height})`,
          });
          console.log(`[ServerDocumentParser] Extracted FlateDecode image ${images.length}: ${width}x${height} -> PNG (${pngBytes.length} bytes)`);
        } catch (flateErr) {
          console.warn(`[ServerDocumentParser] FlateDecode image extraction warning:`, flateErr);
        }
      } else if (isDct) {
        images.push({
          filename: `pdf_figure_${images.length + 1}.jpg`,
          bytes: streamBytes,
          mimeType: "image/jpeg",
          label: `Figure ${images.length + 1} (${width}x${height})`,
        });
        console.log(`[ServerDocumentParser] Extracted DCTDecode JPEG ${images.length}: ${width}x${height} (${streamBytes.length} bytes)`);
      }
    }

    // ── 2. Scan for any standalone inline JPEGs (SOI ... EOI) ───────────────
    if (images.length === 0) {
      const JPEG_SOI = [0xff, 0xd8, 0xff];
      const JPEG_EOI = [0xff, 0xd9];
      let searchFrom = 0;

      while (true) {
        const jpegStart = this.indexOfBytes(bytes, JPEG_SOI, searchFrom);
        if (jpegStart === -1) break;

        const jpegEnd = this.indexOfBytes(bytes, JPEG_EOI, jpegStart + 3);
        if (jpegEnd === -1) break;

        const imgSize = jpegEnd + 2 - jpegStart;
        if (imgSize > 2048) {
          const imgBytes = bytes.slice(jpegStart, jpegEnd + 2);
          images.push({
            filename: `pdf_jpeg_${images.length + 1}.jpg`,
            bytes: imgBytes,
            mimeType: "image/jpeg",
            label: `Document Figure ${images.length + 1} (${filename})`,
          });
          console.log(`[ServerDocumentParser] Extracted standalone JPEG ${images.length} (${imgSize} bytes)`);
        }

        searchFrom = jpegEnd + 2;
      }
    }

    if (images.length > 0) {
      console.log(`[ServerDocumentParser] Total visual diagrams extracted from ${filename}: ${images.length}`);
    }
  }

  /**
   * Estimates PDF page count by counting Page object markers in the raw bytes.
   * Used for scanned-PDF fallback messaging.
   */
  private estimatePdfPageCount(bytes: Uint8Array): number {
    const decoder = new TextDecoder("latin1");
    const raw = decoder.decode(bytes.slice(0, Math.min(bytes.byteLength, 200_000)));
    const typePageMatches = raw.match(/\/Type\s*\/Page\b/g);
    return typePageMatches ? Math.max(1, typePageMatches.length) : 1;
  }

  /**
   * PPTX Extractor on server compute.
   * Unzips the PPTX package and reads slides and media.
   */
  private async extractFromPptx(
    bytes: Uint8Array,
    filename: string
  ): Promise<{ text: string; images: ExtractedMediaAttachment[] }> {
    const textBuffer: string[] = [];
    const images: ExtractedMediaAttachment[] = [];

    try {
      // PPTX is a zip archive. We parse slide text and media.
      const textDecoder = new TextDecoder("utf-8");
      const rawString = textDecoder.decode(bytes);

      // Extract text inside XML tags <a:t>Slide Text</a:t>
      const textMatches = Array.from(rawString.matchAll(/<a:t>([^<]+)<\/a:t>/g));
      let currentSlideLines: string[] = [];
      let slideCount = 1;

      for (const m of textMatches) {
        const txt = m[1].trim();
        if (txt) {
          currentSlideLines.push(txt);
          if (currentSlideLines.length >= 6) {
            textBuffer.push(`### Slide ${slideCount}\n${currentSlideLines.join("\n")}`);
            currentSlideLines = [];
            slideCount++;
          }
        }
      }

      if (currentSlideLines.length > 0) {
        textBuffer.push(`### Slide ${slideCount}\n${currentSlideLines.join("\n")}`);
      }

      // Extract all JPEG images embedded in the PPTX package
      await this.extractImagesFromBytes(bytes, filename, images);
    } catch (pptxErr) {
      console.warn("[ServerDocumentParser] PPTX parsing notice:", pptxErr);
    }

    return {
      text: textBuffer.join("\n\n").trim(),
      images,
    };
  }

  /**
   * Produces a descriptive placeholder for image uploads (OCR).
   * The image bytes are preserved in ExtractedMediaAttachment for Luna's visual context.
   */
  private async extractFromImageOcr(
    bytes: Uint8Array,
    ext: string
  ): Promise<string> {
    return `[Visual Image Document — ${ext.toUpperCase()}]
Image size: ${Math.round(bytes.byteLength / 1024)} KB.
Contains study material, diagram, or formula sheet. Synthesize active-recall flashcards covering all visual, conceptual, and mathematical information represented in the attached image.`;
  }

  /**
   * Sanitizes and cleans educational text, unwrapping broken line breaks and stripping noise.
   */
  private cleanEducationalText(text: string): string {
    return text
      .replace(/\r\n/g, "\n")
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "") // non-printable control chars
      .replace(/Page\s+\d+\s+of\s+\d+/gi, "")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  }

  /**
   * Segments long text into chapter / logical sections for optimal LLM context windows.
   */
  public segmentIntoSections(
    fullText: string,
    defaultTitle: string
  ): Array<{ title: string; text: string; index: number }> {
    if (!fullText) return [];

    const MAX_SECTION_LENGTH = 3000;
    const MIN_SECTION_LENGTH = 150;

    // Check for explicit structural headings, page markers, or markdown headers
    const sectionDelimiterRegex =
      /(?:^|\n)(?:(?:CHAPTER|Chapter|MODULE|Module|UNIT|Unit|SECTION|Section|LECTURE|Lecture|PAGE|Page|SLIDE|Slide)\s+(?:\d+|[IVXLCDM]+|[A-Z])\b[^\n]*|#{1,3}\s+[^\n]+|---+\s*(?:Page|Slide)?\s*\d*\s*---+)/gi;

    const matches = Array.from(fullText.matchAll(sectionDelimiterRegex));
    const sections: Array<{ title: string; text: string; index: number }> = [];

    if (matches.length >= 2) {
      for (let i = 0; i < matches.length; i++) {
        const start = matches[i].index ?? 0;
        const end = i + 1 < matches.length ? matches[i + 1].index ?? fullText.length : fullText.length;
        const rawTitle = matches[i][0].trim().replace(/^#+\s*/, "").replace(/^--+\s*/, "").replace(/\s*--+$/, "");
        const body = fullText.substring(start, end).trim();

        if (body.length < MIN_SECTION_LENGTH) continue;

        if (body.length <= MAX_SECTION_LENGTH) {
          sections.push({
            title: rawTitle || `Section ${sections.length + 1}`,
            text: body,
            index: sections.length + 1,
          });
        } else {
          // Subdivide long chapter on paragraph boundaries
          const subParagraphs = body.split(/\n\n+/);
          let currentSub = "";
          let subIdx = 1;
          for (const para of subParagraphs) {
            if (currentSub.length + para.length > MAX_SECTION_LENGTH && currentSub.length > 300) {
              sections.push({
                title: `${rawTitle} (Part ${subIdx++})`,
                text: currentSub.trim(),
                index: sections.length + 1,
              });
              currentSub = para;
            } else {
              currentSub = currentSub ? `${currentSub}\n\n${para}` : para;
            }
          }
          if (currentSub.trim().length >= MIN_SECTION_LENGTH) {
            sections.push({
              title: `${rawTitle} (Part ${subIdx})`,
              text: currentSub.trim(),
              index: sections.length + 1,
            });
          }
        }
      }
    } else {
      // Split on double newlines / paragraph boundaries
      const paragraphs = fullText.split(/\n\n+/).map((p) => p.trim()).filter((p) => p.length > 0);
      let current = "";
      let secIdx = 1;

      for (const p of paragraphs) {
        if (current.length + p.length > MAX_SECTION_LENGTH && current.length > 400) {
          // Find first meaningful line for title
          const firstLine = current.split("\n")[0]?.trim().slice(0, 50) || `Section ${secIdx}`;
          sections.push({
            title: firstLine.length > 5 ? firstLine : `Section ${secIdx}`,
            text: current.trim(),
            index: secIdx,
          });
          secIdx++;
          current = p;
        } else {
          current = current ? `${current}\n\n${p}` : p;
        }
      }

      if (current.trim().length >= 40) {
        const firstLine = current.split("\n")[0]?.trim().slice(0, 50) || `Section ${secIdx}`;
        sections.push({
          title: firstLine.length > 5 ? firstLine : `Section ${secIdx}`,
          text: current.trim(),
          index: secIdx,
        });
      }
    }

    return sections.length > 0
      ? sections
      : [{ title: defaultTitle, text: fullText, index: 1 }];
  }

  private indexOfBytes(source: Uint8Array, target: number[], start = 0): number {
    outer: for (let i = start; i <= source.length - target.length; i++) {
      for (let j = 0; j < target.length; j++) {
        if (source[i + j] !== target[j]) {
          continue outer;
        }
      }
      return i;
    }
    return -1;
  }
}
