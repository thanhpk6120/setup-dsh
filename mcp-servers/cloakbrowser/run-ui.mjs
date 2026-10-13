import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { launchPersistentContext } from 'cloakbrowser';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const targetUrl = process.argv[2] || process.env.TARGET_URL || 'https://google.com';

const context = await launchPersistentContext({
  userDataDir: path.join(__dirname, 'chrome-profile'),
  headless: false,
  humanize: true,
  locale: 'vi-VN',
  timezoneId: 'Asia/Ho_Chi_Minh',
  viewport: { width: 1366, height: 768 },
});
const page = context.pages()[0] ?? await context.newPage();
await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
console.log(`CloakBrowser is open on ${targetUrl}. Please login. Close the browser window to stop the script.`);
await new Promise((resolve) => context.on('close', resolve));
