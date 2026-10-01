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
      const accountId =
        Deno.env.get("R2_ACCOUNT_ID") ?? "70d5976cda85543f749219264f8391f0";
      const accessKeyId =
        Deno.env.get("R2_ACCESS_KEY_ID") ?? "45baa62136f37a008f6bb338d27ca708";
      const secretAccessKey =
        Deno.env.get("R2_SECRET_ACCESS_KEY") ??
        "cf4d750fbf1ff5ee3b7037e87e8f92540794260fdcdc4d82931244b2fd320246";
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
    return (
      Deno.env.get("R2_PUBLIC_DOMAIN") ??
      "https://pub-48d140cd04784f4b93fd2941eedd7223.r2.dev"
    ).replace(/\/+$/, "");
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
