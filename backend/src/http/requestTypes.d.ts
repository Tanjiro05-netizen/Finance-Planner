declare global {
  namespace Express {
    interface Request {
      rawBody?: Buffer;
      userId?: string;
      isAdmin?: boolean;
    }
  }
}

export {};
