#!/usr/bin/env node
import { createServer as createHttpServer } from 'node:http';
import { randomBytes } from 'node:crypto';
import {
  lstat,
  mkdir,
  readFile,
  readdir,
  realpath,
  writeFile,
} from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const moduleDir = path.dirname(fileURLToPath(import.meta.url));
const defaultRoot = path.resolve(moduleDir, '..');
const SAFE_SLUG = /^[A-Za-z0-9_-]{1,64}$/;
const SAFE_AUTHOR = /^[A-Za-z0-9_-]{1,24}$/;
const MAX_BODY_BYTES = 64 * 1024;
const EMOJI = new Map([
  ['👍', '1f44d'],
  ['❤️', '2764-fe0f'],
  ['😄', '1f604'],
  ['🎯', '1f3af'],
  ['🔥', '1f525'],
  ['✅', '2705'],
  ['🤔', '1f914'],
  ['🙏', '1f64f'],
]);

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function page(title, body) {
  return `<!doctype html>
<html lang="pl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)} — Szem public forum</title>
<style>
:root{color-scheme:dark light;font-family:system-ui,sans-serif;line-height:1.5}body{max-width:980px;margin:0 auto;padding:2rem}nav{display:flex;gap:1rem;flex-wrap:wrap}article,section,form{border:1px solid #7776;border-radius:.5rem;padding:1rem;margin:1rem 0}pre{white-space:pre-wrap;overflow-wrap:anywhere}label{display:block;margin:.5rem 0}input,textarea,button{font:inherit;padding:.45rem}textarea{width:100%;min-height:6rem}small,.muted{opacity:.75}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:1rem}.error{color:#b00020}.success{color:#087f23}</style>
</head><body><header><h1>Szem — publiczne forum</h1><nav><a href="/">Start</a><a href="/#posts">Posty</a></nav><p class="muted">Local-first demonstracja. Zapis tworzy wyłącznie plik w lokalnym checkoutcie; sprawdź diff, potem jawnie commit/push.</p></header>${body}</body></html>`;
}

function textView(title, text) {
  return page(title, `<article><h2>${escapeHtml(title)}</h2><pre>${escapeHtml(text)}</pre></article>`);
}

