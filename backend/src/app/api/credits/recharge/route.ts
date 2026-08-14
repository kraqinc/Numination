import { NextRequest, NextResponse } from "next/server";
import { getAuthenticatedUser } from "@/lib/auth";
import { createPendingRecharge, paypalCheckoutUrl } from "@/lib/billing";

export const runtime = "nodejs";

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
