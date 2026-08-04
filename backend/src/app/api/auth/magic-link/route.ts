import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  generateMagicLinkToken,
  hashMagicLinkToken,
  isValidEmail,
  normalizeEmail,
} from "@/lib/verification";
import { sendWrenMagicLinkEmail } from "@/lib/email";

export const runtime = "nodejs";

// El deep link vuelve directo a la app -- Android intercepta este esquema
// (ver AndroidManifest.xml: scheme="numination" host="auth") y nunca abre
// una página web intermedia.
const APP_DEEP_LINK_SCHEME = "numination://auth";

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

    const token = generateMagicLinkToken();
    // Reutilizamos la tabla LoginCode: codeHash guarda el hash del token de
    // Magic Link en vez del hash del código de 6 dígitos. Mismo esquema de
    // expiración y de un solo uso, sin necesitar una migración de Prisma.
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    await prisma.loginCode.upsert({
      where: { email },
      update: {
        codeHash: hashMagicLinkToken(token),
        expiresAt,
        attempts: 0,
      },
      create: {
        email,
        codeHash: hashMagicLinkToken(token),
        expiresAt,
        attempts: 0,
      },
    });

    const existingUser = await prisma.user.findUnique({ where: { email } });
    const link = `${APP_DEEP_LINK_SCHEME}?magic=${token}&email=${encodeURIComponent(email)}`;

    try {
      await sendWrenMagicLinkEmail({
        to: email,
        link,
        purpose: existingUser ? "login" : "signup",
      });
    } catch (emailError) {
      console.error("sendWrenMagicLinkEmail error:", emailError);
      if (process.env.NODE_ENV !== "production") {
        return NextResponse.json({
          ok: true,
          message: "Modo desarrollo: no se pudo enviar el correo, pero aquí tienes el enlace.",
          devLink: link,
        });
      }
      throw emailError;
    }

    return NextResponse.json({
      ok: true,
      message: "Te enviamos un enlace de acceso a tu correo.",
    });
  } catch (error) {
    console.error("magic-link request error:", error);
    return NextResponse.json(
      { ok: false, error: "No se pudo enviar el enlace" },
      { status: 500 }
    );
  }
}
