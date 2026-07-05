import { badRequest } from "../errors";
import { z, type ZodSchema } from "../validation/zod";
import type { NextFunction, Request, RequestHandler, Response } from "./express";

type RequestSchemas = {
  body?: ZodSchema;
  params?: ZodSchema;
  query?: ZodSchema;
};

export const emptyBodySchema = z.preprocess(
  (value) => value ?? {},
  z.object({}).strict()
);

export function validate(schemas: RequestSchemas): RequestHandler {
  return (req: Request, _res: Response, next: NextFunction) => {
    try {
      if (schemas.body) {
        setRequestPart(req, "body", parsePart("body", schemas.body, req.body));
      }

      if (schemas.params) {
        setRequestPart(req, "params", parsePart("params", schemas.params, req.params));
      }

      if (schemas.query) {
        setRequestPart(req, "query", parsePart("query", schemas.query, req.query));
      }

      next();
    } catch (error) {
      next(error);
    }
  };
}

function setRequestPart(req: Request, key: "body" | "params" | "query", value: unknown): void {
  Object.defineProperty(req, key, {
    configurable: true,
    enumerable: true,
    value,
    writable: true
  });
}

function parsePart(name: string, schema: ZodSchema, value: unknown): unknown {
  const parsed = schema.safeParse(value);

  if (!parsed.success) {
    const message = parsed.error.issues
      .map((issue) => `${issue.path.join(".") || name}: ${issue.message}`)
      .join("; ");
    throw badRequest("validation_error", message);
  }

  return parsed.data;
}