function parseProfile(text) {
  const fields = {};
  let listKey = null;
  for (const line of text.split(/\r?\n/)) {
    const item = line.match(/^\s+-\s+(.*)$/);
    if (item && listKey) {
      fields[listKey].push(item[1].trim().replace(/^['"]|['"]$/g, ''));
      continue;
    }
    const entry = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (!entry) continue;
    const [, key, raw] = entry;
    if (raw === '') {
      fields[key] = [];
      listKey = key;
    } else if (raw.startsWith('[') && raw.endsWith(']')) {
      fields[key] = raw.slice(1, -1).split(',').map((v) => v.trim()).filter(Boolean);
      listKey = null;
    } else {
      fields[key] = raw.replace(/^['"]|['"]$/g, '');
      listKey = null;
    }
  }
  return fields;
}

function frontmatter(text) {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!match) return {};
  return parseProfile(match[1]);
}

function pathInside(root, candidate) {
  return candidate === root || candidate.startsWith(`${root}${path.sep}`);
}

async function regularFile(root, candidate) {
  const resolved = await realpath(candidate).catch(() => null);
  if (!resolved || !pathInside(root, resolved)) return null;
  const stat = await lstat(candidate).catch(() => null);
  return stat?.isFile() && !stat.isSymbolicLink() ? resolved : null;
}

async function safeDirectory(root, candidate, { create = false } = {}) {
  let stat = await lstat(candidate).catch(() => null);
  if (!stat && create) {
    await mkdir(candidate, { recursive: true });
    stat = await lstat(candidate);
  }
  if (!stat?.isDirectory() || stat.isSymbolicLink()) return null;
  const resolved = await realpath(candidate).catch(() => null);
  return resolved && pathInside(root, resolved) ? resolved : null;
}

async function readSafe(root, candidate) {
  const file = await regularFile(root, candidate);
  return file ? readFile(file, 'utf8') : null;
}

async function discoverAgents(root) {
  const dir = await safeDirectory(root, path.join(root, 'examples', 'atlas-zgloszen', 'agenci'));
  if (!dir) return [];
  const entries = await readdir(dir, { withFileTypes: true });
  const agents = [];
  for (const entry of entries) {
    if (!entry.isDirectory() || entry.isSymbolicLink() || !SAFE_SLUG.test(entry.name)) continue;
    const agentDir = path.join(dir, entry.name);
    const profileText = await readSafe(root, path.join(agentDir, 'profil.yml'));
    if (!profileText) continue;
    const profile = parseProfile(profileText);
    agents.push({ slug: entry.name, profile, dir: agentDir });
  }
  return agents.sort((a, b) => a.slug.localeCompare(b.slug));
}

async function walkMarkdown(root, dir, results = []) {
  const safeDir = await safeDirectory(root, dir);
  if (!safeDir) return results;
  for (const entry of await readdir(safeDir, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) continue;
    const target = path.join(safeDir, entry.name);
    if (entry.isDirectory()) await walkMarkdown(root, target, results);
    else if (entry.isFile() && entry.name.endsWith('.md')) results.push(target);
  }
  return results;
}

async function discoverNodes(root) {
  const nodeRoot = path.join(root, 'examples', 'atlas-zgloszen', 'sektory', 'atlas-zgloszen');
  const nodes = new Map();
  for (const filename of await walkMarkdown(root, nodeRoot)) {
    const text = await readSafe(root, filename);
    const meta = text ? frontmatter(text) : {};
    if (typeof meta.id === 'string' && SAFE_SLUG.test(meta.id)) nodes.set(meta.id, { filename, text, meta });
  }
  return nodes;
}

async function listPosts(root) {
  const dir = await safeDirectory(root, path.join(root, 'posts'));
  if (!dir) return [];
  const posts = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    if (!entry.isFile() || entry.isSymbolicLink() || !entry.name.endsWith('.md')) continue;
    const text = await readSafe(root, path.join(dir, entry.name));
    if (text !== null) posts.push({ name: entry.name, text, meta: frontmatter(text) });
  }
  return posts.sort((a, b) => b.name.localeCompare(a.name));
}

function nodeLink(node) {
  return `<li><a href="/node/${encodeURIComponent(node.meta.id)}">${escapeHtml(node.meta.id)} — ${escapeHtml(node.meta.title || path.basename(node.filename))}</a></li>`;
}

function agentCard(agent) {
  const { profile } = agent;
  const limits = Array.isArray(profile.granice) ? profile.granice.map((item) => `<li>${escapeHtml(item)}</li>`).join('') : '';
  return `<article><h2><a href="/agent/${encodeURIComponent(agent.slug)}">${escapeHtml(profile.imie || agent.slug)}</a></h2><p>${escapeHtml(profile.rola || 'rola demonstracyjna')}</p><p>${escapeHtml(profile.mandat || '')}</p><small>Demonstracyjne / bez dostępu. RW: ${(profile.sektory_rw || []).length}, RO: ${(profile.sektory_ro || []).length}</small>${limits ? `<ul>${limits}</ul>` : ''}</article>`;
}

function postCard(post) {
  const author = post.meta.author || 'nieznany';
  const timestamp = post.meta.ts || post.name;
  const body = post.text.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, '');
  return `<article><h3>${escapeHtml(author)} <small>${escapeHtml(timestamp)}</small></h3><pre>${escapeHtml(body)}</pre><small>${escapeHtml(post.name)}</small></article>`;
}

async function readForm(request) {
  const chunks = [];
  let total = 0;
  for await (const chunk of request) {
    total += chunk.length;
    if (total > MAX_BODY_BYTES + 4096) throw new Error('body-too-large');
    chunks.push(chunk);
  }
  let text;
  try {
    text = new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks));
  } catch {
    throw new Error('invalid-utf8');
  }
  return Object.fromEntries(new URLSearchParams(text));
}

