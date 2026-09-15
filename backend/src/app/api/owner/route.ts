import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getAuthenticatedUser } from "@/lib/auth";

export const runtime = "nodejs";

async function requireOwner(req: NextRequest) {
  const payload = await getAuthenticatedUser(req);
  if (!payload || payload.role !== "OWNER") return null;
  return payload;
}

export async function GET(req: NextRequest) {
  const owner = await requireOwner(req);
  if (!owner) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const { searchParams } = new URL(req.url);
  const view = searchParams.get("view") ?? "stats";

  if (view === "pending-recharges") {
    const pending = await prisma.pendingRecharge.findMany({
      where: { status: "PENDING" },
      include: { user: { select: { email: true } } },
      orderBy: { createdAt: "asc" },
    });
    return NextResponse.json({
      requests: pending.map((r) => ({
        id: r.id,
        package_id: r.packageId,
        credit_amount: r.creditAmount,
        price_label: r.priceLabel,
        plan_tier: r.planTier,
        tier_duration_days: r.tierDurationDays,
        reference_code: r.referenceCode,
        status: r.status,
        created_at: r.createdAt,
        user_email: r.user.email,
        user_id: r.userId,
      })),
    });
  }

  if (view === "users") {
    const users = await prisma.user.findMany({
      include: { credits: true },
      orderBy: { createdAt: "desc" },
    });
    return NextResponse.json({
      users: users.map((u) => ({
        id: u.id,
        email: u.email,
        role: u.role,
        tier: u.tier,
        balance: u.credits?.balance ?? 0,
      })),
    });
  }

  if (view === "audit-logs") {
    const logs = await prisma.auditLog.findMany({
      include: { actor: { select: { email: true } } },
      orderBy: { timestamp: "desc" },
    });
    return NextResponse.json({
      logs: logs.map((log) => ({
        id: log.id,
        action: log.action,
        details: log.details,
        timestamp: log.timestamp,
        actor_email: log.actor.email,
      })),
    });
  }

  // stats
  const [totalUsers, totalProjects, creditsAgg, auditLogsCount] = await Promise.all([
    prisma.user.count(),
    prisma.project.count(),
    prisma.credits.aggregate({ _sum: { balance: true } }),
    prisma.auditLog.count(),
  ]);

  return NextResponse.json({
    metrics: {
      totalUsers,
      totalProjects,
      circulatingCredits: creditsAgg._sum.balance ?? 0,
      auditLogsLogged: auditLogsCount,
    },
  });
}

