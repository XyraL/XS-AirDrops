// Dev-only static server for html/preview.html.
//
// The preview harness is plain file:// HTML, but the browser pane renders
// out-of-tree file URLs as static snapshots, so the scripts never run and
// nothing can be verified. Serving the same directory over http makes it a
// real page. Not referenced by fxmanifest — FiveM never sees this.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };

http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  const rel = url === '/' ? '/preview.html' : url;
  const file = path.join(ROOT, rel);

  if (!file.startsWith(ROOT)) { res.writeHead(403).end(); return; }

  fs.readFile(file, (err, buf) => {
    if (err) { res.writeHead(404).end('not found'); return; }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    res.end(buf);
  });
}).listen(5174, () => console.log("preview harness on http://localhost:5174"));
