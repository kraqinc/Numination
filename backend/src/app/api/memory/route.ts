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

  const { searchParams } =
    new URL(req.url);

  const projectId =
    searchParams.get("projectId");

  const memories =
    await prisma.memory.findMany({
      where: {
        userId: payload.sub,
        ...(projectId
          ? { projectId }
          : {})
      },

      orderBy: [
        { pinned: "desc" },
        { updatedAt: "desc" }
      ],

      take: 100
    });

  return NextResponse.json({
    memories
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
      title: string;
      content: string;
      type?: string;
      projectId?: string | null;
      pinned?: boolean;
    };

  if (
    !body.title?.trim() ||
    !body.content?.trim()
  ) {
    return NextResponse.json(
      {
        error:
          "title y content son requeridos"
      },
      { status: 400 }
    );
  }

  const memory =
    await prisma.memory.create({
      data: {
        userId: payload.sub,
        projectId:
          body.projectId ?? null,
        title: body.title.trim(),
        content: body.content.trim(),
        type:
          body.type ?? "PROJECT",
        pinned:
          Boolean(body.pinned)
      }
    });

  return NextResponse.json(
    { memory },
    { status: 201 }
  );
}
