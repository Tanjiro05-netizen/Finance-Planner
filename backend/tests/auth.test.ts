import { describe, expect, test } from "vitest";
import { createServiceContext } from "./helpers";

describe("auth", () => {
  test("bootstrap tokens verify and malformed tokens are rejected", async () => {
    const context = createServiceContext();
    const { token } = await context.authService.bootstrap();

    await expect(context.authService.verifyToken(token)).resolves.toEqual(expect.any(String));
    await expect(context.authService.verifyToken("not-a-token")).rejects.toMatchObject({
      statusCode: 401,
      code: "unauthorized"
    });
  });
});
