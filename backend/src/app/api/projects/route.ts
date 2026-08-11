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

  const projects =
    await prisma.project.findMany({
      where: {
        userId: payload.sub
      },

      orderBy: {
        updatedAt: "desc"
      }
    });

  return NextResponse.json({
    projects
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

  const {
    name,
    description
  } =
    (await req.json()) as {
      name: string;
      description?: string;
    };

  if (
    !name ||
    !name.trim()
  ) {
    return NextResponse.json(
      {
        error:
          "El nombre del proyecto es requerido"
      },
      { status: 400 }
    );
  }

  const project =
    await prisma.$transaction(
      async tx => {

        const created =
          await tx.project.create({
            data: {
              userId: payload.sub,
              name: name.trim(),
              description:
                description ?? ""
            }
          });

        await tx.projectFile.create({
          data: {
            projectId: created.id,
            name: "NUMINATION.md",
            path: "NUMINATION.md",
            content:
              `# ${created.name}

## Project Overview
${created.description || "Sin descripción todavía."}

## Architecture
- Mantener aquí las decisiones de arquitectura importantes.

## Important Decisions
- Ninguna registrada todavía.

## Current Tasks
- Definir el primer objetivo del proyecto.

## Known Bugs
- Ninguno registrado todavía.

## User Preferences
- Usar el espacio de trabajo de Numination para mantener el contexto.

## Important Files
- NUMINATION.md

## Recent AI Work
- Proyecto creado por Numination.
`
          }
        });

        await tx.userActivity.create({
          data: {
            userId: payload.sub,
            type:
              "PROJECT_CREATED",
            description:
              `Proyecto creado: ${created.name}`,
            projectId:
              created.id
          }
        });

        await tx.notification.create({
          data: {
            userId: payload.sub,
            type:
              "PROJECT_CREATED",
            title:
              "Proyecto creado",
            message:
              `${created.name} ya está listo para trabajar.`
          }
        });

        return created;
      }
    );

  return NextResponse.json(
    { project },
    { status: 201 }
  );
}
