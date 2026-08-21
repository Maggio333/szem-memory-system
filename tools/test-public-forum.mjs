#!/usr/bin/env node
import assert from 'node:assert/strict';
import { mkdtemp, cp, readFile, readdir, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPublicForumServer } from './public-forum.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixture = await mkdtemp(path.join(tmpdir(), 'szem-public-forum-'));
let server;

async function request(base, pathname, options = {}) {
  return fetch(`${base}${pathname}`, { redirect: 'manual', ...options });
}

async function form(base, pathname, values) {
  return request(base, pathname, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(values),
  });
}

let escaped;
try {
  await cp(path.join(root, 'examples'), path.join(fixture, 'examples'), { recursive: true });
  escaped = await mkdtemp(path.join(tmpdir(), 'szem-public-forum-outside-'));
  await writeFile(path.join(escaped, 'profil.yml'), 'imie: Escape\n');
  let symlinkCheck = true;
  try {
    await symlink(escaped, path.join(fixture, 'examples', 'atlas-zgloszen', 'agenci', 'Escape'));
  } catch (error) {
    if (error?.code !== 'EPERM') throw error;
    symlinkCheck = false;
    console.log('PUBLIC-FORUM-SYMLINK-CHECK-SKIPPED (EPERM)');
  }
  await writeFile(
    path.join(fixture, 'examples', 'atlas-zgloszen', 'agenci', 'Monter01', 'tozsamosc', 'o-mnie.md'),
    '<script>outside()</script>\n',
  );

  server = await createPublicForumServer({ root: fixture });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;

  let response = await request(base, '/');
  assert.equal(response.status, 200);
  assert.match(await response.text(), /Monter01/);
  if (symlinkCheck) {
    assert.doesNotMatch(await request(base, '/').then((r) => r.text()), /Escape/);
    console.log('PUBLIC-FORUM-SYMLINK-CHECK-ENFORCED');
  }

  response = await request(base, '/agent/Monter01');
  assert.equal(response.status, 200);
  assert.match(await response.text(), /&lt;script&gt;outside\(\)&lt;\/script&gt;/);
  assert.equal((await request(base, '/agent/%2e%2e%2f.git')).status, 404);
  assert.equal((await request(base, '/.git/config')).status, 404);
  assert.equal((await request(base, '/node/ATLAS-C1')).status, 200);
  assert.equal((await request(base, '/node/not-a-node')).status, 404);

  response = await form(base, '/post', { author: 'PublicUser', body: 'Neutralny post testowy.' });
  assert.equal(response.status, 201);
  assert.match(await response.text(), /sprawdź diff/i);
  const posts = await readdir(path.join(fixture, 'posts'));
  assert.equal(posts.length, 1);
  const post = posts[0];
  assert.match(await readFile(path.join(fixture, 'posts', post), 'utf8'), /author: PublicUser/);

  assert.equal((await form(base, '/post', { author: '../bad', body: 'x' })).status, 400);
  assert.equal((await form(base, '/post', { author: 'PublicUser', body: 'x'.repeat(65537) })).status, 400);
  assert.equal((await form(base, '/post', { author: 'PublicUser', body: 'x', reply_to: '../../fake.md' })).status, 400);
  assert.equal((await form(base, '/post', { author: 'PublicUser', body: 'Odpowiedź.', reply_to: post })).status, 201);

  response = await form(base, '/react', { post, reactor: 'Reviewer_1', emoji: '✅' });
  assert.equal(response.status, 201);
  assert.equal((await readdir(path.join(fixture, 'reactions'))).length, 1);
  assert.equal((await form(base, '/react', { post, reactor: 'Reviewer_1', emoji: '💣' })).status, 400);
  assert.equal((await form(base, '/react', { post: '../bad.md', reactor: 'Reviewer_1', emoji: '✅' })).status, 400);

  console.log('PUBLIC-FORUM-TEST-OK');
} finally {
  await new Promise((resolve) => server?.close(resolve) ?? resolve());
  await rm(fixture, { recursive: true, force: true });
  if (escaped) await rm(escaped, { recursive: true, force: true });
}
