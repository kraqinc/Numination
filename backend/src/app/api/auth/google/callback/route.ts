import { NextRequest, NextResponse } from "next/server";
import { createHash, randomBytes } from "crypto";
import { prisma } from "@/lib/prisma";
import { signJwt } from "@/lib/jwt";

export const runtime = "nodejs";

function hashPassword(value: string): string {
  return createHash("sha256").update(value + "wren-salt").digest("hex");
}

function generateFallbackPasswordHash(): string {
  return hashPassword(randomBytes(32).toString("hex"));
}

async function exchangeCodeForTokens(code: string, redirectUri: string) {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error("GOOGLE_CLIENT_ID o GOOGLE_CLIENT_SECRET no configurados");
  }

  const body = new URLSearchParams({
    code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirectUri,
    grant_type: "authorization_code",
  });

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: body.toString(),
  });

  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new Error(
      `Error intercambiando code por token: ${res.status} ${JSON.stringify(data)}`
    );
  }

  return data as {
    access_token?: string;
    id_token?: string;
    expires_in?: number;
    token_type?: string;
    scope?: string;
  };
}

async function fetchGoogleUserInfo(accessToken: string) {
  const res = await fetch("https://www.googleapis.com/oauth2/v2/userinfo", {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new Error(
      `Error obteniendo userinfo: ${res.status} ${JSON.stringify(data)}`
    );
  }

  return data as {
    id?: string;
    email?: string;
    verified_email?: boolean;
    name?: string;
    given_name?: string;
    family_name?: string;
    picture?: string;
  };
}

export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url);
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state");
    const error = url.searchParams.get("error");
    const errorDescription = url.searchParams.get("error_description");

    if (error) {
      return NextResponse.json(
        {
          ok: false,
          error: `Google OAuth falló: ${error}${errorDescription ? ` - ${errorDescription}` : ""}`,
        },
        { status: 400 }
      );
    }

    if (!code || !state) {
      return NextResponse.json(
        { ok: false, error: "Faltan parámetros de OAuth" },
        { status: 400 }
      );
    }

    const storedState = req.cookies.get("wren_google_oauth_state")?.value;
    if (!storedState || storedState !== state) {
      return NextResponse.json(
        { ok: false, error: "Estado OAuth inválido" },
        { status: 401 }
      );
    }

    const clientId = process.env.GOOGLE_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
    const jwtSecret = process.env.JWT_SECRET;

    if (!clientId || !clientSecret || !jwtSecret) {
      return NextResponse.json(
        {
          ok: false,
          error: "Faltan GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET o JWT_SECRET",
        },
        { status: 500 }
      );
    }

    const redirectUri = new URL("/api/auth/google/callback", req.nextUrl.origin).toString();

    const tokenData = await exchangeCodeForTokens(code, redirectUri);
    if (!tokenData.access_token) {
      return NextResponse.json(
        { ok: false, error: "Google no devolvió access_token" },
        { status: 500 }
      );
    }

    const googleUser = await fetchGoogleUserInfo(tokenData.access_token);

    if (!googleUser.email || !googleUser.verified_email) {
      return NextResponse.json(
        { ok: false, error: "Google no devolvió un correo verificado" },
        { status: 401 }
      );
    }

    const email = String(googleUser.email).trim().toLowerCase();
    const displayName =
      googleUser.name?.trim() ||
      googleUser.given_name?.trim() ||
      email.split("@")[0];

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
      jwtSecret
    );

    const payload = {
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        tier: user.tier,
        balance: credits.balance,
      },
    };

    // Deep link de vuelta a la app Android nativa (Custom Tabs cierra y
    // Android abre MainActivity con este Intent). Ya no redirige a ninguna
    // página web de login.
    const redirectUrl = new URL("wren://auth");
    redirectUrl.searchParams.set("token", token);
    redirectUrl.searchParams.set("email", user.email);
    redirectUrl.searchParams.set("name", displayName);
    redirectUrl.searchParams.set("provider", "google");

    const html = `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Numination · Login completado</title>
  <style>
    body {
      margin: 0;
      font-family: Inter, Arial, sans-serif;
      background: #0b0d10;
      color: #f3f5f7;
      display: grid;
      place-items: center;
      min-height: 100vh;
      padding: 24px;
      text-align: center;
    }
    .card {
      max-width: 560px;
      width: 100%;
      background: #11151a;
      border: 1px solid #232833;
      border-radius: 22px;
      padding: 28px;
      box-sizing: border-box;
    }
    .brand {
      font-size: 28px;
      font-weight: 800;
      letter-spacing: 2px;
      margin-bottom: 14px;
    }
    .msg {
      color: #9ca3af;
      line-height: 1.6;
      margin: 0 0 18px 0;
    }
    .token {
      display: inline-block;
      max-width: 100%;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      background: #0d1117;
      border: 1px solid #232833;
      border-radius: 14px;
      padding: 12px 14px;
      color: #27e7ff;
      font-size: 12px;
      margin-top: 10px;
    }
    a {
      color: #27e7ff;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">NUMINATION</div>
    <p class="msg">Login con Google completado. Volviendo a la app...</p>
    <p class="msg" style="margin-top:18px">
      Si no vuelves automáticamente, toca <a href="${redirectUrl.toString()}">continuar</a>.
    </p>
  </div>

  <script>
    (function () {
      const payload = ${JSON.stringify(payload)};

      try {
        if (window.NuminationAuthBridge && typeof window.NuminationAuthBridge.onLoginSuccess === "function") {
          window.NuminationAuthBridge.onLoginSuccess(JSON.stringify(payload));
        }
      } catch (e) {}

      setTimeout(() => {
        window.location.replace(${JSON.stringify(redirectUrl.toString())});
      }, 1200);
    })();
  </script>
</body>
</html>`;

    const response = new NextResponse(html, {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
      },
    });

    response.cookies.set("wren_google_oauth_state", "", {
      httpOnly: true,
      sameSite: "lax",
      secure: req.nextUrl.protocol === "https:",
      path: "/api/auth/google",
      maxAge: 0,
    });

    return response;
  } catch (error) {
    console.error("Google OAuth callback error:", error);
    return NextResponse.json(
      { ok: false, error: "Error interno en Google OAuth" },
      { status: 500 }
    );
  }
}
