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

  const notifications =
    await prisma.notification.findMany({
      where: {
        userId: payload.sub
      },

      orderBy: {
        createdAt: "desc"
      },

      take: 100
    });

  const unread =
    notifications.filter(
      notification =>
        !notification.read
    ).length;

  return NextResponse.json({
    notifications,
    unread
  });
}

export async function POST(
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

  const body =
    (await req.json()) as {
      action?: string;
      id?: string;
    };

  if (
    body.action ===
    "mark_all_read"
  ) {
    await prisma.notification.updateMany({
      where: {
        userId: payload.sub,
        read: false
      },

      data: {
        read: true
      }
    });

    return NextResponse.json({
      ok: true
    });
  }

  if (
    body.action === "mark_read" &&
    body.id
  ) {
    await prisma.notification.updateMany({
      where: {
        id: body.id,
        userId: payload.sub
      },

      data: {
        read: true
      }
    });

    return NextResponse.json({
      ok: true
    });
  }

  return NextResponse.json(
    {
      error: "Acción inválida"
    },
    {
      status: 400
    }
  );
}
