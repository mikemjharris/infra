// GET  /api/scores                    -> top scores, [[score, name], ...]
// POST /api/scores {"score","name"}   -> saves it, then the top scores
//
// Runs behind snowman's CloudFront, which adds x-origin-verify; anything else
// is refused.

import { timingSafeEqual, randomUUID } from 'node:crypto';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';

const TABLE = process.env.TABLE;
const SECRET = Buffer.from(process.env.ORIGIN_VERIFY_SECRET || '');
const BOARD = 'all';
const TOP = 5;
// A 30-second game has never come near this; anything above is made up.
const MAX_SCORE = 1_000_000;
const MAX_NAME = 20;

const db = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const reply = (statusCode, body) => ({
  statusCode,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  body: JSON.stringify(body),
});

const fromCloudFront = (headers = {}) => {
  const given = Buffer.from(headers['x-origin-verify'] || '');
  return SECRET.length > 0 && given.length === SECRET.length && timingSafeEqual(given, SECRET);
};

const topScores = async () => {
  const { Items = [] } = await db.send(new QueryCommand({
    TableName: TABLE,
    KeyConditionExpression: 'board = :board',
    ExpressionAttributeValues: { ':board': BOARD },
    ScanIndexForward: false,
    Limit: TOP,
  }));
  return Items.map((item) => [item.score, item.name]);
};

const cleanName = (name) => String(name ?? '')
  .replace(/[\p{C}<>]/gu, '')
  .trim()
  .slice(0, MAX_NAME) || 'Anon';

export const handler = async (event) => {
  if (!fromCloudFront(event.headers)) return reply(403, { error: 'forbidden' });

  const method = event.requestContext?.http?.method;
  const path = event.rawPath;
  if (path !== '/api/scores') return reply(404, { error: 'not found' });

  if (method === 'GET') return reply(200, await topScores());

  if (method === 'POST') {
    let input;
    try {
      const raw = event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString() : event.body;
      input = JSON.parse(raw || '{}');
    } catch {
      return reply(400, { error: 'invalid JSON' });
    }
    const score = input.score;
    if (!Number.isInteger(score) || score < 0 || score > MAX_SCORE) {
      return reply(400, { error: 'invalid score' });
    }
    await db.send(new PutCommand({
      TableName: TABLE,
      Item: {
        board: BOARD,
        rank: `${String(score).padStart(7, '0')}#${randomUUID()}`,
        score,
        name: cleanName(input.name),
        at: new Date().toISOString(),
      },
    }));
    return reply(200, await topScores());
  }

  return reply(405, { error: 'method not allowed' });
};
