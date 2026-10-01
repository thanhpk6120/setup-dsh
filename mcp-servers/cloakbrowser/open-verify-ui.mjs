import { launchPersistentContext } from 'cloakbrowser';
const context = await launchPersistentContext({
  userDataDir: 'D:/Project/AI/cloakbrowser/chrome-profile-verify',
  headless: false,
  humanize: true,
  locale: 'vi-VN',
  timezoneId: 'Asia/Ho_Chi_Minh',
  viewport: { width: 1366, height: 768 },
});
const page = context.pages()[0] ?? await context.newPage();
await page.goto('http://localhost:8080/web/guest/login', { waitUntil: 'domcontentloaded' });
console.log('CloakBrowser verify UI ready. Close the browser window to stop.');
await new Promise((resolve) => context.on('close', resolve));
