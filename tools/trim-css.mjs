// Removes rule blocks whose selectors only ever name classes this resource
// does not use.
//
// The stylesheet is a copy of cipher-admin's and arrived carrying three
// quarters of a different application. This is a one-shot cleanup, kept in the
// repo so the next person can see how the trim was decided rather than
// wondering what was cut.
//
// Conservative on purpose:
//   - a block is dropped only when EVERY class in its selector is unused
//   - a selector naming an element, an id or a :pseudo is always kept
//   - @media / @keyframes bodies are left completely alone
//
//   node tools/trim-css.mjs --dry     report only
//   node tools/trim-css.mjs           rewrite the file
import { readFileSync, writeFileSync, globSync } from 'node:fs';

const FILE = 'html/css/style.css';
const dry = process.argv.includes('--dry');

const css = readFileSync(FILE, 'utf8');
const sources = [
  ...globSync('html/*.html', { cwd: process.cwd() }),
  ...globSync('html/js/**/*.js', { cwd: process.cwd() }),
].map((f) => readFileSync(f, 'utf8')).join('\n');

const isUsed = (cls) => sources.includes(cls);

// Walk the stylesheet at brace depth, so at-rule bodies are skipped wholesale.
const out = [];
let i = 0;
let removed = 0;
let removedLines = 0;

while (i < css.length) {
  const braceAt = css.indexOf('{', i);
  if (braceAt === -1) { out.push(css.slice(i)); break; }

  const selector = css.slice(i, braceAt);
  const trimmed = selector.trim();

  // At-rules: copy the whole balanced block through untouched.
  if (trimmed.startsWith('@')) {
    let depth = 0;
    let j = braceAt;
    do {
      if (css[j] === '{') depth++;
      else if (css[j] === '}') depth--;
      j++;
    } while (depth > 0 && j < css.length);

    out.push(css.slice(i, j));
    i = j;
    continue;
  }

  const closeAt = css.indexOf('}', braceAt);
  const end = closeAt === -1 ? css.length : closeAt + 1;
  const block = css.slice(i, end);

  // Split on commas: one selector in a group being live keeps the whole rule.
  const parts = trimmed.split(',').map((p) => p.trim()).filter(Boolean);

  const droppable = parts.length > 0 && parts.every((part) => {
    // Anything that is not purely class-based stays. Element and id selectors
    // can match markup that never names a class at all.
    if (/[#\[]/.test(part)) return false;
    if (/(^|[\s>+~])[a-zA-Z]/.test(part.replace(/\.[\w-]+/g, ''))) return false;

    const classes = [...part.matchAll(/\.([a-zA-Z][\w-]*)/g)].map((m) => m[1]);
    if (classes.length === 0) return false;

    return classes.every((c) => !isUsed(c));
  });

  if (droppable) {
    removed++;
    removedLines += block.split('\n').length - 1;
  } else {
    out.push(block);
  }

  i = end;
}

const result = out.join('').replace(/\n{3,}/g, '\n\n');

console.log(`  rules removed : ${removed}`);
console.log(`  lines         : ${css.split('\n').length} → ${result.split('\n').length}`);

if (dry) {
  console.log('  (dry run — nothing written)');
} else {
  writeFileSync(FILE, result);
  console.log('  written');
}
