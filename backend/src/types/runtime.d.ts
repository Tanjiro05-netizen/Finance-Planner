type BufferEncoding = "utf8" | "base64" | "base64url" | "hex" | string;

interface Buffer extends Uint8Array {
  toString(encoding?: BufferEncoding): string;
}

declare const Buffer: {
  from(value: string | ArrayBuffer | ArrayBufferView, encoding?: BufferEncoding): Buffer;
  alloc(size: number, fill?: number): Buffer;
  concat(values: readonly Buffer[]): Buffer;
};

declare const process: {
  env: Record<string, string | undefined>;
  on(signal: string, listener: () => void): void;
  exit(code?: number): never;
};

declare const performance: {
  now(): number;
};

declare const URL: new (value: string) => unknown;

declare function require(moduleName: string): unknown;

declare module "dotenv/config" {}

declare module "node:crypto" {
  type KeyLike = unknown;

  type Hmac = {
    update(value: string | Buffer): Hmac;
    digest(encoding: BufferEncoding): string;
  };

  type Hash = {
    update(value: string | Buffer): Hash;
    digest(encoding: BufferEncoding): string;
  };

  type Cipher = {
    update(value: string | Buffer, inputEncoding?: BufferEncoding): Buffer;
    final(): Buffer;
    getAuthTag(): Buffer;
  };

  type Decipher = {
    update(value: Buffer): Buffer;
    final(): Buffer;
    setAuthTag(tag: Buffer): void;
  };

  export function createHmac(algorithm: string, key: string | Buffer): Hmac;
  export function timingSafeEqual(left: Buffer, right: Buffer): boolean;
  export function randomUUID(): string;
  export function randomBytes(size: number): Buffer;
  export function createCipheriv(
    algorithm: string,
    key: Buffer,
    iv: Buffer,
    options?: { authTagLength?: number }
  ): Cipher;
  export function createDecipheriv(
    algorithm: string,
    key: Buffer,
    iv: Buffer,
    options?: { authTagLength?: number }
  ): Decipher;
  export function createHash(algorithm: string): Hash;
  export function createPublicKey(options: { format: "jwk"; key: Record<string, unknown> }): KeyLike;
  export function verify(
    algorithm: string,
    data: Buffer,
    key: { key: KeyLike; dsaEncoding: "ieee-p1363" },
    signature: Buffer
  ): boolean;
}

declare module "express" {
  export type NextFunction = (error?: unknown) => void;

  export interface Request {
    method: string;
    path: string;
    body: any;
    params: Record<string, string | string[] | undefined>;
    query: unknown;
    rawBody?: Buffer;
    userId?: string;
    isAdmin?: boolean;
    requestId?: string;
    header(name: string): string | undefined;
  }

  export interface Response {
    statusCode: number;
    status(code: number): Response;
    json(body: unknown): Response;
    on(event: "finish", listener: () => void): Response;
    setHeader(name: string, value: string): Response;
  }

  export type RequestHandler = (
    req: Request,
    res: Response,
    next: NextFunction
  ) => unknown;

  export type ErrorRequestHandler = (
    error: unknown,
    req: Request,
    res: Response,
    next: NextFunction
  ) => unknown;

  type Handler = RequestHandler | ErrorRequestHandler | Router;

  export interface Router {
    get(path: string, ...handlers: Handler[]): Router;
    post(path: string, ...handlers: Handler[]): Router;
    patch(path: string, ...handlers: Handler[]): Router;
    delete(path: string, ...handlers: Handler[]): Router;
    use(path: string, ...handlers: Handler[]): Router;
  }

  export interface Server {
    close(listener?: () => void): void;
  }

  export interface Express extends Router {
    disable(setting: string): Express;
    listen(port: number, listener?: () => void): Server;
  }

  export function Router(): Router;

  type JsonOptions = {
    verify?: (req: Request, res: Response, buffer: Buffer) => void;
  };

  type ExpressFactory = {
    (): Express;
    json(options?: JsonOptions): RequestHandler;
  };

  const express: ExpressFactory;
  export default express;
}
