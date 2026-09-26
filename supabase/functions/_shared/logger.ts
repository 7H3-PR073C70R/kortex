/**
 * Standardized JSON Logger for Supabase Edge Functions with correlation IDs.
 */

export interface StructuredLogPayload {
  timestamp: string;
  level: "INFO" | "WARN" | "ERROR" | "DEBUG";
  correlationId: string;
  functionName: string;
  message: string;
  details?: unknown;
}

export function logStructured(
  level: "INFO" | "WARN" | "ERROR" | "DEBUG",
  functionName: string,
  message: string,
  req?: Request,
  details?: unknown
): void {
  const correlationId =
    req?.headers.get("x-correlation-id") ||
    req?.headers.get("x-request-id") ||
    crypto.randomUUID();

  const payload: StructuredLogPayload = {
    timestamp: new Date().toISOString(),
    level,
    correlationId,
    functionName,
    message,
    details,
  };

  console.log(JSON.stringify(payload));
}
