import { describe, expect, test } from "vitest";
import { createServiceContext, createUserId } from "./helpers";

describe("cancellations", () => {
  test("creates, lists, advances, and isolates requests by user", async () => {
    const context = createServiceContext();
    const userAId = await createUserId(context);
    const userBId = await createUserId(context);

    const created = await context.cancellationService.create({
      userId: userAId,
      subscriptionRef: "sub-streambox",
      merchantName: "Streambox",
      method: "concierge"
    });

    expect(created.status).toBe("requested");
    await expect(context.cancellationService.list(userAId)).resolves.toHaveLength(1);
    await expect(context.cancellationService.list(userBId)).resolves.toEqual([]);
    await expect(
      context.cancellationService.advance({
        userId: userBId,
        id: created.id,
        status: "contacting"
      })
    ).rejects.toMatchObject({
      statusCode: 404
    });

    await expect(
      context.cancellationService.advance({
        userId: userAId,
        id: created.id,
        status: "contacting"
      })
    ).resolves.toMatchObject({
      status: "contacting"
    });

    await expect(
      context.cancellationService.advance({
        userId: userAId,
        id: created.id,
        status: "cancelledByUser",
        note: "User confirmed the guided cancellation."
      })
    ).resolves.toMatchObject({
      status: "cancelledByUser",
      note: "User confirmed the guided cancellation."
    });
  });

  test("rejects concierge requests when launch flag is guided-only", async () => {
    const context = createServiceContext({ conciergeEnabled: false });
    const userId = await createUserId(context);

    await expect(
      context.cancellationService.create({
        userId,
        subscriptionRef: "sub-streambox",
        merchantName: "Streambox",
        method: "concierge"
      })
    ).rejects.toMatchObject({
      statusCode: 403,
      code: "feature_disabled"
    });

    await expect(
      context.cancellationService.create({
        userId,
        subscriptionRef: "sub-streambox",
        merchantName: "Streambox",
        method: "guided"
      })
    ).resolves.toMatchObject({
      method: "guided",
      status: "requested"
    });
  });
});
