import { prisma } from "@/lib/prisma";
import { randomUUID } from "crypto";

export const PAYPAL_ME_URL = "https://paypal.me/KraqPro";

export type BillingPlan = {
  id: string;
  title: string;
  credits: number;
  priceUsd: string;
  priceLabel: string;
  bestValue?: boolean;
  tier?: "PRO";
  tierDurationDays?: number;
};

// This is the sole source of truth for prices, credits and entitlement. The
// Android app can display this catalog but never decides any of these values.
const BILLING_PLANS: readonly BillingPlan[] = [
  {
    id: "starter_100",
    title: "Starter Pack",
    credits: 100,
    priceUsd: "1.99",
    priceLabel: "$1.99 USD",
  },
  {
    id: "premium_500",
    title: "Premium Pack",
    credits: 500,
    priceUsd: "6.99",
    priceLabel: "$6.99 USD",
    bestValue: true,
  },
  {
    id: "pro_1500",
    title: "Pro Credits Pack",
    credits: 1500,
    priceUsd: "14.99",
    priceLabel: "$14.99 USD",
  },
  {
    id: "ultra_5000",
    title: "Ultra Pack",
    credits: 5000,
    priceUsd: "39.99",
    priceLabel: "$39.99 USD",
  },
  {
    id: "subscription_monthly",
    title: "Numination Pro",
    credits: 1000,
    priceUsd: "9.99",
    priceLabel: "$9.99 USD / mes",
    tier: "PRO",
    tierDurationDays: 30,
  },
];

export function getBillingPlan(id: string | undefined): BillingPlan | null {
  return BILLING_PLANS.find((plan) => plan.id === id) ?? null;
}

export function getPublicBillingPlans() {
  return BILLING_PLANS.map((plan) => ({ ...plan }));
}

export function paypalCheckoutUrl(plan: BillingPlan): string {
  return `${PAYPAL_ME_URL}/${plan.priceUsd}`;
}

export async function createPendingRecharge(userId: string, packageId: string) {
  const plan = getBillingPlan(packageId);
  if (!plan) return null;

  const referenceCode = `NUM-${randomUUID().replaceAll("-", "").slice(0, 10).toUpperCase()}`;
  const recharge = await prisma.pendingRecharge.create({
    data: {
      userId,
      packageId: plan.id,
      creditAmount: plan.credits,
      priceLabel: plan.priceLabel,
      planTier: plan.tier,
      tierDurationDays: plan.tierDurationDays,
      referenceCode,
      status: "PENDING",
    },
  });

  return { plan, recharge };
}
