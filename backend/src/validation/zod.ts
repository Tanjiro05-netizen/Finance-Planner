type ZodIssue = {
  path: Array<string | number>;
  message: string;
};

type ZodErrorLike = {
  issues: ZodIssue[];
  message: string;
};

export type SafeParseResult =
  | {
      success: true;
      data: unknown;
    }
  | {
      success: false;
      error: ZodErrorLike;
    };

export type ZodSchema = {
  safeParse(value: unknown): SafeParseResult;
  optional(): ZodSchema;
  default(value: unknown): ZodSchema;
  refine(check: (value: any) => boolean, message: string): ZodSchema;
  url(): ZodSchema;
  min(value: number): ZodSchema;
  max(value: number): ZodSchema;
  int(): ZodSchema;
  positive(): ZodSchema;
  strict(): ZodSchema;
  passthrough(): ZodSchema;
};

type ZodFactory = {
  object(shape: Record<string, ZodSchema>): ZodSchema;
  string(): ZodSchema;
  number(): ZodSchema;
  enum(values: readonly string[]): ZodSchema;
  preprocess(preprocess: (value: unknown) => unknown, schema: ZodSchema): ZodSchema;
  coerce: {
    number(): ZodSchema;
  };
};

function loadZod(moduleName: string): { z: ZodFactory } {
  const runtimeRequire = eval("require") as (name: string) => unknown;
  return runtimeRequire(moduleName) as { z: ZodFactory };
}

export const z = loadZod("zod").z;
