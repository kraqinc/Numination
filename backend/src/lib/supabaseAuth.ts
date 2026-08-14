import { createPublicKey, verify as verifySignature } from "node:crypto";
import { prisma } from "./prisma";

interface JwtPayload {
  sub?: string;
  email?: string;
  aud?: string | string[];
  iss?: string;
  exp?: number;
  nbf?: number;
  role?: string;
}

interface Jwk {
  kid?: string;
  kty: string;
  alg?: string;
  use?: string;
  crv?: string;
  x?: string;
  y?: string;
  n?: string;
  e?: string;
}

interface JwksResponse {
  keys?: Jwk[];
}

let jwksCache: { expiresAt: number; keys: Jwk[] } | null = null;

const JWKS_CACHE_MS = 10 * 60 * 1000;
const CLOCK_SKEW_SECONDS = 60;

/**
 * Supabase's modern JWT signing-key system exposes public keys through JWKS,
 * so the backend can verify asymmetric user tokens without storing a JWT
 * secret or a service-role key. New Supabase projects use asymmetric signing
 * by default; an optional publishable-key fallback is kept for legacy HS256
 * projects.
 */
async function loadJwks(supabaseUrl: string, forceRefresh = false): Promise<Jwk[]> {
  const now = Date.now();
  if (!forceRefresh && jwksCache && jwksCache.expiresAt > now) {
    return jwksCache.keys;
  }

  const response = await fetch(`${supabaseUrl}/auth/v1/.well-known/jwks.json`, {
    cache: "no-store",
    signal: AbortSignal.timeout(10_000),
  });

  if (!response.ok) {
    throw new Error(`JWKS request failed: ${response.status}`);
  }

  const body = (await response.json()) as JwksResponse;
  const keys = Array.isArray(body.keys) ? body.keys : [];
  if (!keys.length) throw new Error("Supabase JWKS contains no keys");

  jwksCache = { expiresAt: now + JWKS_CACHE_MS, keys };
  return keys;
}

function decodeBase64Url(value: string): Buffer {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return Buffer.from(padded, "base64");
}

function decodeJsonPart<T>(value: string): T {
  return JSON.parse(decodeBase64Url(value).toString("utf8")) as T;
}

function audienceMatches(aud: JwtPayload["aud"], expected: string): boolean {
  if (Array.isArray(aud)) return aud.includes(expected);
  return aud === expected;
}

function verifyAsymmetricJwt(token: string, keys: Jwk[], expectedIssuer: string): JwtPayload {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWT format");

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const header = decodeJsonPart<{ alg?: string; kid?: string }>(encodedHeader);
  const payload = decodeJsonPart<JwtPayload>(encodedPayload);

  if (header.alg !== "ES256" && header.alg !== "RS256") {
    throw new Error(`Unsupported Supabase JWT algorithm: ${header.alg ?? "unknown"}`);
  }

  const candidates = header.kid
    ? keys.filter((key) => key.kid === header.kid)
    : keys;

  if (!candidates.length) throw new Error("No matching Supabase signing key");

  const signingInput = Buffer.from(`${encodedHeader}.${encodedPayload}`, "ascii");
  const signature = decodeBase64Url(encodedSignature);

  let valid = false;
  for (const jwk of candidates) {
    try {
      const publicKey = createPublicKey({
        key: jwk as import("node:crypto").JsonWebKey,
        format: "jwk",
      });
      valid = verifySignature(
        "sha256",
        signingInput,
        {
          key: publicKey,
          ...(header.alg === "ES256" ? { dsaEncoding: "ieee-p1363" as const } : {}),
        },
        signature,
      );
      if (valid) break;
    } catch {
      // Try the next active/previously-used public key from the JWKS set.
    }
  }

  if (!valid) throw new Error("Invalid Supabase JWT signature");

  const now = Math.floor(Date.now() / 1000);
  if (payload.iss !== expectedIssuer) throw new Error("Invalid Supabase JWT issuer");
  if (!audienceMatches(payload.aud, "authenticated")) {
    throw new Error("Invalid Supabase JWT audience");
  }
  if (!payload.exp || payload.exp < now - CLOCK_SKEW_SECONDS) {
    throw new Error("Expired Supabase JWT");
  }
  if (payload.nbf && payload.nbf > now + CLOCK_SKEW_SECONDS) {
    throw new Error("Supabase JWT is not active yet");
  }
  if (!payload.sub) throw new Error("Supabase JWT has no subject");

  return payload;
}

async function verifyLegacyTokenWithAuthServer(
  token: string,
  supabaseUrl: string,
): Promise<JwtPayload | null> {
  const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY?.trim();
  if (!publishableKey) return null;

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    method: "GET",
    headers: {
      apikey: publishableKey,
      Authorization: `Bearer ${token}`,
    },
    cache: "no-store",
    signal: AbortSignal.timeout(10_000),
  });

  if (!response.ok) return null;

  const user = (await response.json()) as { id?: string; email?: string | null };
  if (!user.id) return null;

  return { sub: user.id, email: user.email ?? undefined };
}

async function findProfileWithRetry(sub: string) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const profile = await prisma.user.findUnique({
      where: { id: sub },
      select: { role: true, tier: true, email: true },
    });
    if (profile) return profile;
    if (attempt < 2) await new Promise((resolve) => setTimeout(resolve, 150));
  }
  return null;
}

export interface AuthenticatedUser {
  sub: string;
  email: string;
  role: string;
  tier: string;
}

/**
 * Validate a Supabase access token without a service-role key. Modern
 * asymmetric projects are verified locally through the public JWKS endpoint;
 * legacy HS256 projects can fall back to Supabase Auth when a publishable key
 * is configured.
 */
export async function verifySupabaseAccessToken(
  token: string,
): Promise<AuthenticatedUser | null> {
  const supabaseUrl = process.env.SUPABASE_URL?.replace(/\/$/, "");
  if (!supabaseUrl || !token) return null;

  try {
    let claims: JwtPayload;
    try {
      const keys = await loadJwks(supabaseUrl);
      claims = verifyAsymmetricJwt(token, keys, `${supabaseUrl}/auth/v1`);
    } catch {
      // A legacy HS256 project does not expose a symmetric verification key in
      // JWKS. Use Supabase Auth itself if the optional publishable key exists.
      const legacy = await verifyLegacyTokenWithAuthServer(token, supabaseUrl);
      if (!legacy) return null;
      claims = legacy;
    }

    const sub = claims.sub?.trim() ?? "";
    if (!sub) return null;

    const profile = await findProfileWithRetry(sub);
    if (!profile) return null;

    return {
      sub,
      email: profile.email || claims.email || "",
      role: profile.role,
      tier: profile.tier,
    };
  } catch {
    return null;
  }
}