export async function POST(req: NextRequest) {
  const owner = await requireOwner(req);
  if (!owner) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const { action, requestId, userId, amount, reason } = (await req.json()) as {
    action: "approve" | "reject" | "adjust-credits";
    requestId?: string;
    userId?: string;
    amount?: number;
    reason?: string;
  };

  if (action === "approve" || action === "reject") {
    if (!requestId) return NextResponse.json({ error: "requestId requerido" }, { status: 400 });

    if (action === "approve") {
      try {
        await prisma.$transaction(async (tx) => {
          const recharge = await tx.pendingRecharge.findUnique({ where: { id: requestId } });
          if (!recharge || recharge.status !== "PENDING") {
            throw new Error("RECHARGE_NOT_PENDING");
          }

          const now = new Date();
          let proExpiresAt: Date | null = null;
          if (recharge.planTier === "PRO" && (recharge.tierDurationDays ?? 0) > 0) {
            const profile = await tx.user.findUnique({
              where: { id: recharge.userId },
              select: { proExpiresAt: true },
            });
            const currentExpiry = profile?.proExpiresAt;
            const startsAt = currentExpiry && currentExpiry > now ? currentExpiry : now;
            proExpiresAt = new Date(startsAt.getTime() + recharge.tierDurationDays! * 86_400_000);
            await tx.user.update({
              where: { id: recharge.userId },
              data: { tier: "PRO", proExpiresAt },
            });
          }

          await tx.credits.upsert({
            where: { userId: recharge.userId },
            update: { balance: { increment: recharge.creditAmount } },
            create: { userId: recharge.userId, balance: recharge.creditAmount },
          });
          await tx.pendingRecharge.update({
            where: { id: requestId },
            data: { status: "APPROVED", resolvedAt: now, resolvedBy: owner.sub },
          });
          await tx.creditLog.create({
            data: {
              userId: recharge.userId,
              amount: recharge.creditAmount,
              reason: `Pago PayPal aprobado: ${recharge.referenceCode}`,
            },
          });
          await tx.userActivity.create({
            data: {
              userId: recharge.userId,
              type: recharge.planTier === "PRO" ? "PRO_ACTIVATED" : "CREDIT_ADDED",
              title: recharge.planTier === "PRO" ? "Numination Pro activado" : "Créditos añadidos",
              description: recharge.planTier === "PRO"
                ? `Pro activo hasta ${proExpiresAt?.toISOString()}`
                : `${recharge.creditAmount} créditos añadidos por PayPal`,
              metadata: { rechargeId: recharge.id, referenceCode: recharge.referenceCode },
            },
          });
          await tx.notification.create({
            data: {
              userId: recharge.userId,
              type: recharge.planTier === "PRO" ? "ACCOUNT" : "CREDITS",
              title: recharge.planTier === "PRO" ? "Bienvenido a Numination Pro" : "Pago confirmado",
              message: recharge.planTier === "PRO"
                ? `Tu acceso Pro está activo hasta ${proExpiresAt?.toLocaleDateString("es-CO")}.`
                : `Añadimos ${recharge.creditAmount} créditos a tu cuenta.`,
              metadata: { rechargeId: recharge.id, referenceCode: recharge.referenceCode },
            },
          });
          await tx.auditLog.create({
            data: {
              actorId: owner.sub,
              action: recharge.planTier === "PRO" ? "PRO_PAYMENT_APPROVED" : "RECHARGE_APPROVED",
              details: `Recarga ${recharge.referenceCode} (+${recharge.creditAmount} créditos) para ${recharge.userId}`,
            },
          });
        });
      } catch (error) {
        if (error instanceof Error && error.message === "RECHARGE_NOT_PENDING") {
          return NextResponse.json({ error: "Solicitud no encontrada o ya resuelta" }, { status: 404 });
        }
        throw error;
      }
    } else {
      const recharge = await prisma.pendingRecharge.findUnique({ where: { id: requestId } });
      if (!recharge || recharge.status !== "PENDING") {
        return NextResponse.json({ error: "Solicitud no encontrada o ya resuelta" }, { status: 404 });
      }
      await prisma.$transaction([
        prisma.pendingRecharge.update({
          where: { id: requestId },
          data: { status: "REJECTED", resolvedAt: new Date(), resolvedBy: owner.sub },
        }),
        prisma.notification.create({
          data: {
            userId: recharge.userId,
            type: "CREDITS",
            title: "Pago no confirmado",
            message: `No pudimos confirmar el pago con referencia ${recharge.referenceCode}.`,
            metadata: { rechargeId: recharge.id, referenceCode: recharge.referenceCode },
          },
        }),
        prisma.auditLog.create({
          data: {
            actorId: owner.sub,
            action: "RECHARGE_REJECTED",
            details: `Recarga ${recharge.referenceCode} rechazada`,
          },
        }),
      ]);
    }

    return NextResponse.json({ message: `Recarga ${action === "approve" ? "aprobada" : "rechazada"}` });
  }

  if (action === "adjust-credits") {
    if (!userId || amount === undefined || !reason) {
      return NextResponse.json({ error: "userId, amount y reason son requeridos" }, { status: 400 });
    }

    await prisma.$transaction([
      prisma.credits.update({ where: { userId }, data: { balance: { increment: amount } } }),
      prisma.creditLog.create({ data: { userId, amount, reason } }),
      prisma.auditLog.create({
        data: {
          actorId: owner.sub,
          action: "MANUAL_CREDIT_ADJUSTMENT",
          details: `${amount >= 0 ? "+" : ""}${amount} créditos para ${userId}. Motivo: ${reason}`,
        },
      }),
    ]);

    return NextResponse.json({ message: "Créditos ajustados" });
  }

  return NextResponse.json({ error: "Acción desconocida" }, { status: 400 });
}
