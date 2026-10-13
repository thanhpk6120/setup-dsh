import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { launchPersistentContext } from 'cloakbrowser';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const targetUrl = process.argv[2] || process.env.TARGET_URL || 'http://localhost:8080/web/guest/login';

const context = await launchPersistentContext({
  userDataDir: path.join(__dirname, 'chrome-profile-verify'),
  headless: false,
  humanize: true,
  locale: 'vi-VN',
  timezoneId: 'Asia/Ho_Chi_Minh',
  viewport: { width: 1366, height: 768 },
});
const page = context.pages()[0] ?? await context.newPage();
await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
console.log(`CloakBrowser verify UI ready on ${targetUrl}. Close the browser window to stop.`);
await new Promise((resolve) => context.on('close', resolve));
