// types.ts
// Shared TypeScript types for Health-Bee backend

export type MessageRole = 'user' | 'assistant';

export interface ChatMessage {
  role: MessageRole;
  content: string;
}

export interface ChatRequest {
  messages: ChatMessage[];
  systemPrompt?: string;
}

export interface ChatResponse {
  content: string;
  sessionId: string;
}

export interface StreamChunk {
  delta: string;
}

export interface HealthResponse {
  status: 'ok';
}

export interface ErrorResponse {
  error: string;
  details?: string;
}
