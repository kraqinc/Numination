import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getAuthenticatedUser } from "@/lib/auth";
import {
  createPendingRecharge,
  getPublicBillingPlans,
  PAYPAL_ME_URL,
  paypalCheckoutUrl,
} from "@/lib/billing";

export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  const payload = await getAuthenticatedUser(req);
  if (!payload) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const [credits, profile, pending] = await Promise.all([
    prisma.credits.findUnique({ where: { userId: payload.sub } }),
    prisma.user.findUnique({
      where: { id: payload.sub },
      select: { proExpiresAt: true },
    }),
    prisma.pendingRecharge.findMany({
      where: { userId: payload.sub, status: "PENDING" },
      orderBy: { createdAt: "desc" },
    }),
  ]);

  return NextResponse.json({
    balance: credits?.balance ?? 0,
    tier: payload.tier,
    proExpiresAt: profile?.proExpiresAt ?? null,
    pending: pending.map((recharge) => ({
      id: recharge.id,
      package_id: recharge.packageId,
      credit_amount: recharge.creditAmount,
      price_label: recharge.priceLabel,
      plan_tier: recharge.planTier,
      tier_duration_days: recharge.tierDurationDays,
      reference_code: recharge.referenceCode,
      status: recharge.status,
      created_at: recharge.createdAt,
      user_email: payload.email,
      user_id: recharge.userId,
    })),
    paypalMeUrl: PAYPAL_ME_URL,
    plans: getPublicBillingPlans(),
  });
}

export async function POST(req: NextRequest) {
  const payload = await getAuthenticatedUser(req);
  if (!payload) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const { packageId } = (await req.json()) as { packageId: string };
  const result = await createPendingRecharge(payload.sub, packageId);
  if (!result) {
    return NextResponse.json({ error: "Paquete inválido" }, { status: 400 });
  }

  const { plan, recharge } = result;

  return NextResponse.json({
    message: "Solicitud creada. Copia el código de referencia en la nota de tu pago de PayPal.",
    requestId: recharge.id,
    referenceCode: recharge.referenceCode,
    credits: plan.credits,
    priceLabel: plan.priceLabel,
    planTier: plan.tier ?? null,
    tierDurationDays: plan.tierDurationDays ?? null,
    paypalUrl: paypalCheckoutUrl(plan),
    status: "PENDING",
  });
}