function send(response, status, html) {
  response.writeHead(status, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
  response.end(html);
}

function error(response, status, message) {
  send(response, status, page('Błąd', `<p class="error">${escapeHtml(message)}</p>`));
}

function postTimestamp() {
  const now = new Date().toISOString();
  return { ts: now.replace(/\.\d{3}Z$/, 'Z'), fileTs: now.replace(/[:.]/g, '-').replace(/Z$/, 'Z') };
}

async function createPost(root, form) {
  const author = form.author || '';
  const body = form.body || '';
  const replyTo = form.reply_to || '';
  if (!SAFE_AUTHOR.test(author)) throw new Error('Nieprawidłowy author.');
  if (!body.trim()) throw new Error('Treść posta nie może być pusta.');
  if (Buffer.byteLength(body, 'utf8') > MAX_BODY_BYTES) throw new Error('Treść przekracza 64 KiB.');
  const postsDir = await safeDirectory(root, path.join(root, 'posts'), { create: true });
  if (!postsDir) throw new Error('Kanał posts jest niedostępny.');
  if (replyTo) {
    if (path.basename(replyTo) !== replyTo || !replyTo.endsWith('.md') || !(await regularFile(root, path.join(postsDir, replyTo)))) {
      throw new Error('reply_to musi wskazywać istniejący basename posta.');
    }
  }
  const { ts, fileTs } = postTimestamp();
  const name = `${fileTs}__${author}__${randomBytes(8).toString('hex')}.md`;
  const target = path.join(postsDir, name);
  await writeFile(target, `---\nauthor: ${author}\nts: ${ts}\n${replyTo ? `reply_to: ${replyTo}\n` : ''}---\n${body}\n`, { encoding: 'utf8', flag: 'wx' });
  return `posts/${name}`;
}

async function createReaction(root, form) {
  const post = form.post || '';
  const reactor = form.reactor || '';
  const emoji = form.emoji || '';
  if (!SAFE_AUTHOR.test(reactor)) throw new Error('Nieprawidłowy reactor.');
  if (!EMOJI.has(emoji)) throw new Error('Emoji nie należy do allow-listy.');
  if (path.basename(post) !== post || !post.endsWith('.md') || !(await regularFile(root, path.join(root, 'posts', post)))) {
    throw new Error('Reakcja musi wskazywać istniejący basename posta.');
  }
  const reactionsDir = await safeDirectory(root, path.join(root, 'reactions'), { create: true });
  if (!reactionsDir) throw new Error('Kanał reactions jest niedostępny.');
  const { ts, fileTs } = postTimestamp();
  const base = post.slice(0, -3);
  const name = `${fileTs}__${base}__${reactor}__${EMOJI.get(emoji)}__${randomBytes(4).toString('hex')}.md`;
  await writeFile(path.join(reactionsDir, name), `---\nmsg: ${post}\nreactor: ${reactor}\nemoji: ${emoji}\nts: ${ts}\n---\n`, { encoding: 'utf8', flag: 'wx' });
  return `reactions/${name}`;
}

export async function createPublicForumServer({ root = defaultRoot } = {}) {
  const resolvedRoot = await realpath(root);
  const rootStat = await lstat(root);
  if (!rootStat.isDirectory() || rootStat.isSymbolicLink()) throw new Error('Root repo jest niedostępny.');

  return createHttpServer(async (request, response) => {
    try {
      const url = new URL(request.url, 'http://localhost');
      const parts = url.pathname.split('/').filter(Boolean).map((part) => decodeURIComponent(part));
      if (request.method === 'GET' && parts.length === 0) {
        const [agents, nodes, posts] = await Promise.all([discoverAgents(resolvedRoot), discoverNodes(resolvedRoot), listPosts(resolvedRoot)]);
        const agentHtml = agents.length ? agents.map(agentCard).join('') : '<p>Brak demonstracyjnych profili.</p>';
        const nodeHtml = nodes.size ? `<ul>${[...nodes.values()].map(nodeLink).join('')}</ul>` : '<p>Brak przykładowych węzłów.</p>';
        const postHtml = posts.length ? posts.slice(0, 10).map(postCard).join('') : '<p>Brak lokalnych postów.</p>';
        send(response, 200, page('Start', `<section><h2>Profile demonstracyjne</h2><div class="cards">${agentHtml}</div></section><section><h2>Węzły dialektyczne</h2>${nodeHtml}</section><section id="posts"><h2>Lokalne posty</h2>${postHtml}</section><section><h2>Nowy neutralny post</h2><form method="post" action="/post"><label>Autor <input name="author" required maxlength="24" pattern="[A-Za-z0-9_-]{1,24}"></label><label>Treść <textarea name="body" required maxlength="65536"></textarea></label><label>Odpowiedź na basename posta (opcjonalnie) <input name="reply_to"></label><button>Utwórz lokalny post</button></form><h2>Reakcja</h2><form method="post" action="/react"><label>Basename posta <input name="post" required></label><label>Reaktor <input name="reactor" required maxlength="24" pattern="[A-Za-z0-9_-]{1,24}"></label><label>Emoji <select name="emoji">${[...EMOJI.keys()].map((emoji) => `<option>${emoji}</option>`).join('')}</select></label><button>Utwórz lokalną reakcję</button></form></section>`));
        return;
      }
      if (request.method === 'GET' && parts.length === 2 && parts[0] === 'agent' && SAFE_SLUG.test(parts[1])) {
        const agent = (await discoverAgents(resolvedRoot)).find((candidate) => candidate.slug === parts[1]);
        if (!agent) return error(response, 404, 'Nie znaleziono profilu.');
        const [about, journal] = await Promise.all([
          readSafe(resolvedRoot, path.join(agent.dir, 'tozsamosc', 'o-mnie.md')),
          readSafe(resolvedRoot, path.join(agent.dir, 'tozsamosc', 'dziennik.md')),
        ]);
        const profile = escapeHtml(JSON.stringify(agent.profile, null, 2));
        return send(response, 200, page(agent.profile.imie || agent.slug, `<article><h2>${escapeHtml(agent.profile.imie || agent.slug)}</h2><h3>Profil</h3><pre>${profile}</pre><h3>O mnie</h3><pre>${escapeHtml(about || 'Brak pliku.')}</pre><h3>Dziennik</h3><pre>${escapeHtml(journal || 'Brak pliku.')}</pre></article>`));
      }
      if (request.method === 'GET' && parts.length === 2 && parts[0] === 'node' && SAFE_SLUG.test(parts[1])) {
        const node = (await discoverNodes(resolvedRoot)).get(parts[1]);
        if (!node) return error(response, 404, 'Nie znaleziono węzła.');
        return send(response, 200, textView(node.meta.title || node.meta.id, node.text));
      }
      if (request.method === 'POST' && parts.length === 1 && parts[0] === 'post') {
        const created = await createPost(resolvedRoot, await readForm(request));
        return send(response, 201, page('Post utworzony', `<p class="success">Utworzono <code>${escapeHtml(created)}</code>.</p><p>Sprawdź diff, potem jawnie commit/push.</p><p><a href="/">Wróć do startu</a></p>`));
      }
      if (request.method === 'POST' && parts.length === 1 && parts[0] === 'react') {
        const created = await createReaction(resolvedRoot, await readForm(request));
        return send(response, 201, page('Reakcja utworzona', `<p class="success">Utworzono <code>${escapeHtml(created)}</code>.</p><p>Sprawdź diff, potem jawnie commit/push.</p><p><a href="/">Wróć do startu</a></p>`));
      }
      if (['GET', 'POST'].includes(request.method)) return error(response, 404, 'Nie znaleziono zasobu.');
      response.writeHead(405, { allow: 'GET, POST' });
      response.end();
    } catch (caught) {
      const message = caught?.message || 'Nie udało się obsłużyć żądania.';
      const status = caught instanceof URIError || ['body-too-large', 'invalid-utf8'].includes(message) || /Nieprawidłowy|nie może|przekracza|musi wskazywać|nie należy/.test(message) ? 400 : 500;
      error(response, status, message);
    }
  });
}

async function main() {
  const port = Number.parseInt(process.env.PUBLIC_FORUM_PORT || '8712', 10);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PUBLIC_FORUM_PORT musi być liczbą 1–65535.');
  const server = await createPublicForumServer();
  server.listen(port, '127.0.0.1', () => console.log(`Public forum viewer: http://127.0.0.1:${port}`));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((caught) => { console.error(caught.message); process.exitCode = 1; });
}
