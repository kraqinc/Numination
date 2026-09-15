import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url);
    const platform = url.searchParams.get("platform") ?? "android";

    const dbVersion = await prisma.appVersion.findFirst({
      where: { platform },
      orderBy: { createdAt: "desc" },
    });

    const version = dbVersion?.version ?? process.env.APP_VERSION ?? "1.0.0";
    const downloadUrl = dbVersion?.downloadUrl ?? process.env.APP_DOWNLOAD_URL ?? "";
    const notes = dbVersion?.notes ?? null;
    const mandatory = dbVersion?.mandatory ?? (process.env.APP_AUTO_UPDATE_ENABLED === "true");
    const supportedLanguages = (process.env.SUPPORTED_LANGUAGES ?? "es,en,pt,ru,af,en-GB,zh,ja,ar")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);

    return NextResponse.json({
      ok: true,
      platform,
      version,
      downloadUrl,
      notes,
      mandatory,
      supportedLanguages,
    });
  } catch (error) {
    console.error("Version metadata error:", error);
    return NextResponse.json({ ok: false, error: "No se pudo obtener la versión" }, { status: 500 });
  }
}
