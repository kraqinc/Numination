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
  const clientId = process.env.GITHUB_CLIENT_ID;
  const clientSecret = process.env.GITHUB_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error("GITHUB_CLIENT_ID o GITHUB_CLIENT_SECRET no configurados");
  }

  const body = new URLSearchParams({
    code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirectUri,
  });

  const res = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: body.toString(),
  });

  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new Error(`Error intercambiando code por token: ${res.status} ${JSON.stringify(data)}`);
  }

  return data as { access_token?: string; scope?: string; token_type?: string };
}

async function fetchGithubUser(accessToken: string) {
  const [userRes, emailRes] = await Promise.all([
    fetch("https://api.github.com/user", {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "User-Agent": "NuminationAI",
        Accept: "application/vnd.github+json",
      },
    }),
    fetch("https://api.github.com/user/emails", {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "User-Agent": "NuminationAI",
        Accept: "application/vnd.github+json",
      },
    }),
  ]);

  const user = await userRes.json().catch(() => ({}));
  const emails = await emailRes.json().catch(() => ([]));

  return {
    id: user.id ? String(user.id) : undefined,
    name: user.name ? String(user.name) : undefined,
    login: user.login ? String(user.login) : undefined,
    email: Array.isArray(emails)
      ? emails.find((item: any) => item?.primary && item?.verified)?.email ?? emails.find((item: any) => item?.verified)?.email
      : undefined,
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
        { ok: false, error: `GitHub OAuth falló: ${error}${errorDescription ? ` - ${errorDescription}` : ""}` },
        { status: 400 }
      );
    }

    if (!code || !state) {
      return NextResponse.json({ ok: false, error: "Faltan parámetros de OAuth" }, { status: 400 });
    }

    const storedState = req.cookies.get("numination_github_oauth_state")?.value;
    if (!storedState || storedState !== state) {
      return NextResponse.json({ ok: false, error: "Estado OAuth inválido" }, { status: 401 });
    }

    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      return NextResponse.json({ ok: false, error: "JWT_SECRET no configurado" }, { status: 500 });
    }

    const redirectUri = new URL("/api/auth/github/callback", req.nextUrl.origin).toString();
    const tokenData = await exchangeCodeForTokens(code, redirectUri);
    if (!tokenData.access_token) {
      return NextResponse.json({ ok: false, error: "GitHub no devolvió access_token" }, { status: 500 });
    }

    const githubUser = await fetchGithubUser(tokenData.access_token);
    const email = String(githubUser.email ?? "").trim().toLowerCase();
    const displayName = String(githubUser.name ?? githubUser.login ?? email.split("@")[0] ?? "Numination User").trim();

    if (!email) {
      return NextResponse.json({ ok: false, error: "GitHub no devolvió un correo verificado" }, { status: 401 });
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
      { sub: user.id, email: user.email, role: user.role, tier: user.tier },
      jwtSecret
    );

    const redirectUrl = new URL("numination://auth");
    redirectUrl.searchParams.set("token", token);
    redirectUrl.searchParams.set("email", user.email);
    redirectUrl.searchParams.set("name", displayName);
    redirectUrl.searchParams.set("provider", "github");

    const html = `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Numination · GitHub</title>
  <style>
    body { margin:0; font-family: Inter, Arial, sans-serif; background:#0b0d10; color:#f3f5f7; display:grid; place-items:center; min-height:100vh; padding:24px; text-align:center; }
    .card { max-width:560px; width:100%; background:#11151a; border:1px solid #232833; border-radius:22px; padding:28px; box-sizing:border-box; }
    .brand { font-size:28px; font-weight:800; letter-spacing:2px; margin-bottom:14px; }
    .msg { color:#9ca3af; line-height:1.6; margin:0 0 18px 0; }
    a { color:#27e7ff; text-decoration:none; }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">NUMINATION</div>
    <p class="msg">Login con GitHub completado. Volviendo a la app...</p>
    <p class="msg" style="margin-top:18px">Si no vuelves automáticamente, toca <a href="${redirectUrl.toString()}">continuar</a>.</p>
  </div>
  <script>
    setTimeout(() => window.location.replace(${JSON.stringify(redirectUrl.toString())}), 1200);
  </script>
</body>
</html>`;

    const response = new NextResponse(html, {
      status: 200,
      headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" },
    });

    response.cookies.set("numination_github_oauth_state", "", {
      httpOnly: true,
      sameSite: "lax",
      secure: req.nextUrl.protocol === "https:",
      path: "/api/auth/github",
      maxAge: 0,
    });

    return response;
  } catch (error) {
    console.error("GitHub OAuth callback error:", error);
    return NextResponse.json({ ok: false, error: "Error interno en GitHub OAuth" }, { status: 500 });
  }
}
