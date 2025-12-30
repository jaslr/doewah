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

  if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
    // Serve HTML download page
    const versionFile = path.join(UPDATES_DIR, 'version.json');
    let version = { version: 'No release', apkFile: 'N/A', releaseDate: 'N/A' };
    if (fs.existsSync(versionFile)) {
      version = JSON.parse(fs.readFileSync(versionFile, 'utf8'));
    }

    const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Doewah - Download</title>
  <style>
    body { font-family: -apple-system, sans-serif; background: #0F0F23; color: #fff; padding: 20px; text-align: center; }
    .container { max-width: 400px; margin: 50px auto; }
    h1 { color: #6366F1; }
    .version { font-size: 48px; font-weight: bold; margin: 30px 0; }
    .info { color: #888; margin: 10px 0; }
    .download-btn { display: inline-block; background: #6366F1; color: #fff; padding: 16px 32px; border-radius: 8px; text-decoration: none; font-size: 18px; margin-top: 20px; }
    .download-btn:hover { background: #4F46E5; }
    .refresh { color: #6366F1; margin-top: 30px; display: block; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Doewah</h1>
    <div class="version">v${version.version}</div>
    <div class="info">Build: ${version.buildNumber || 'N/A'}</div>
    <div class="info">Released: ${version.releaseDate || 'N/A'}</div>
    <div class="info">File: ${version.apkFile}</div>
    <a href="/download" class="download-btn">Download APK</a>
    <a href="/" class="refresh" onclick="location.reload(); return false;">Refresh</a>
  </div>
</body>
</html>`;

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
  } else if (req.method === 'GET' && req.url === '/version') {
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
