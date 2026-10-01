import { launchPersistentContext } from 'cloakbrowser';
const context = await launchPersistentContext({
  userDataDir: 'D:/Thanhpk/AI/cloakbrowser/chrome-profile',
  headless: false,
  humanize: true,
  locale: 'vi-VN',
  timezoneId: 'Asia/Ho_Chi_Minh',
  viewport: { width: 1366, height: 768 },
});
const page = context.pages()[0] ?? await context.newPage();
await page.goto('http://10.30.1.17/bankhub/bankhub-admin-be/-/pipelines', { waitUntil: 'domcontentloaded' });
console.log('CloakBrowser is open. Please login. Close the browser window to stop the script.');
await new Promise((resolve) => context.on('close', resolve));
