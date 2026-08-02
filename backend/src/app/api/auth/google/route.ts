import { NextRequest, NextResponse } from "next/server";
import { randomBytes } from "crypto";

export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  try {
    const clientId = process.env.GOOGLE_CLIENT_ID;
    if (!clientId) {
      return NextResponse.json(
        { ok: false, error: "GOOGLE_CLIENT_ID no configurado" },
        { status: 500 }
      );
    }

    const state = randomBytes(16).toString("hex");
    const redirectUri = new URL("/api/auth/google/callback", req.nextUrl.origin).toString();

    const authUrl = new URL("https://accounts.google.com/o/oauth2/v2/auth");
    authUrl.searchParams.set("client_id", clientId);
    authUrl.searchParams.set("redirect_uri", redirectUri);
    authUrl.searchParams.set("response_type", "code");
    authUrl.searchParams.set("scope", "openid email profile");
    authUrl.searchParams.set("access_type", "offline");
    authUrl.searchParams.set("prompt", "select_account");
    authUrl.searchParams.set("state", state);

    const response = NextResponse.redirect(authUrl.toString());

    response.cookies.set("wren_google_oauth_state", state, {
      httpOnly: true,
      sameSite: "lax",
      secure: req.nextUrl.protocol === "https:",
      path: "/api/auth/google",
      maxAge: 10 * 60,
    });

    return response;
  } catch (error) {
    console.error("Google OAuth start error:", error);
    return NextResponse.json(
      { ok: false, error: "No se pudo iniciar Google" },
      { status: 500 }
    );
  }
}
