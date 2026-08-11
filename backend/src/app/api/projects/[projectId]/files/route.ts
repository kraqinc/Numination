iimport { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getAuthenticatedUser } from "@/lib/auth";

export const runtime = "nodejs";

async function ownsProject(
  userId: string,
  projectId: string
) {
  const project =
    await prisma.project.findUnique({
      where: { id: projectId }
    });

  return project?.userId === userId;
}

export async function GET(
  req: NextRequest,
  {
    params
  }: {
    params: {
      projectId: string;
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

  if (
    !(await ownsProject(
      payload.sub,
      params.projectId
    ))
  ) {
    return NextResponse.json(
      {
        error:
          "No autorizado"
      },
      { status: 403 }
    );
  }

  const files =
    await prisma.projectFile.findMany({
      where: {
        projectId:
          params.projectId
      },

      orderBy: {
        path: "asc"
      }
    });

  return NextResponse.json({
    files
  });
}

export async function POST(
  req: NextRequest,
  {
    params
  }: {
    params: {
      projectId: string;
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

  if (
    !(await ownsProject(
      payload.sub,
      params.projectId
    ))
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
      name: string;
      path: string;
      isDirectory?: boolean;
      content?: string;
      parentId?: string | null;
    };

  const file =
    await prisma.projectFile.create({
      data: {
        projectId:
          params.projectId,
        name: body.name,
        path: body.path,
        isDirectory:
          Boolean(
            body.isDirectory
          ),
        content:
          body.isDirectory
            ? null
            : body.content ?? "",
        parentId:
          body.parentId ?? null
      }
    });

  return NextResponse.json(
    { file },
    { status: 201 }
  );
}
