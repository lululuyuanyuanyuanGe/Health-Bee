// gemini.ts
// Gemini API service wrapper

import {
  GoogleGenerativeAI,
  Content,
  GenerateContentStreamResult,
} from '@google/generative-ai';
import { ChatMessage } from '../types';

const MODEL_NAME = 'gemini-1.5-flash';

function getClient(): GoogleGenerativeAI {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY environment variable is not set');
  }
  return new GoogleGenerativeAI(apiKey);
}

/**
 * Map our message roles to Gemini roles.
 * Gemini uses "user" and "model" (not "assistant").
 */
function mapMessages(messages: ChatMessage[]): Content[] {
  return messages.map((msg) => ({
    role: msg.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: msg.content }],
  }));
}

/**
 * Generate a complete (non-streaming) chat response.
 */
export async function generateChat(
  messages: ChatMessage[],
  systemPrompt?: string,
): Promise<string> {
  const client = getClient();

  const model = client.getGenerativeModel({
    model: MODEL_NAME,
    ...(systemPrompt
      ? { systemInstruction: { role: 'system', parts: [{ text: systemPrompt }] } }
      : {}),
  });

  // Gemini chat requires at least one message and the last must be from "user"
  const history = mapMessages(messages.slice(0, -1));
  const lastMessage = messages[messages.length - 1];

  if (!lastMessage) {
    throw new Error('No messages provided');
  }

  const chat = model.startChat({ history });
  const result = await chat.sendMessage(lastMessage.content);
  const response = result.response;
  return response.text();
}

/**
 * Generate a streaming chat response.
 * Returns an async iterable of text chunks.
 */
export async function generateChatStream(
  messages: ChatMessage[],
  systemPrompt?: string,
): Promise<GenerateContentStreamResult> {
  const client = getClient();

  const model = client.getGenerativeModel({
    model: MODEL_NAME,
    ...(systemPrompt
      ? { systemInstruction: { role: 'system', parts: [{ text: systemPrompt }] } }
      : {}),
  });

  const history = mapMessages(messages.slice(0, -1));
  const lastMessage = messages[messages.length - 1];

  if (!lastMessage) {
    throw new Error('No messages provided');
  }

  const chat = model.startChat({ history });
  return chat.sendMessageStream(lastMessage.content);
}
