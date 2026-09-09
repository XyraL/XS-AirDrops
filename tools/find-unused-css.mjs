// Reports CSS class selectors that nothing in this resource uses.
//
// The stylesheet started as a copy of XS-AdminMenu's, so it arrived carrying
// rules for ban tables, threat cards and inventory slots — panels that do not
// exist here. This finds them. It only REPORTS; removing a rule is a decision,
// not something a script should do to a stylesheet unattended.
//
//   node tools/find-unused-css.mjs
import { readFileSync, globSync } from 'node:fs';

const css = readFileSync('html/css/style.css', 'utf8');

// Everything that could name a class at runtime: markup, template literals,
// and classList calls.
const sources = [
  ...globSync('html/*.html', { cwd: process.cwd() }),
  ...globSync('html/js/**/*.js', { cwd: process.cwd() }),
].map((f) => readFileSync(f, 'utf8')).join('\n');

// Class selectors defined in the stylesheet.
const defined = new Set();
for (const m of css.matchAll(/\.([a-zA-Z][\w-]*)/g)) defined.add(m[1]);

// A name counts as used if it appears anywhere in the sources at all. That is
// deliberately generous: classes get built by concatenation ('tag-' + colour),
// and a false "unused" that deletes a live rule is far worse than keeping a
// dead one.
const unused = [];
for (const name of [...defined].sort()) {
  if (!sources.includes(name)) unused.push(name);
}

const totalLines = css.split('\n').length;

console.log(`  stylesheet: ${totalLines} lines, ${defined.size} class selectors`);
console.log(`  unreferenced: ${unused.length}\n`);

// Grouped by prefix, because they come in families and a family is what you
// would actually delete.
const groups = {};
for (const name of unused) {
  const key = name.split('-')[0];
  (groups[key] ||= []).push(name);
}

const sorted = Object.entries(groups).sort((a, b) => b[1].length - a[1].length);
for (const [prefix, names] of sorted.slice(0, 20)) {
  console.log(`  ${prefix.padEnd(14)} ${String(names.length).padStart(3)}  ${names.slice(0, 6).join(', ')}${names.length > 6 ? ' …' : ''}`);
}
