import { NextRequest, NextResponse } from "next/server";
import { createHash, randomBytes } from "crypto";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { prisma } from "@/lib/prisma";
import { signJwt } from "@/lib/jwt";

export const runtime = "nodejs";

function hashPassword(value: string): string {
  return createHash("sha256").update(value + "wren-salt").digest("hex");
}

function generateFallbackPasswordHash(): string {
  return hashPassword(randomBytes(32).toString("hex"));
}

const GOOGLE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs")
);

export async function POST(req: NextRequest) {
  try {
    const { idToken } = (await req.json()) as { idToken?: string };
    if (!idToken) {
      return NextResponse.json({ ok: false, error: "Falta idToken" }, { status: 400 });
    }

    const jwtSecret = process.env.JWT_SECRET;
    const audienceCandidates = [process.env.GOOGLE_WEB_CLIENT_ID, process.env.GOOGLE_CLIENT_ID].filter(Boolean) as string[];
    if (!jwtSecret || audienceCandidates.length === 0) {
      return NextResponse.json(
        { ok: false, error: "Faltan JWT_SECRET o GOOGLE_WEB_CLIENT_ID/GOOGLE_CLIENT_ID" },
        { status: 500 }
      );
    }

    const { payload } = await jwtVerify(idToken, GOOGLE_JWKS, {
      issuer: ["https://accounts.google.com", "accounts.google.com"],
      audience: audienceCandidates.length === 1 ? audienceCandidates[0] : audienceCandidates,
    });

    const email = String(payload.email ?? "").trim().toLowerCase();
    const emailVerified = payload.email_verified === true || payload.email_verified === "true";
    const displayName = String(payload.name ?? payload.given_name ?? email.split("@")[0] ?? "Numination User").trim();

    if (!email || !emailVerified) {
      return NextResponse.json(
        { ok: false, error: "Google no devolvió un correo verificado" },
        { status: 401 }
      );
    }

    let user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      user = await prisma.user.create({
        data: {
          email,
          passwordHash: generateFallbackPasswordHash(),
          credits: { create: { balance: 50 } },
        },
      });
    }

    const credits = await prisma.credits.upsert({
      where: { userId: user.id },
      update: {},
      create: { userId: user.id, balance: 50 },
    });

    const token = await signJwt(
      {
        sub: user.id,
        email: user.email,
        role: user.role,
        tier: user.tier,
      },
      jwtSecret
    );

    return NextResponse.json({
      ok: true,
      message: "Sesión iniciada con Google",
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        tier: user.tier,
        balance: credits.balance,
        name: displayName,
        provider: "google",
      },
    });
  } catch (error) {
    console.error("Google native login error:", error);
    return NextResponse.json(
      { ok: false, error: "No se pudo verificar Google" },
      { status: 401 }
    );
  }
}
