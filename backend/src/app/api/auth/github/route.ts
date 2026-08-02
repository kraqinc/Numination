import { NextRequest, NextResponse } from "next/server";
import { randomBytes } from "crypto";

export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  try {
    const clientId = process.env.GITHUB_CLIENT_ID;
    if (!clientId) {
      return NextResponse.json(
        { ok: false, error: "GITHUB_CLIENT_ID no configurado" },
        { status: 500 }
      );
    }

    const state = randomBytes(16).toString("hex");
    const redirectUri = new URL("/api/auth/github/callback", req.nextUrl.origin).toString();

    const authUrl = new URL("https://github.com/login/oauth/authorize");
    authUrl.searchParams.set("client_id", clientId);
    authUrl.searchParams.set("redirect_uri", redirectUri);
    authUrl.searchParams.set("scope", "read:user user:email");
    authUrl.searchParams.set("state", state);

    const response = NextResponse.redirect(authUrl.toString());
    response.cookies.set("numination_github_oauth_state", state, {
      httpOnly: true,
      sameSite: "lax",
      secure: req.nextUrl.protocol === "https:",
      path: "/api/auth/github",
      maxAge: 10 * 60,
    });

    return response;
  } catch (error) {
    console.error("GitHub OAuth start error:", error);
    return NextResponse.json(
      { ok: false, error: "No se pudo iniciar GitHub" },
      { status: 500 }
    );
  }
}
