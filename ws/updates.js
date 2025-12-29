const http = require('http');
const fs = require('fs');
const path = require('path');

const UPDATES_DIR = process.env.UPDATES_DIR || '/root/doewah/releases';
const UPDATES_PORT = process.env.UPDATES_PORT || 8406;

// Ensure releases directory exists
if (!fs.existsSync(UPDATES_DIR)) {
  fs.mkdirSync(UPDATES_DIR, { recursive: true });
}

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');

  if (req.method === 'GET' && req.url === '/version') {
    // Return current version info
    const versionFile = path.join(UPDATES_DIR, 'version.json');
    if (fs.existsSync(versionFile)) {
      const version = JSON.parse(fs.readFileSync(versionFile, 'utf8'));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(version));
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'No version info available' }));
    }
  } else if (req.method === 'GET' && req.url === '/download') {
    // Serve the latest APK
    const versionFile = path.join(UPDATES_DIR, 'version.json');
    if (!fs.existsSync(versionFile)) {
      res.writeHead(404);
      res.end('No release available');
      return;
    }

    const version = JSON.parse(fs.readFileSync(versionFile, 'utf8'));
    const apkPath = path.join(UPDATES_DIR, version.apkFile);

    if (!fs.existsSync(apkPath)) {
      res.writeHead(404);
      res.end('APK not found');
      return;
    }

    const stat = fs.statSync(apkPath);
    res.writeHead(200, {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': stat.size,
      'Content-Disposition': `attachment; filename="${version.apkFile}"`,
    });

    fs.createReadStream(apkPath).pipe(res);
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

server.listen(UPDATES_PORT, () => {
  console.log(`Update server listening on port ${UPDATES_PORT}`);
  console.log(`Releases directory: ${UPDATES_DIR}`);
});

module.exports = server;
