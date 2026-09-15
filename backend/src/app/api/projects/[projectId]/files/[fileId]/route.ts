import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getAuthenticatedUser } from "@/lib/auth";

export const runtime = "nodejs";

export async function PUT(
  req: NextRequest,
  {
    params
  }: {
    params: {
      projectId: string;
      fileId: string;
    };
  }
) {
  const payload =
    await getAuthenticatedUser(req);

  if (!payload) {
    return NextResponse.json(
      { error: "No autorizado" },
      { status: 401 }
    );
  }

  const file =
    await prisma.projectFile.findUnique({
      where: {
        id: params.fileId
      }
    });

  const project =
    await prisma.project.findUnique({
      where: {
        id: params.projectId
      }
    });

  if (
    !file ||
    !project ||
    file.projectId !==
      params.projectId ||
    project.userId !==
      payload.sub
  ) {
    return NextResponse.json(
      {
        error:
          "No autorizado"
      },
      { status: 403 }
    );
  }

  const body =
    (await req.json()) as {
      content: string;
    };

  const updated =
    await prisma.projectFile.update({
      where: {
        id: params.fileId
      },

      data: {
        content:
          body.content ?? ""
      }
    });

  return NextResponse.json({
    file: updated
  });
}

export async function DELETE(
  req: NextRequest,
  {
    params
  }: {
    params: {
      projectId: string;
      fileId: string;
    };
  }
) {
  const payload =
    await getAuthenticatedUser(req);

  if (!payload) {
    return NextResponse.json(
      { error: "No autorizado" },
      { status: 401 }
    );
  }

  const file =
    await prisma.projectFile.findUnique({
      where: {
        id: params.fileId
      }
    });

  const project =
    await prisma.project.findUnique({
      where: {
        id: params.projectId
      }
    });

  if (
    !file ||
    !project ||
    file.projectId !==
      params.projectId ||
    project.userId !==
      payload.sub
  ) {
    return NextResponse.json(
      {
        error:
          "No autorizado"
      },
      { status: 403 }
    );
  }

  await prisma.projectFile.delete({
    where: {
      id: params.fileId
    }
  });

  return NextResponse.json({
    ok: true
  });
}
