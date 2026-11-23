// Finds config keys that nothing reads.
//
// A config file is a promise: every key in it claims to change something. One
// that nothing reads is worse than no key at all, because a server owner will
// set it, get no effect, and conclude the script is broken. `isWeapon` sat in
// this config doing nothing after the loot tables moved into the database.
//
//   node tools/check-config-keys.mjs
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const cfg = readFileSync('config.lua', 'utf8');

// Indented `Key =` lines: the nested settings, not the top-level Config.X
// tables (which are always referenced by name anyway).
const defined = new Set();
for (const m of cfg.matchAll(/^\s{4,}([A-Za-z][A-Za-z0-9_]*)\s*=/gm)) defined.add(m[1]);

const code = ['server', 'client', 'bridge', 'shared']
  .flatMap((dir) => readdirSync(dir).map((f) => join(dir, f)))
  .filter((f) => f.endsWith('.lua'))
  .map((f) => readFileSync(f, 'utf8'))
  .join('\n');

// A key counts as read if it appears after a dot or inside a string anywhere in
// the Lua. Deliberately loose: a false "unused" that deletes a live setting is
// much worse than leaving one in the report to check by hand.
const unread = [...defined]
  .filter((key) => {
    const dotted = new RegExp('\\.' + key + '\\b');
    const quoted = new RegExp('[\'"]' + key + '[\'"]');
    return !dotted.test(code) && !quoted.test(code);
  })
  .sort();

console.log(`  keys defined : ${defined.size}`);
console.log(`  never read    : ${unread.length}`);

if (unread.length) {
  console.log('');
  for (const key of unread) console.log(`    ${key}`);
  process.exit(1);
}
