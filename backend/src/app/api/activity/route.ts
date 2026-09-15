import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getAuthenticatedUser } from "@/lib/auth";

export const runtime = "nodejs";

export async function GET(
  req: NextRequest
) {
  const payload =
    await getAuthenticatedUser(req);

  if (!payload) {
    return NextResponse.json(
      { error: "No autorizado" },
      { status: 401 }
    );
  }

  const items =
    await prisma.userActivity.findMany({
      where: {
        userId: payload.sub
      },

      orderBy: {
        createdAt: "desc"
      },

      take: 25
    });

  return NextResponse.json({
    items
  });
}
