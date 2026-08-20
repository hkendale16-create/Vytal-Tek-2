/** Product catalog mirrored from the Flutter SubscriptionCatalog. */
export type ProductDef = {
  id: string;
  tier: "plus" | "pro" | "complete";
  displayName: string;
  entitlements: string[];
};

export const SUBSCRIPTION_PRODUCTS: Record<string, ProductDef> = {
  "vytal.plus.monthly": {
    id: "vytal.plus.monthly",
    tier: "plus",
    displayName: "Vytal Plus",
    entitlements: [
      "ai.basic",
      "analytics.basic",
      "analytics.advanced",
      "recovery.advanced",
      "sleep.advanced",
      "workouts.custom",
      "workouts.ai_generated",
      "history.extended",
      "calendar.basic",
      "calendar.advanced",
      "plans.basic",
      "plans.advanced",
      "progress.basic",
      "progress.advanced",
      "gyms.nearby",
      "exercises.library",
    ],
  },
  "vytal.pro.monthly": {
    id: "vytal.pro.monthly",
    tier: "pro",
    displayName: "Vytal Pro",
    entitlements: [
      "ai.basic",
      "ai.advanced",
      "ai.workout_builder",
      "analytics.basic",
      "analytics.advanced",
      "recovery.advanced",
      "sleep.advanced",
      "digital_body.advanced",
      "workouts.custom",
      "workouts.ai_generated",
      "history.extended",
      "calendar.basic",
      "calendar.advanced",
      "plans.basic",
      "plans.advanced",
      "progress.basic",
      "progress.advanced",
      "gyms.nearby",
      "exercises.library",
    ],
  },
  "vytal.complete.monthly": {
    id: "vytal.complete.monthly",
    tier: "complete",
    displayName: "Vytal Complete",
    entitlements: [
      "ai.basic",
      "ai.advanced",
      "ai.workout_builder",
      "analytics.basic",
      "analytics.advanced",
      "recovery.advanced",
      "sleep.advanced",
      "digital_body.advanced",
      "workouts.custom",
      "workouts.ai_generated",
      "history.extended",
      "calendar.basic",
      "calendar.advanced",
      "plans.basic",
      "plans.advanced",
      "progress.basic",
      "progress.advanced",
      "gyms.nearby",
      "exercises.library",
    ],
  },
};

export function entitlementSnapshot(product: ProductDef, lifecycle = "active") {
  const renews = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  return {
    tier: product.tier,
    enabled: product.entitlements,
    lifecycle,
    productId: product.id,
    expiresAt: renews,
    renewsAt: renews,
    willRenew: lifecycle === "active" || lifecycle === "canceledActive",
    verificationSource: "serverVerified",
    lastVerifiedAt: new Date().toISOString(),
  };
}
