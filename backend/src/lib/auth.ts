import { NextRequest } from "next/server";
import { verifySupabaseAccessToken } from "./supabaseAuth";

/**
 * Misma firma que antes (cuando verificaba el JWT propio): toma el header
 * Authorization: Bearer <token> y devuelve { sub, email, role, tier } o
 * null. El token ahora es el access_token de la sesion de Supabase que
 * Android obtiene directamente de supabase.auth (Google ID token, GitHub
 * OAuth o Email OTP) -- este backend ya no emite ni verifica tokens propios.
 */
export async function getAuthenticatedUser(req: NextRequest) {
  const authHeader = req.headers.get("authorization") || "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) return null;
  return verifySupabaseAccessToken(token);
}
