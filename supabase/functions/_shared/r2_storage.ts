import { S3Client, PutObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.525.0";

export interface UploadDocumentImageParams {
  documentId: string;
  filename: string;
  bytes: Uint8Array;
  mimeType: string;
  contentHash?: string;
}

export interface UploadResult {
  publicUrl: string;
  key: string;
  sizeBytes: number;
}

/**
 * Centralized Cloudflare R2 Storage Provider for Kortex.
 * Manages structured object hierarchies for documents, forum media, and extracted assets.
 */
export class R2StorageProvider {
  private static clientInstance: S3Client | null = null;

  private static getS3Client(): S3Client {
    if (!this.clientInstance) {
      const accountId = Deno.env.get("R2_ACCOUNT_ID");
      const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
      const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");

      if (!accountId || !accessKeyId || !secretAccessKey) {
        throw new Error(
          "R2 storage credentials missing from environment variables (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY)"
        );
      }

      const endpoint =
        Deno.env.get("R2_S3_ENDPOINT") ??
        `https://${accountId}.r2.cloudflarestorage.com`;

      this.clientInstance = new S3Client({
        region: "auto",
        endpoint: endpoint,
        credentials: {
          accessKeyId,
          secretAccessKey,
        },
      });
    }
    return this.clientInstance;
  }

  public static get bucketName(): string {
    return Deno.env.get("R2_BUCKET_NAME") ?? "kortex-forum-media";
  }

  public static get publicDomain(): string {
    const domain = Deno.env.get("R2_PUBLIC_DOMAIN");
    if (!domain) {
      throw new Error("R2_PUBLIC_DOMAIN is not configured");
    }
    return domain.replace(/\/+$/, "");
  }

  /**
   * Uploads an extracted document diagram/image to Cloudflare R2 with structured key hierarchy:
   * `documents/{documentId}/images/{filename}`
   */
  public static async uploadDocumentImage(
    params: UploadDocumentImageParams
  ): Promise<UploadResult> {
    const { documentId, filename, bytes, mimeType, contentHash } = params;
    const client = this.getS3Client();

    const cleanFileName = filename.replace(/[^a-zA-Z0-9_\.-]/g, "_");
    const objectKey = contentHash
      ? `documents/canonical/${contentHash}/images/${cleanFileName}`
      : `documents/${documentId}/images/${cleanFileName}`;

    const command = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: objectKey,
      Body: bytes,
      ContentType: mimeType,
      CacheControl: "public, max-age=31536000, immutable",
    });

    await client.send(command);

    const publicUrl = `${this.publicDomain}/${objectKey}`;

    return {
      publicUrl,
      key: objectKey,
      sizeBytes: bytes.length,
    };
  }
}
