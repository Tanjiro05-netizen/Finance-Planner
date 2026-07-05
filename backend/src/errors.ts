export class ApiError extends Error {
  readonly statusCode: number;
  readonly code: string;

  constructor(statusCode: number, code: string, message: string) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }
}

export function badRequest(code: string, message: string): ApiError {
  return new ApiError(400, code, message);
}

export function unauthorized(message = "Authentication is required."): ApiError {
  return new ApiError(401, "unauthorized", message);
}

export function forbidden(message = "You do not have access to this resource."): ApiError {
  return new ApiError(403, "forbidden", message);
}

export function notFound(message = "The requested resource was not found."): ApiError {
  return new ApiError(404, "not_found", message);
}

export function conflict(message: string): ApiError {
  return new ApiError(409, "conflict", message);
}

export function internal(message = "Something went wrong."): ApiError {
  return new ApiError(500, "internal_error", message);
}

export function isApiError(error: unknown): error is ApiError {
  return error instanceof ApiError;
}
