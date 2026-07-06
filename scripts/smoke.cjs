/**
 * Boot-smoke driver: loads the real app main process, waits for the window
 * to paint, captures a screenshot, and exits 0 — or exits 1 on any renderer
 * error. Used headlessly (Xvfb) in development containers and CI:
 *
 *   xvfb-run -a npx electron scripts/smoke.cjs --no-sandbox
 */
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');

let failed = false;

process.on('uncaughtException', (error) => {
  console.error('[smoke] main-process exception:', error);
  process.exit(1);
});

// Load the real app (registers IPC, creates the window on ready).
require(path.join(__dirname, '..', 'dist', 'main', 'index.js'));

app.whenReady().then(() => {
  setTimeout(async () => {
    const win = BrowserWindow.getAllWindows()[0];
    if (!win) {
      console.error('[smoke] no window was created');
      process.exit(1);
    }
    win.webContents.on('console-message', (_e, level, message) => {
      if (level >= 3) {
        console.error('[smoke] renderer error:', message);
        failed = true;
      }
    });
    try {
      const image = await win.webContents.capturePage();
      const out = path.join(__dirname, '..', 'smoke.png');
      fs.writeFileSync(out, image.toPNG());
      console.log('[smoke] screenshot written to', out, `(${image.getSize().width}x${image.getSize().height})`);
    } catch (error) {
      console.error('[smoke] capture failed:', error);
      failed = true;
    }
    console.log(failed ? '[smoke] FAIL' : '[smoke] OK');
    process.exit(failed ? 1 : 0);
  }, 5000);
});
