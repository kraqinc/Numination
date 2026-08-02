import { NextRequest, NextResponse } from "next/server";
import { randomBytes } from "crypto";
import { prisma } from "@/lib/prisma";
import {
  generateFallbackPasswordHash,
  hashCode,
  isValidEmail,
  normalizeEmail,
} from "@/lib/verification";
import { signJwt } from "@/lib/jwt";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const email = normalizeEmail(body.email);
    const code = String(body.code || "").trim();

    if (!email || !isValidEmail(email)) {
      return NextResponse.json(
        { ok: false, error: "Correo inválido" },
        { status: 400 }
      );
    }

    if (!/^\d{6}$/.test(code)) {
      return NextResponse.json(
        { ok: false, error: "El código debe tener 6 dígitos" },
        { status: 400 }
      );
    }

    const secret = process.env.JWT_SECRET;
    if (!secret) {
      return NextResponse.json(
        { ok: false, error: "JWT_SECRET no configurado" },
        { status: 500 }
      );
    }

    const record = await prisma.loginCode.findUnique({ where: { email } });

    if (!record) {
      return NextResponse.json(
        { ok: false, error: "Código inválido o vencido" },
        { status: 401 }
      );
    }

    if (record.expiresAt.getTime() < Date.now()) {
      await prisma.loginCode.deleteMany({ where: { email } }).catch(() => {});
      return NextResponse.json(
        { ok: false, error: "Código inválido o vencido" },
        { status: 401 }
      );
    }

    if (record.attempts >= 5) {
      return NextResponse.json(
        { ok: false, error: "Demasiados intentos" },
        { status: 429 }
      );
    }

    if (hashCode(code) !== record.codeHash) {
      await prisma.loginCode.update({
        where: { email },
        data: { attempts: { increment: 1 } },
      });

      return NextResponse.json(
        { ok: false, error: "Código inválido o vencido" },
        { status: 401 }
      );
    }

    let user = await prisma.user.findUnique({ where: { email } });

    if (!user) {
      user = await prisma.user.create({
        data: {
          email,
          passwordHash: generateFallbackPasswordHash(),
          credits: {
            create: { balance: 50 },
          },
        },
      });
    }

    const credits = await prisma.credits.upsert({
      where: { userId: user.id },
      update: {},
      create: {
        userId: user.id,
        balance: 50,
      },
    });

    const token = await signJwt(
      {
        sub: user.id,
        email: user.email,
        role: user.role,
        tier: user.tier,
      },
      secret
    );

    await prisma.loginCode.deleteMany({ where: { email } }).catch(() => {});

    return NextResponse.json({
      ok: true,
      message: "Sesión iniciada",
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        tier: user.tier,
        balance: credits.balance,
      },
    });
  } catch (error) {
    console.error("verify-code error:", error);
    return NextResponse.json(
      { ok: false, error: "Error interno de autenticación" },
      { status: 500 }
    );
  }
}
