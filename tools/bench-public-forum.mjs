#!/usr/bin/env node
import { cp, mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';
import { createPublicForumServer } from './public-forum.mjs';

const moduleDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(moduleDir, '..');
const postCount = 200;
const postBody = 'x'.repeat(256);
const maxP95Ms = Number(process.env.PUBLIC_FORUM_BENCH_MAX_P95_MS ?? '500');

if (!Number.isFinite(maxP95Ms) || maxP95Ms <= 0) {
  throw new Error('PUBLIC_FORUM_BENCH_MAX_P95_MS musi być dodatnią liczbą.');
}

function percentile(samples, value) {
  const sorted = [...samples].sort((a, b) => a - b);
  return sorted[Math.ceil(sorted.length * value) - 1];
}

async function request(base, pathname, options = {}) {
  const started = performance.now();
  const response = await fetch(`${base}${pathname}`, { redirect: 'manual', ...options });
  await response.arrayBuffer();
  if (response.status < 200 || response.status >= 300) {
    throw new Error(`${options.method || 'GET'} ${pathname}: HTTP ${response.status}`);
  }
  return performance.now() - started;
}

async function measure(name, { count, concurrency, operation }) {
  for (let index = 0; index < concurrency; index += 1) await operation(-index - 1);

  const samples = [];
  const started = performance.now();
  let next = 0;
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (next < count) {
      const index = next;
      next += 1;
      samples.push(await operation(index));
    }
  }));
  const elapsed = performance.now() - started;
  const result = {
    name,
    count,
    concurrency,
    throughput: count / (elapsed / 1000),
    p50: percentile(samples, 0.5),
    p95: percentile(samples, 0.95),
  };
  if (result.p95 > maxP95Ms) {
    throw new Error(`${name}: p95 ${result.p95.toFixed(2)} ms przekracza limit ${maxP95Ms} ms`);
  }
  return result;
}

function print(result) {
  console.log([
    'PUBLIC-FORUM-BENCH',
    `route=${result.name}`,
    `ops=${result.count}`,
    `concurrency=${result.concurrency}`,
    `ops_s=${result.throughput.toFixed(2)}`,
    `p50_ms=${result.p50.toFixed(2)}`,
    `p95_ms=${result.p95.toFixed(2)}`,
  ].join(' '));
}

const fixture = await mkdtemp(path.join(tmpdir(), 'szem-public-forum-bench-'));
let server;
try {
  await cp(path.join(root, 'examples'), path.join(fixture, 'examples'), { recursive: true });
  const postsDir = path.join(fixture, 'posts');
  await mkdir(postsDir);
  for (let index = 0; index < postCount; index += 1) {
    const sequence = String(index).padStart(4, '0');
    await writeFile(
      path.join(postsDir, `2026-01-01T00-00-${sequence}Z__Bench__seed.md`),
      `---\nauthor: Bench\nts: 2026-01-01T00:00:00Z\n---\n${postBody}\n`,
    );
  }

  server = await createPublicForumServer({ root: fixture });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;
  const seedPost = '2026-01-01T00-00-0000Z__Bench__seed.md';
  const form = (values) => ({
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(values),
  });

  const results = [
    await measure('GET /', { count: 50, concurrency: 8, operation: () => request(base, '/') }),
    await measure('GET /agent/Hart01', { count: 30, concurrency: 4, operation: () => request(base, '/agent/Hart01') }),
    await measure('GET /node/ATLAS-C1', { count: 30, concurrency: 4, operation: () => request(base, '/node/ATLAS-C1') }),
    await measure('POST /post', {
      count: 20,
      concurrency: 4,
      operation: (index) => request(base, '/post', form({ author: 'Bench', body: `post-${index}-${postBody}` })),
    }),
    await measure('POST /react', {
      count: 20,
      concurrency: 4,
      operation: () => request(base, '/react', form({ post: seedPost, reactor: 'Bench', emoji: '✅' })),
    }),
  ];
  results.forEach(print);
  console.log(`PUBLIC-FORUM-BENCH-OK fixture_posts=${postCount} max_p95_ms=${maxP95Ms}`);
} finally {
  await new Promise((resolve) => server?.close(resolve) ?? resolve());
  await rm(fixture, { recursive: true, force: true });
}
