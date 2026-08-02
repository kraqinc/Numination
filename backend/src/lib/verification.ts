import { createHash, randomInt, randomBytes } from "crypto";

const PEPPER = process.env.EMAIL_CODE_PEPPER || "wren-email-code-pepper";

export function normalizeEmail(email: string): string {
  return String(email || "").trim().toLowerCase();
}

export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function generateSixDigitCode(): string {
  return String(randomInt(100000, 999999));
}

export function hashCode(code: string): string {
  return createHash("sha256").update(`${code}:${PEPPER}`).digest("hex");
}

export function generateFallbackPasswordHash(): string {
  return createHash("sha256")
    .update(randomBytes(32).toString("hex"))
    .digest("hex");
}
