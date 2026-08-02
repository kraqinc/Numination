import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  generateSixDigitCode,
  hashCode,
  isValidEmail,
  normalizeEmail,
} from "@/lib/verification";
import { sendWrenVerificationEmail } from "@/lib/email";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const email = normalizeEmail(body.email);

    if (!email || !isValidEmail(email)) {
      return NextResponse.json(
        { ok: false, error: "Correo inválido" },
        { status: 400 }
      );
    }

    const code = generateSixDigitCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await prisma.loginCode.upsert({
      where: { email },
      update: {
        codeHash: hashCode(code),
        expiresAt,
        attempts: 0,
      },
      create: {
        email,
        codeHash: hashCode(code),
        expiresAt,
        attempts: 0,
      },
    });

    const existingUser = await prisma.user.findUnique({ where: { email } });

    try {
      await sendWrenVerificationEmail({
        to: email,
        code,
        purpose: existingUser ? "login" : "signup",
      });
    } catch (emailError) {
      console.error("sendWrenVerificationEmail error:", emailError);
      if (process.env.NODE_ENV !== "production") {
        return NextResponse.json({
          ok: true,
          message: "Modo desarrollo: no se pudo enviar el correo, pero aquí tienes el código.",
          devCode: code,
        });
      }
      throw emailError;
    }

    return NextResponse.json({
      ok: true,
      message: "Si el correo es válido, te enviamos un código de 6 dígitos.",
    });
  } catch (error) {
    console.error("request-code error:", error);
    return NextResponse.json(
      { ok: false, error: "No se pudo enviar el código" },
      { status: 500 }
    );
  }
}
