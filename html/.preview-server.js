// Dev-only preview of the builder in a normal browser: node html/.preview-server.js
// then open http://localhost:5174/?page=zones (or ?edit=zone:1&tab=points).
// Not in fxmanifest, so FiveM never serves it. /__settings.json is read from
// shared/settings.lua so the mock always shows the real settings list.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };

function tokens(src) {
  const out = [];
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (/\s|,/.test(c)) { i++; continue; }
    if (c === "'" || c === '"') {
      let j = i + 1;
      let s = '';
      while (j < src.length && src[j] !== c) {
        if (src[j] === '\\') { s += src[j + 1]; j += 2; continue; }
        s += src[j];
        j++;
      }
      out.push({ t: 'str', v: s });
      i = j + 1;
      continue;
    }
    if (c === '{' || c === '}' || c === '=') { out.push({ t: c }); i++; continue; }
    const m = /^-?[\d.]+/.exec(src.slice(i));
    if (m) { out.push({ t: 'num', v: Number(m[0]) }); i += m[0].length; continue; }
    const w = /^[A-Za-z_]\w*/.exec(src.slice(i));
    if (w) { out.push({ t: 'id', v: w[0] }); i += w[0].length; continue; }
    i++;
  }
  return out;
}

function parseTable(tk, pos, consts) {
  const arr = [];
  const obj = {};
  let isObj = false;
  pos++;
  while (pos < tk.length && tk[pos].t !== '}') {
    if (tk[pos].t === 'id' && tk[pos + 1] && tk[pos + 1].t === '=') {
      const key = tk[pos].v;
      const [v, next] = parseValue(tk, pos + 2, consts);
      obj[key] = v;
      isObj = true;
      pos = next;
    } else {
      const [v, next] = parseValue(tk, pos, consts);
      arr.push(v);
      pos = next;
    }
  }
  if (isObj) { arr.forEach((v, i) => { obj[i] = v; }); return [obj, pos + 1]; }
  return [arr, pos + 1];
}

function parseValue(tk, pos, consts) {
  const t = tk[pos];
  if (t.t === '{') return parseTable(tk, pos, consts);
  if (t.t === 'str' || t.t === 'num') return [t.v, pos + 1];
  if (t.t === 'id') {
    if (t.v === 'true') return [true, pos + 1];
    if (t.v === 'false') return [false, pos + 1];
    if (t.v === 'nil') return [null, pos + 1];
    return [consts[t.v], pos + 1];
  }
  return [null, pos + 1];
}

function parseSettings(lua) {
  const consts = {};
  for (const m of lua.matchAll(/^local (\w+) = (\{[^\n]*\})/gm)) consts[m[1]] = parseValue(tokens(m[2]), 0, consts)[0];
  const start = lua.indexOf('Settings.Sections = {');
  let depth = 0;
  let end = start;
  for (let i = lua.indexOf('{', start); i < lua.length; i++) {
    if (lua[i] === '{') depth++;
    if (lua[i] === '}') { depth--; if (depth === 0) { end = i + 1; break; } }
  }
  const raw = parseValue(tokens(lua.slice(lua.indexOf('{', start), end)), 0, consts)[0];
  const values = {};
  const defaults = {};
  const sections = raw.map((s) => ({
    id: s.id, icon: s.icon, label: s.label, help: s.help,
    fields: (s.fields || []).map((f) => {
      const def = { key: f[0], type: f[1], section: s.id };
      Object.keys(f).forEach((k) => { if (!/^\d+$/.test(k) && k !== 'default') def[k] = f[k]; });
      values[def.key] = f.default;
      defaults[def.key] = f.default;
      return def;
    }),
  }));
  return { sections, values, defaults };
}

if (require.main === module) {
  http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/__settings.json') {
      const lua = fs.readFileSync(path.join(ROOT, '..', 'shared', 'settings.lua'), 'utf8');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(parseSettings(lua)));
      return;
    }
    const file = path.join(ROOT, url === '/' ? '/index.html' : url);
    if (!file.startsWith(ROOT)) { res.writeHead(403).end(); return; }
    fs.readFile(file, (err, buf) => {
      if (err) { res.writeHead(404).end('not found'); return; }
      res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
      res.end(buf);
    });
  }).listen(5174, () => console.log('preview on http://localhost:5174'));
}

module.exports = { parseSettings };
