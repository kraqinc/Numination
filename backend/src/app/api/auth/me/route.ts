import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getAuthenticatedUser } from "@/lib/auth";

export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  const payload = await getAuthenticatedUser(req);

  if (!payload) {
    return NextResponse.json(
      { error: "No autorizado" },
      { status: 401 }
    );
  }

  const user = await prisma.user.upsert({
    where: {
      id: payload.sub,
    },
    create: {
      id: payload.sub,
      email: payload.email,
      role: payload.role,
      tier: payload.tier,
    },
    update: {
      email: payload.email,
    },
  });

  await prisma.credits.upsert({
    where: {
      userId: payload.sub,
    },
    create: {
      userId: payload.sub,
      balance: 50,
    },
    update: {},
  });

  const credits = await prisma.credits.findUnique({
    where: {
      userId: payload.sub,
    },
  });

  return NextResponse.json({
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      tier: user.tier,
      balance: credits?.balance ?? 0,
    },
  });
}
