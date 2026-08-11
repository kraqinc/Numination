import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getAuthenticatedUser } from "@/lib/auth";

export const runtime = "nodejs";

/**
 * Unica ruta de "auth" que le queda al backend, y no verifica nada de
 * Google/GitHub -- solo confirma la sesion de Supabase ya establecida (igual
 * que /credits, /projects, etc.) y devuelve el perfil de aplicacion
 * (role/tier/balance) que Supabase no guarda en el JWT. Android la llama una
 * vez justo despues de un login exitoso con Supabase para poblar
 * SessionManager (antes esos datos venian embebidos en el JWT propio).
 */
export async function GET(req: NextRequest) {
  const payload = await getAuthenticatedUser(req);
  if (!payload) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const credits = await prisma.credits.findUnique({ where: { userId: payload.sub } });

  return NextResponse.json({
    user: {
      id: payload.sub,
      email: payload.email,
      role: payload.role,
      tier: payload.tier,
      balance: credits?.balance ?? 0,
    },
  });
}
