// Which config settings can an admin change in the panel, and which still
// require editing a file and restarting?
//
// "Fully editable through the panel" is a goal you can measure, and this is the
// measurement. Anything listed as not-exposed is either a deliberate decision
// (structural settings the panel cannot express) or an oversight.
//
//   node tools/check-settings-coverage.mjs
import { readFileSync } from 'node:fs';

// Settings that stay in the file on purpose, and why.
//
// Without this the report reads as a to-do list and someone eventually "fixes"
// it by putting admin permissions in the admin panel.
const DELIBERATE = {
  'Bridges.framework': 'detected at boot; changing it live cannot re-detect',
  'Bridges.inventory': 'detected at boot; changing it live cannot re-detect',

  'AdminCommand.Enabled': 'turning the command off from inside it locks you out',
  'AdminCommand.Command': 'the command is registered at boot',
  'AdminCommand.Aces': 'SECURITY — granting panel access from the panel is escalation',
  'Admin.acePermission': 'SECURITY — same',
  'Admin.groups': 'SECURITY — same',
  'Admin.licenses': 'SECURITY — same',

  'Announce.Webhook': 'a credential; anyone who can post to it can post as you',

  'Bridges.dispatch': 'detected at boot; changing it live cannot re-detect',
  'AdminCommand.Builder': 'the command is registered at boot',

  'Loot.Tiers': 'seeds the first loot table; Loot tables in the builder own it after that',
  'Loot.Slots': 'seeds the first crate type; Crate types in the builder own it after that',
  'Loot.MaxWeight': 'seeds the first crate type',
  'Loot.MinStacks': 'seeds the first loot table',
  'Loot.MaxStacks': 'seeds the first loot table',
  'Loot.StacksPerSearch': 'seeds the first crate type',
  'Loot.GuaranteeAtLeast': 'seeds the first loot table',
  'Drop.CrackTime': 'seeds the first crate type',
  'Delivery.PlaneModel': 'seeds the first crate type',
  'Delivery.CrateModel': 'seeds the first crate type',
  'Delivery.Altitude': 'seeds the first crate type',
  'Police.Alert': 'seeds the first crate type',
  'Police.Delay': 'seeds the first crate type',
  'Blip.Sprite': 'seeds the first crate type',
  'Blip.Colour': 'seeds the first crate type',
  'Builder.cameraSpeed': 'its fields are exposed',
  'Sounds.Events': 'sound name and set pairs; a table, not a setting',
  'Schedule.Hours': 'its fields are exposed',

  // Parents whose children are all exposed individually.
  'Access.See': 'its fields are exposed',
  'Access.Collect': 'its fields are exposed',
  'Access.Police': 'its fields are exposed',
};

const cfg = readFileSync('config.lua', 'utf8');
const schema = readFileSync('shared/settings.lua', 'utf8');

// Settings the panel already drives.
const exposed = new Set(
  [...schema.matchAll(/\{ '([A-Za-z]+\.[^']+)', '/g)].map((m) => m[1]),
);

// Every `Section.Key` in config.lua: a top-level `Config.Section = {` followed
// by indented `Key =` lines.
const settings = [];
let section = null;

for (const line of cfg.split('\n')) {
  const top = line.match(/^Config\.([A-Za-z][\w]*)\s*=/);
  if (top) { section = top[1]; continue; }

  // A nested table opening resets nothing; we only track depth-1 keys.
  const key = line.match(/^ {4}([A-Za-z][\w]*)\s*=/);
  if (key && section) settings.push(`${section}.${key[1]}`);
}

const notExposed = settings.filter((s) => !exposed.has(s));
const deliberate = notExposed.filter((s) => DELIBERATE[s]);
const unexplained = notExposed.filter((s) => !DELIBERATE[s]);

console.log(`  settings in config.lua : ${settings.length}`);
console.log(`  editable in the panel  : ${settings.length - notExposed.length}`);
console.log(`  file-only on purpose   : ${deliberate.length}`);
console.log(`  file-only, unexplained : ${unexplained.length}`);

if (unexplained.length) {
  console.log('\n  Either expose these, or say here why not:');
  for (const m of unexplained) console.log('    ' + m);
  process.exit(1);
}
