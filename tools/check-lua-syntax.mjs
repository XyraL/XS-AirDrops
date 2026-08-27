// Parses every Lua file properly.
//
// There is no Lua interpreter on this dev machine, which is why
// check-lua-blocks.mjs exists — but that only balances block keywords. It
// cannot see a missing comma, a stray bracket, or anything else that makes a
// file fail to load. And a config.lua that fails to load is not a small
// problem: every file after it sees `Config` as nil and the whole resource
// falls over with errors that point anywhere except the actual cause.
//
// luaparse is a pure-JS Lua parser, so this is a real syntax check.
//
//   npm install --no-save luaparse
//   node tools/check-lua-syntax.mjs
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import luaparse from 'luaparse';

// Defaults to this resource; pass a path to check another one.
const base = process.argv[2] || '.';
const files = [];

(function walk(dir) {
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }

  for (const entry of entries) {
    const p = join(dir, entry.name);
    // Nothing here needs to parse vendored or generated Lua.
    if (entry.isDirectory()) {
      if (['node_modules', '.git', 'stream'].includes(entry.name)) continue;
      walk(p);
    } else if (entry.name.endsWith('.lua')) {
      files.push(p);
    }
  }
})(base);

let bad = 0;

for (const file of files.sort()) {
  const src = readFileSync(file, 'utf8');

  // FiveM extends Lua with a backtick hash literal: `prop_name` compiles to
  // its joaat hash. luaparse only knows standard Lua and reports every one of
  // them as a syntax error, which would flag perfectly good files across the
  // whole line. Swap them for a number, exactly as the game does.
  //
  // Done on a copy for parsing only — nothing is written back.
  const parseable = src.replace(/`[^`\n]*`/g, '0');

  try {
    // luaVersion 5.3 is the closest luaparse offers to FiveM's 5.4, and the
    // differences are features this codebase does not use.
    luaparse.parse(parseable, { luaVersion: '5.3', comments: false });
  } catch (err) {
    bad++;
    console.log(`  ${file}`);
    console.log(`      line ${err.line || '?'}: ${err.message.replace(/^\[.*?\]\s*/, '')}`);

    const lines = src.split('\n');
    const n = (err.line || 1) - 1;
    for (let i = Math.max(0, n - 2); i <= Math.min(lines.length - 1, n + 1); i++) {
      console.log(`      ${String(i + 1).padStart(4)} ${i === n ? '>' : ' '} ${lines[i]}`);
    }
    console.log('');
  }
}

if (bad) {
  console.log(`  ${bad} file(s) will not load.`);
  process.exit(1);
}
console.log(`  ${files.length} Lua files parse cleanly.`);
