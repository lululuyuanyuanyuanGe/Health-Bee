// chat.ts
// Chat routes: POST /api/chat and POST /api/chat/stream

import { Router, Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { generateChat, generateChatStream } from '../services/gemini';
import { ChatRequest, ChatResponse } from '../types';
import { createError } from '../middleware/errorHandler';

const router = Router();

/**
 * Validate incoming chat request body.
 */
function validateChatRequest(body: unknown): ChatRequest {
  if (!body || typeof body !== 'object') {
    throw createError('Request body must be a JSON object', 400);
  }

  const req = body as Record<string, unknown>;

  if (!Array.isArray(req.messages) || req.messages.length === 0) {
    throw createError('messages must be a non-empty array', 400);
  }

  for (const msg of req.messages) {
    if (
      typeof msg !== 'object' ||
      msg === null ||
      !['user', 'assistant'].includes((msg as Record<string, unknown>).role as string) ||
      typeof (msg as Record<string, unknown>).content !== 'string'
    ) {
      throw createError(
        'Each message must have role ("user"|"assistant") and content (string)',
        400,
      );
    }
  }

  if (req.systemPrompt !== undefined && typeof req.systemPrompt !== 'string') {
    throw createError('systemPrompt must be a string if provided', 400);
  }

  return {
    messages: req.messages as ChatRequest['messages'],
    systemPrompt: req.systemPrompt as string | undefined,
  };
}

/**
 * POST /api/chat
 * Returns a complete AI response in one JSON payload.
 */
router.post('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { messages, systemPrompt } = validateChatRequest(req.body);

    const content = await generateChat(messages, systemPrompt);
    const sessionId = uuidv4();

    const response: ChatResponse = { content, sessionId };
    res.json(response);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/chat/stream
 * Streams AI response chunks as Server-Sent Events.
 *
 * SSE format:
 *   data: {"delta": "text chunk"}\n\n
 *   ...
 *   data: [DONE]\n\n
 */
router.post('/stream', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { messages, systemPrompt } = validateChatRequest(req.body);

    // Set SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    const streamResult = await generateChatStream(messages, systemPrompt);

    for await (const chunk of streamResult.stream) {
      const delta = chunk.text();
      if (delta) {
        res.write(`data: ${JSON.stringify({ delta })}\n\n`);
      }
    }

    res.write('data: [DONE]\n\n');
    res.end();
  } catch (err) {
    // If headers already sent, we can only end the stream with an error event
    if (res.headersSent) {
      res.write(`data: ${JSON.stringify({ error: (err as Error).message })}\n\n`);
      res.end();
    } else {
      next(err);
    }
  }
});

export default router;
