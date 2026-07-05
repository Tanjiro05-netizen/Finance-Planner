export type NextFunction = (error?: unknown) => void;

export type Request = {
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
};

export type Response = {
  statusCode: number;
  status(code: number): Response;
  json(body: unknown): Response;
  on(event: "finish", listener: () => void): Response;
  setHeader(name: string, value: string): Response;
};

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

export type Router = {
  get(path: string, ...handlers: RequestHandler[]): Router;
  post(path: string, ...handlers: RequestHandler[]): Router;
  patch(path: string, ...handlers: RequestHandler[]): Router;
  delete(path: string, ...handlers: RequestHandler[]): Router;
  use(...handlers: RequestHandler[]): Router;
  use(handler: ErrorRequestHandler): Router;
  use(path: string, ...handlers: Handler[]): Router;
};

export type Server = {
  close(listener?: () => void): void;
};

export type Express = Router & {
  disable(setting: string): Express;
  listen(port: number, listener?: () => void): Server;
};

type JsonOptions = {
  verify?: (req: Request, res: Response, buffer: Buffer) => void;
};

type ExpressRuntime = {
  (): Express;
  Router(): Router;
  json(options?: JsonOptions): RequestHandler;
};

export function createExpressApp(): Express {
  return loadExpress("express")();
}

export function createRouter(): Router {
  return loadExpress("express").Router();
}

export function json(options?: JsonOptions): RequestHandler {
  return loadExpress("express").json(options);
}

function loadExpress(moduleName: string): ExpressRuntime {
  const runtimeRequire = eval("require") as (name: string) => unknown;
  return runtimeRequire(moduleName) as ExpressRuntime;
}
