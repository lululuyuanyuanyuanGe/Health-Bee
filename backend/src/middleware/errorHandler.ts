// errorHandler.ts
// Global Express error handler

import { Request, Response, NextFunction } from 'express';
import { ErrorResponse } from '../types';

export interface AppError extends Error {
  statusCode?: number;
  details?: string;
}

export function errorHandler(
  err: AppError,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  const statusCode = err.statusCode ?? 500;
  const body: ErrorResponse = {
    error: err.message || 'Internal Server Error',
    ...(err.details ? { details: err.details } : {}),
  };

  console.error(`[Error ${statusCode}]`, err.message, err.stack);
  res.status(statusCode).json(body);
}

export function createError(message: string, statusCode = 500, details?: string): AppError {
  const err: AppError = new Error(message);
  err.statusCode = statusCode;
  if (details) err.details = details;
  return err;
}
