// Finds player-typed values interpolated into innerHTML without escaping.
//
// Counting how many times esc() appears tells you nothing on its own — a file
// with 100 esc() calls and 20 misses is still a file with 20 misses. This looks
// for the specific shape that matters: a field whose value came from a person,
// dropped into a template literal raw.
//
// It reports; it does not rewrite. A miss inside an event attribute needs
// delegation, not escaping, and only a human can tell those apart.
//
//   node tools/check-escaping.mjs [dir]
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

// Fields that hold something a person typed. Ids, timestamps and enum values
// are left out deliberately — wrapping those is noise, not safety.
const FREE_TEXT = [
  'name', 'notes', 'label', 'title', 'location', 'narrative', 'description',
  'reason', 'message', 'comment', 'content', 'summary', 'address', 'plate',
  'firstname', 'lastname', 'username', 'author', 'text', 'body', 'query',
  'officer_name', 'created_by_name', 'admin_name', 'banned_by', 'player_name',
  'item', 'itemName', 'vehicle', 'model', 'job', 'gang',
].join('|');

// Checked by hand and genuinely safe.
//
// It lives here rather than as a comment on the line, because every one of
// these sits inside a template literal — a `//` there would render as text in
// the panel rather than being a comment.
//
// A checker that always reports the same known-safe lines is one people learn
// to ignore, and then it stops catching the real ones too. Each entry says why.
// `file` and `near` narrow an entry to one place: the file name and a piece of
// text that must be on the same line, so the same expression elsewhere is
// still checked.
const ALLOW = [
  { match: "${s.name}", file: 'blips.js', near: 'return `${',
    why: "sprite file names from the built-in list; every caller escapes the whole URL" },
  { match: "${c.label}", file: 'bsettings.js', near: 'return c ?',
    why: "built-in GTA colour names; fmt() output is escaped where it is shown" },
  { match: "${l.data.label}", file: 'builder.js', near: 'is empty',
    why: "issue text, escaped where the issue list renders it" },
  { match: "${z.data.label}", file: 'builder.js', near: 'sub: `Zone #',
    why: "issue sub-line, escaped where the issue list renders it" },
  { match: "${c.data.label}", file: 'builder.js', near: 'sub: `Crate type',
    why: "issue sub-line, escaped where the issue list renders it" },
  { match: "${l.data.label}", file: 'builder.js', near: 'sub: `Loot table',
    why: "issue sub-line, escaped where the issue list renders it" },
  { match: "${d.label}", file: 'builder.js', near: '.toLowerCase().includes(q)',
    why: "search text, never rendered" },
  { match: "${d.notes}", file: 'builder.js', near: '.toLowerCase().includes(q)',
    why: "search text, never rendered" },
  { match: "${i.label}", file: 'builder.js', near: 'const hay = `',
    why: "search text, never rendered" },
  { match: "${def.data.label}", file: 'builder.js', near: "sel('crate'",
    why: "option label; sel() escapes every option" },
  { match: "${S.loot[0].data.label}", file: 'builder.js', near: "sel('loot'",
    why: "option label; sel() escapes every option" },
  { match: "${z.data.label}", file: 'builder.js', near: "group: 'Drop zones'",
    why: "palette label, escaped where the palette renders" },
  { match: "${res.data.label}", file: 'builder.js', near: 'XS.toast(',
    why: "toasts go in through textContent" },
  { match: "${d.label}", file: 'builder.js', near: 'XS.toast(',
    why: "toasts go in through textContent" },
  { match: "${d.label || 'this zone'}", file: 'builder.js', near: "XS.rpc('b:place'",
    why: "sent to the game as text UI, not markup" },
  { match: "${d.label}", file: 'builder.js', near: 'd.label = `',
    why: "a copy's new name, escaped wherever it is shown" },
  { match: "${t.name}", file: 'builder.js', near: 'modal({',
    why: "modal() escapes its title and text" },
  { match: "${x ? x.label : 'the zone'}", file: 'builder.js', near: 'modal({',
    why: "modal() escapes its title and text" },
  { match: "${z.data.label}", file: 'mock.js', near: 'fail(',
    why: "browser preview only; errors show as toasts through textContent" },
];

const root = process.argv[2] || 'html/js';

const files = [];
(function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, entry.name);
    if (entry.isDirectory()) walk(p);
    else if (entry.name.endsWith('.js')) files.push(p);
  }
})(root);

// ${ ... field ... } where the expression does not mention an escaper.
const RE = new RegExp(
  '\\$\\{(?![^}]*\\b(?:esc|escAttr|escNum|escapeHtml)\\s*\\()[^}]*\\.(?:' + FREE_TEXT + ')\\b[^}]*\\}',
  'g',
);
const EVENT_ATTR = /on\w+\s*=\s*"[^"]*"/g;

let inText = 0;
let inAttr = 0;
const rows = [];

for (const file of files) {
  const lines = readFileSync(file, 'utf8').split('\n');

  lines.forEach((line, i) => {
    // Only lines that are building markup.
    if (!line.includes('${')) return;

    // Whether a value needs escaping depends on where it is being written, and
    // "somewhere on this line" is not good enough: minified files put a dozen
    // statements on one line, so a line can contain both sinks at once.
    //
    // So look BACKWARDS from each match for the nearest of the two. textContent
    // does not parse HTML — tags assigned to it appear on screen as text, which
    // is the entire point — so a value headed there needs no escaping.
    const sinkFor = (index) => {
      const before = line.slice(0, index);
      return before.lastIndexOf('.textContent') > before.lastIndexOf('.innerHTML')
        ? 'text' : 'html';
    };

    const attrRanges = [];
    for (const m of line.matchAll(EVENT_ATTR)) attrRanges.push([m.index, m.index + m[0].length]);

    for (const m of line.matchAll(RE)) {
      if (ALLOW.some((a) => a.match === m[0] && (!a.file || file.endsWith(a.file)) && (!a.near || line.includes(a.near)))) continue;
      if (sinkFor(m.index) === 'text') continue;

      const body = m[0].slice(2, -1);   // inside the ${ }

      // .length and friends are numbers; escaping a number is noise.
      if (/\.(?:length|size|count)\s*$/.test(body)) continue;

      // A comparison yields a literal class name, not the field's value.
      if (/[=!]==|\s<\s|\s>\s/.test(body)) continue;

      // `${helper(x.name)}` — the helper owns what it returns. Escaping here
      // would double-escape whatever it built.
      if (/^\s*[\w.$]+\s*\(/.test(body)) continue;

      // Already inside an enclosing esc(...) that opened earlier on this line.
      const before = line.slice(0, m.index);
      const opens = (before.match(/\b(?:esc|escAttr|escapeHtml)\s*\(/g) || []).length;
      const balance = (before.match(/\(/g) || []).length - (before.match(/\)/g) || []).length;
      if (opens > 0 && balance > 0) continue;

      const inEvent = attrRanges.some(([a, b]) => m.index >= a && m.index < b);
      if (inEvent) inAttr++; else inText++;
      rows.push({ file, line: i + 1, snippet: m[0].slice(0, 70), inEvent });
    }
  });
}

console.log(`  files scanned         : ${files.length}`);
console.log(`  unescaped in markup   : ${inText}   <- escape these`);
console.log(`  unescaped in handlers : ${inAttr}   <- these need delegation, not escaping`);

if (rows.length) {
  console.log('');
  for (const r of rows.filter((r) => !r.inEvent).slice(0, 40)) {
    console.log(`    ${r.file}:${r.line}  ${r.snippet}`);
  }
}

process.exit(inText > 0 ? 1 : 0);
