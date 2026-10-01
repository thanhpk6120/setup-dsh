#!/usr/bin/env node
// Full-coverage MCP server cho CloakBrowser stealth automation.
// Singleton browser context + multi-tab. Profile tách theo tên (default, shopee, tiki...).
//
// Đăng ký:
//   claude mcp add cloakbrowser -- node "D:/Project/AI/cloakbrowser/mcp-server-full.mjs"
//
// Profile mặc định = 'default'. Data profile lưu trong cùng thư mục file này
// (PROFILES_ROOT = __dirname = D:/Project/AI/cloakbrowser). Chỉ truyền `profile`
// khác khi cần session riêng (vd: shopee, tiki...).

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { launchPersistentContext } from 'cloakbrowser';
import path from 'node:path';
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROFILES_ROOT = __dirname;

// ---------- State ----------
const contexts = new Map();   // profileName -> Promise<BrowserContext>
const tabs = new Map();       // tabId -> { page, profile, createdAt }
let nextTabId = 1;

function profilePath(name) {
  return path.join(PROFILES_ROOT, `chrome-profile${name === 'default' ? '' : `-${name}`}`);
}

async function getContext(profile = 'default') {
  if (!contexts.has(profile)) {
    const dir = profilePath(profile);
    const launch = (userDataDir = dir) => launchPersistentContext({
      userDataDir,
      headless: true,
      humanize: true,
      locale: 'vi-VN',
      timezoneId: 'Asia/Ho_Chi_Minh',
      viewport: { width: 1366, height: 768 },
    });
    const contextPromise = (async () => {
      try {
        return await launch();
      } catch (firstError) {
        // A transient Chromium crash must not poison this profile's context cache.
        try {
          return await launch();
        } catch (secondError) {
          // ponytail: Recovery sessions are unauthenticated; restore the original profile after its launch issue is repaired.
          const recoveryDir = path.join(PROFILES_ROOT, `chrome-profile-${profile}-recovery`);
          try {
            return await launch(recoveryDir);
          } catch (recoveryError) {
            recoveryError.message = `CloakBrowser không khởi động được với profile ${profile} hoặc profile recovery: ${recoveryError.message}`;
            throw recoveryError;
          }
        }
      }
    })();
    contexts.set(profile, contextPromise);
    contextPromise.catch(() => contexts.delete(profile));
  }
  return contexts.get(profile);
}

async function getTab(tabId) {
  const tab = tabs.get(tabId);
  if (!tab) throw new Error(`Tab ${tabId} không tồn tại. Dùng tab_open trước.`);
  if (tab.page.isClosed()) {
    tabs.delete(tabId);
    throw new Error(`Tab ${tabId} đã đóng.`);
  }
  return tab.page;
}

async function shutdown() {
  for (const [, p] of contexts) {
    const ctx = await p.catch(() => null);
    if (ctx) await ctx.close().catch(() => {});
  }
}

// ---------- Tool implementations ----------

async function tab_open({ url, profile = 'default' }) {
  const ctx = await getContext(profile);
  const page = await ctx.newPage();
  if (url) await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  const id = `t${nextTabId++}`;
  tabs.set(id, { page, profile, createdAt: Date.now() });
  return { tabId: id, profile, url: page.url(), title: await page.title() };
}

async function tab_close({ tabId }) {
  const tab = tabs.get(tabId);
  if (!tab) return { closed: false, reason: 'not found' };
  await tab.page.close().catch(() => {});
  tabs.delete(tabId);
  return { closed: true, tabId };
}

async function tab_list() {
  const out = [];
  for (const [id, tab] of tabs) {
    if (tab.page.isClosed()) { tabs.delete(id); continue; }
    out.push({
      tabId: id,
      profile: tab.profile,
      url: tab.page.url(),
      title: await tab.page.title().catch(() => null),
      ageMs: Date.now() - tab.createdAt,
    });
  }
  return { tabs: out };
}

async function navigate({ tabId, url, waitUntil = 'domcontentloaded', timeout = 60000 }) {
  const page = await getTab(tabId);
  const res = await page.goto(url, { waitUntil, timeout });
  return { status: res?.status() ?? null, finalUrl: page.url(), title: await page.title() };
}

async function go_back({ tabId }) {
  const page = await getTab(tabId);
  await page.goBack({ waitUntil: 'domcontentloaded' });
  return { url: page.url() };
}

async function go_forward({ tabId }) {
  const page = await getTab(tabId);
  await page.goForward({ waitUntil: 'domcontentloaded' });
  return { url: page.url() };
}

async function reload({ tabId }) {
  const page = await getTab(tabId);
  await page.reload({ waitUntil: 'domcontentloaded' });
  return { url: page.url() };
}

async function get_url({ tabId }) {
  const page = await getTab(tabId);
  return { url: page.url() };
}

async function get_title({ tabId }) {
  const page = await getTab(tabId);
  return { title: await page.title() };
}

async function get_html({ tabId, selector }) {
  const page = await getTab(tabId);
  if (selector) {
    const el = await page.$(selector);
    if (!el) throw new Error(`Selector không tìm thấy: ${selector}`);
    return { html: await el.innerHTML() };
  }
  return { html: await page.content() };
}

async function get_text({ tabId, selector }) {
  const page = await getTab(tabId);
  if (selector) {
    const el = await page.$(selector);
    if (!el) throw new Error(`Selector không tìm thấy: ${selector}`);
    return { text: await el.innerText() };
  }
  return { text: await page.evaluate(() => document.body.innerText) };
}

async function screenshot({ tabId, fullPage = false, selector, savePath }) {
  const page = await getTab(tabId);
  let buf;
  if (selector) {
    const el = await page.$(selector);
    if (!el) throw new Error(`Selector không tìm thấy: ${selector}`);
    buf = await el.screenshot();
  } else {
    buf = await page.screenshot({ fullPage });
  }
  if (savePath) {
    await fs.writeFile(savePath, buf);
    return { saved: savePath, sizeBytes: buf.length };
  }
  return { base64: buf.toString('base64'), sizeBytes: buf.length };
}

async function pdf({ tabId, savePath }) {
  const page = await getTab(tabId);
  const buf = await page.pdf({ format: 'A4' });
  if (savePath) {
    await fs.writeFile(savePath, buf);
    return { saved: savePath, sizeBytes: buf.length };
  }
  return { base64: buf.toString('base64'), sizeBytes: buf.length };
}

async function click({ tabId, selector, button = 'left', clickCount = 1, timeout = 10000 }) {
  const page = await getTab(tabId);
  await page.click(selector, { button, clickCount, timeout });
  return { clicked: selector };
}

async function type_text({ tabId, selector, text, delay = 30, clear = false }) {
  const page = await getTab(tabId);
  if (clear) await page.fill(selector, '');
  await page.type(selector, text, { delay });
  return { typed: selector, length: text.length };
}

async function fill({ tabId, selector, value }) {
  const page = await getTab(tabId);
  await page.fill(selector, value);
  return { filled: selector };
}

async function select_option({ tabId, selector, values }) {
  const page = await getTab(tabId);
  const result = await page.selectOption(selector, values);
  return { selected: result };
}

async function check({ tabId, selector, checked = true }) {
  const page = await getTab(tabId);
  if (checked) await page.check(selector);
  else await page.uncheck(selector);
  return { selector, checked };
}

async function hover({ tabId, selector }) {
  const page = await getTab(tabId);
  await page.hover(selector);
  return { hovered: selector };
}

async function press_key({ tabId, key, selector }) {
  const page = await getTab(tabId);
  if (selector) await page.press(selector, key);
  else await page.keyboard.press(key);
  return { pressed: key };
}

async function upload_file({ tabId, selector, filePaths }) {
  const page = await getTab(tabId);
  await page.setInputFiles(selector, filePaths);
  return { uploaded: filePaths };
}

async function wait_for_selector({ tabId, selector, state = 'visible', timeout = 30000 }) {
  const page = await getTab(tabId);
  await page.waitForSelector(selector, { state, timeout });
  return { found: selector };
}

async function wait_for_text({ tabId, text, timeout = 30000 }) {
  const page = await getTab(tabId);
  await page.waitForFunction((t) => document.body?.innerText?.includes(t), text, { timeout });
  return { found: text };
}

async function wait_for_url({ tabId, urlPattern, timeout = 30000 }) {
  const page = await getTab(tabId);
  await page.waitForURL(new RegExp(urlPattern), { timeout });
  return { url: page.url() };
}

async function wait_for_timeout({ tabId, ms }) {
  const page = await getTab(tabId);
  await page.waitForTimeout(ms);
  return { waited: ms };
}

async function query_selector({ tabId, selector }) {
  const page = await getTab(tabId);
  const result = await page.evaluate((sel) => {
    const el = document.querySelector(sel);
    if (!el) return null;
    return {
      tag: el.tagName.toLowerCase(),
      text: el.textContent?.trim().slice(0, 200) ?? null,
      attributes: Object.fromEntries(Array.from(el.attributes).map(a => [a.name, a.value])),
    };
  }, selector);
  return { element: result };
}

async function query_all({ tabId, selector, limit = 50 }) {
  const page = await getTab(tabId);
  const result = await page.evaluate(({ sel, lim }) => {
    return Array.from(document.querySelectorAll(sel)).slice(0, lim).map(el => ({
      tag: el.tagName.toLowerCase(),
      text: el.textContent?.trim().slice(0, 200) ?? null,
      href: el.getAttribute('href'),
      src: el.getAttribute('src'),
    }));
  }, { sel: selector, lim: limit });
  return { count: result.length, elements: result };
}

async function evaluate({ tabId, script, arg }) {
  const page = await getTab(tabId);
  // Wrap script trong function để tránh syntax error với expression statement
  const fn = new Function('arg', `return (async () => { ${script} })();`);
  // Eval qua page để chạy trong context browser
  const result = await page.evaluate(
    ({ src, a }) => {
      const f = new Function('arg', `return (async () => { ${src} })();`);
      return f(a);
    },
    { src: script, a: arg ?? null }
  );
  return { result };
}

async function extract_links({ tabId, base }) {
  const page = await getTab(tabId);
  return await page.evaluate((b) => {
    const baseUrl = b || location.origin;
    const links = Array.from(document.querySelectorAll('a[href]'));
    return {
      count: links.length,
      links: links.slice(0, 200).map(a => ({
        href: new URL(a.getAttribute('href'), baseUrl).href,
        text: a.textContent?.trim().slice(0, 120) ?? null,
      })),
    };
  }, base);
}

async function extract_table({ tabId, selector = 'table' }) {
  const page = await getTab(tabId);
  return await page.evaluate((sel) => {
    const t = document.querySelector(sel);
    if (!t) return null;
    const rows = Array.from(t.querySelectorAll('tr')).map(tr =>
      Array.from(tr.querySelectorAll('th,td')).map(c => c.textContent?.trim() ?? '')
    );
    return { rows };
  }, selector);
}

async function get_cookies({ profile = 'default', urls }) {
  const ctx = await getContext(profile);
  const cookies = await ctx.cookies(urls);
  return { count: cookies.length, cookies };
}

async function set_cookies({ profile = 'default', cookies }) {
  const ctx = await getContext(profile);
  await ctx.addCookies(cookies);
  return { added: cookies.length };
}

async function clear_cookies({ profile = 'default' }) {
  const ctx = await getContext(profile);
  await ctx.clearCookies();
  return { cleared: true };
}

async function get_local_storage({ tabId }) {
  const page = await getTab(tabId);
  return await page.evaluate(() => {
    const out = {};
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k) out[k] = localStorage.getItem(k);
    }
    return { items: out };
  });
}

async function profile_login({ profile = 'default', url }) {
  // Mở browser KHÔNG headless để user tự login.
  // Sau khi user đóng cửa sổ → context tự cleanup.
  const dir = profilePath(profile);
  // Đóng context cũ nếu đang mở (cần re-open ở mode headed)
  if (contexts.has(profile)) {
    const ctx = await contexts.get(profile).catch(() => null);
    if (ctx) await ctx.close().catch(() => {});
    contexts.delete(profile);
  }
  const ctx = await launchPersistentContext({
    userDataDir: dir,
    headless: false,
    humanize: true,
    locale: 'vi-VN',
    timezoneId: 'Asia/Ho_Chi_Minh',
    viewport: { width: 1366, height: 768 },
  });
  const page = ctx.pages()[0] ?? await ctx.newPage();
  if (url) await page.goto(url, { waitUntil: 'domcontentloaded' });
  return {
    message: `Browser mở ở mode UI để bạn login. Đóng cửa sổ sau khi xong, cookies sẽ lưu vào ${dir}.`,
    profile,
    profileDir: dir,
    note: 'Sau khi đóng browser, gọi lại tool khác để dùng profile (đã có cookies).',
  };
}

async function profile_list() {
  const entries = await fs.readdir(PROFILES_ROOT, { withFileTypes: true });
  const profiles = entries
    .filter(e => e.isDirectory() && e.name.startsWith('chrome-profile'))
    .map(e => e.name === 'chrome-profile' ? 'default' : e.name.replace('chrome-profile-', ''));
  return { profiles };
}

async function profile_delete({ profile }) {
  if (profile === 'default') throw new Error('Không xóa được default profile qua tool. Xóa thủ công nếu cần.');
  if (contexts.has(profile)) {
    const ctx = await contexts.get(profile).catch(() => null);
    if (ctx) await ctx.close().catch(() => {});
    contexts.delete(profile);
  }
  const dir = profilePath(profile);
  await fs.rm(dir, { recursive: true, force: true });
  return { deleted: profile };
}

// Domain-specific shortcut: shopee_scrape (giữ lại từ server cũ)
async function shopee_scrape({ url, profile = 'default' }) {
  const ctx = await getContext(profile);
  const page = await ctx.newPage();
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(2500);
    const finalUrl = page.url();
    const m = finalUrl.match(/\/(?:product\/|[^/]+\/)(\d+)\/(\d+)/);
    if (!m) throw new Error(`Không bóc được shopId/itemId: ${finalUrl}`);
    const [, shopId, itemId] = m;
    const apiUrl = `https://shopee.vn/api/v4/pdp/get_pc?shop_id=${shopId}&item_id=${itemId}&tz_offset_minutes=420&detail_level=0`;
    const apiData = await page.evaluate(async (u) => {
      const res = await fetch(u, {
        headers: { 'x-api-source': 'pc', 'x-shopee-language': 'vi', 'x-requested-with': 'XMLHttpRequest' },
        credentials: 'include',
      });
      return { status: res.status, body: await res.json().catch(() => null) };
    }, apiUrl);

    if (apiData.status !== 200 || !apiData.body?.data) {
      const fb = await page.evaluate(() => ({
        title: document.title,
        ogTitle: document.querySelector('meta[property="og:title"]')?.getAttribute('content') ?? null,
        ogImage: document.querySelector('meta[property="og:image"]')?.getAttribute('content') ?? null,
        h1: document.querySelector('h1')?.textContent?.trim() ?? null,
      }));
      return { source: 'dom-fallback', url: finalUrl, shopId, itemId, ...fb };
    }
    const item = apiData.body.data.item ?? apiData.body.data;
    return {
      source: 'api', url: finalUrl, shopId, itemId,
      name: item.name ?? null,
      price: item.price != null ? item.price / 100000 : null,
      priceMin: item.price_min != null ? item.price_min / 100000 : null,
      priceMax: item.price_max != null ? item.price_max / 100000 : null,
      currency: item.currency ?? 'VND',
      stock: item.stock ?? null,
      sold: item.historical_sold ?? item.sold ?? null,
      liked: item.liked_count ?? null,
      rating: item.item_rating?.rating_star ?? null,
      ratingCount: item.item_rating?.rating_count?.[0] ?? null,
      images: (item.images ?? []).map(id => id.startsWith('http') ? id : `https://down-vn.img.susercontent.com/file/${id}`),
      description: item.description ?? null,
      brand: item.brand ?? null,
      shopLocation: item.shop_location ?? null,
      categories: (item.categories ?? []).map(c => c.display_name ?? c.name).filter(Boolean),
      fetchedAt: new Date().toISOString(),
    };
  } finally {
    await page.close().catch(() => {});
  }
}

// ---------- Extra tools ----------

async function download_file({ url, savePath, profile = 'default' }) {
  const ctx = await getContext(profile);
  // Tạo page tạm để fetch với cookies
  const page = await ctx.newPage();
  try {
    const result = await page.evaluate(async (u) => {
      const res = await fetch(u, { credentials: 'include' });
      if (!res.ok) return { error: `HTTP ${res.status}` };
      const buf = await res.arrayBuffer();
      const bytes = new Uint8Array(buf);
      // Trả base64 chunked
      let s = '';
      for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
      return { status: res.status, contentType: res.headers.get('content-type'), base64: btoa(s), size: bytes.length };
    }, url);
    if (result.error) throw new Error(result.error);
    const buf = Buffer.from(result.base64, 'base64');
    await fs.writeFile(savePath, buf);
    return { saved: savePath, sizeBytes: buf.length, contentType: result.contentType };
  } finally {
    await page.close().catch(() => {});
  }
}

async function intercept_response({ tabId, urlPattern, navigateTo, timeout = 30000 }) {
  const page = await getTab(tabId);
  const re = new RegExp(urlPattern);
  const responses = [];
  const handler = async (response) => {
    if (re.test(response.url())) {
      const status = response.status();
      let body = null;
      const ct = response.headers()['content-type'] || '';
      if (ct.includes('json') || ct.includes('text')) {
        body = await response.text().catch(() => null);
      }
      responses.push({ url: response.url(), status, contentType: ct, body });
    }
  };
  page.on('response', handler);
  try {
    if (navigateTo) await page.goto(navigateTo, { waitUntil: 'domcontentloaded', timeout });
    else await page.waitForTimeout(Math.min(timeout, 5000));
    // Chờ thêm chút để response cuối kịp về
    await page.waitForTimeout(1500);
  } finally {
    page.off('response', handler);
  }
  return { matched: responses.length, responses: responses.slice(0, 50) };
}

async function set_request_headers({ tabId, headers }) {
  const page = await getTab(tabId);
  await page.setExtraHTTPHeaders(headers);
  return { set: Object.keys(headers) };
}

async function block_resources({ tabId, types = ['image', 'font', 'stylesheet', 'media'] }) {
  const page = await getTab(tabId);
  await page.route('**/*', (route) => {
    if (types.includes(route.request().resourceType())) {
      return route.abort();
    }
    return route.continue();
  });
  return { blocking: types };
}

async function iframe_list({ tabId }) {
  const page = await getTab(tabId);
  const frames = page.frames();
  return {
    count: frames.length,
    frames: frames.map((f, i) => ({ index: i, url: f.url(), name: f.name() })),
  };
}

async function iframe_eval({ tabId, frameIndex, script, arg }) {
  const page = await getTab(tabId);
  const frame = page.frames()[frameIndex];
  if (!frame) throw new Error(`iframe index ${frameIndex} không tồn tại`);
  const result = await frame.evaluate(
    ({ src, a }) => {
      const f = new Function('arg', `return (async () => { ${src} })();`);
      return f(a);
    },
    { src: script, a: arg ?? null }
  );
  return { result, frameUrl: frame.url() };
}

async function set_storage_state({ profile = 'default', state }) {
  // state shape: { cookies: [...], origins: [{ origin, localStorage: [{name,value}] }] }
  const ctx = await getContext(profile);
  if (state.cookies?.length) await ctx.addCookies(state.cookies);
  if (state.origins?.length) {
    const page = await ctx.newPage();
    try {
      for (const o of state.origins) {
        await page.goto(o.origin, { waitUntil: 'domcontentloaded' });
        await page.evaluate((items) => {
          for (const it of items) localStorage.setItem(it.name, it.value);
        }, o.localStorage ?? []);
      }
    } finally {
      await page.close().catch(() => {});
    }
  }
  return { cookies: state.cookies?.length ?? 0, origins: state.origins?.length ?? 0 };
}

async function export_storage_state({ profile = 'default', savePath }) {
  const ctx = await getContext(profile);
  const state = await ctx.storageState();
  if (savePath) {
    await fs.writeFile(savePath, JSON.stringify(state, null, 2));
    return { saved: savePath, cookies: state.cookies.length, origins: state.origins.length };
  }
  return state;
}

async function scroll({ tabId, selector, direction = 'down', amount = 800, smooth = false }) {
  const page = await getTab(tabId);
  const result = await page.evaluate(
    ({ sel, dir, amt, sm }) => {
      const target = sel ? document.querySelector(sel) : window;
      if (!target) return { error: `selector không tồn tại: ${sel}` };
      const dx = dir === 'left' ? -amt : dir === 'right' ? amt : 0;
      const dy = dir === 'up' ? -amt : dir === 'down' ? amt : 0;
      if (target === window) {
        window.scrollBy({ left: dx, top: dy, behavior: sm ? 'smooth' : 'auto' });
        return { scrollY: window.scrollY, scrollX: window.scrollX };
      }
      target.scrollBy({ left: dx, top: dy, behavior: sm ? 'smooth' : 'auto' });
      return { scrollTop: target.scrollTop, scrollLeft: target.scrollLeft };
    },
    { sel: selector, dir: direction, amt: amount, sm: smooth }
  );
  if (result.error) throw new Error(result.error);
  await page.waitForTimeout(smooth ? 600 : 200);
  return result;
}

async function drag_and_drop({ tabId, sourceSelector, targetSelector }) {
  const page = await getTab(tabId);
  await page.dragAndDrop(sourceSelector, targetSelector);
  return { from: sourceSelector, to: targetSelector };
}

async function solve_captcha_2captcha({ tabId, type = 'recaptcha-v2', siteKey, pageUrl }) {
  const apiKey = process.env.CAPTCHA_API_KEY;
  if (!apiKey) {
    throw new Error('CAPTCHA_API_KEY env var chưa set. Cần API key 2captcha (https://2captcha.com).');
  }
  if (!siteKey) throw new Error('siteKey bắt buộc (lấy từ data-sitekey trong DOM).');
  const page = await getTab(tabId);
  const url = pageUrl ?? page.url();

  // Submit job
  const submitUrl = `https://2captcha.com/in.php?key=${apiKey}&method=userrecaptcha&googlekey=${siteKey}&pageurl=${encodeURIComponent(url)}&json=1`;
  const submit = await fetch(submitUrl).then(r => r.json());
  if (submit.status !== 1) throw new Error(`2captcha submit fail: ${submit.request}`);
  const reqId = submit.request;

  // Poll result (~10s interval, max 120s)
  for (let i = 0; i < 24; i++) {
    await new Promise(r => setTimeout(r, 10000));
    const poll = await fetch(`https://2captcha.com/res.php?key=${apiKey}&action=get&id=${reqId}&json=1`).then(r => r.json());
    if (poll.status === 1) {
      const token = poll.request;
      // Inject token vào response field
      await page.evaluate((t) => {
        const ta = document.querySelector('textarea[name="g-recaptcha-response"]');
        if (ta) { ta.style.display = 'block'; ta.value = t; }
        if (window.___grecaptcha_cfg) {
          // best-effort callback trigger
          for (const k of Object.keys(window.___grecaptcha_cfg.clients ?? {})) {
            const client = window.___grecaptcha_cfg.clients[k];
            for (const path of Object.keys(client)) {
              const cb = client[path]?.callback;
              if (typeof cb === 'function') try { cb(t); } catch {}
            }
          }
        }
      }, token);
      return { solved: true, type, tokenLength: token.length, requestId: reqId };
    }
    if (poll.request !== 'CAPCHA_NOT_READY') throw new Error(`2captcha error: ${poll.request}`);
  }
  throw new Error('2captcha timeout sau 240s');
}

async function bulk_scrape({ urls, profile = 'default', concurrency = 3, extractor = 'meta' }) {
  // extractor: 'meta' (og tags), 'text' (innerText), 'html' (full html)
  const ctx = await getContext(profile);
  const results = [];
  const queue = [...urls];

  async function worker() {
    while (queue.length) {
      const url = queue.shift();
      const page = await ctx.newPage();
      try {
        const res = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
        await page.waitForTimeout(1500);
        let data;
        if (extractor === 'meta') {
          data = await page.evaluate(() => ({
            title: document.title,
            ogTitle: document.querySelector('meta[property="og:title"]')?.getAttribute('content') ?? null,
            ogImage: document.querySelector('meta[property="og:image"]')?.getAttribute('content') ?? null,
            ogDescription: document.querySelector('meta[property="og:description"]')?.getAttribute('content') ?? null,
            h1: document.querySelector('h1')?.textContent?.trim() ?? null,
          }));
        } else if (extractor === 'text') {
          data = { text: await page.evaluate(() => document.body.innerText.slice(0, 5000)) };
        } else if (extractor === 'html') {
          data = { html: await page.content() };
        } else {
          data = { error: `Unknown extractor: ${extractor}` };
        }
        results.push({ url, finalUrl: page.url(), status: res?.status() ?? null, ...data });
      } catch (err) {
        results.push({ url, error: err.message });
      } finally {
        await page.close().catch(() => {});
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(concurrency, urls.length) }, worker));
  return { count: results.length, results };
}

// ---------- Tool catalog ----------
const tools = [
  // Tab/Session (4)
  { name: 'tab_open', desc: 'Mở tab mới (tùy chọn navigate URL). Trả về tabId để dùng cho tool khác.',
    schema: { type: 'object', properties: { url: { type: 'string' }, profile: { type: 'string', default: 'default' } } } },
  { name: 'tab_close', desc: 'Đóng tab.',
    schema: { type: 'object', properties: { tabId: { type: 'string' } }, required: ['tabId'] } },
  { name: 'tab_list', desc: 'Liệt kê tabs đang mở.', schema: { type: 'object', properties: {} } },

  // Navigation (4)
  { name: 'navigate', desc: 'Điều hướng tab tới URL.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, url: { type: 'string' }, waitUntil: { type: 'string', enum: ['load', 'domcontentloaded', 'networkidle'], default: 'domcontentloaded' }, timeout: { type: 'number', default: 60000 } }, required: ['tabId', 'url'] } },
  { name: 'go_back', desc: 'Back trong history.',
    schema: { type: 'object', properties: { tabId: { type: 'string' } }, required: ['tabId'] } },
  { name: 'go_forward', desc: 'Forward trong history.',
    schema: { type: 'object', properties: { tabId: { type: 'string' } }, required: ['tabId'] } },
  { name: 'reload', desc: 'Reload trang.',
    schema: { type: 'object', properties: { tabId: { type: 'string' } }, required: ['tabId'] } },

  // Page state (5)
  { name: 'get_url', desc: 'Lấy URL hiện tại.', schema: { type: 'object', properties: { tabId: { type: 'string' } }, required: ['tabId'] } },
  { name: 'get_title', desc: 'Lấy title.', schema: { type: 'object', properties: { tabId: { type: 'string' } }, required: ['tabId'] } },
  { name: 'get_html', desc: 'Lấy HTML toàn trang hoặc của selector.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' } }, required: ['tabId'] } },
  { name: 'get_text', desc: 'Lấy text rendered toàn trang hoặc của selector.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' } }, required: ['tabId'] } },
  { name: 'screenshot', desc: 'Screenshot (toàn trang/viewport/selector). Tùy chọn savePath để ghi file thay vì base64.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, fullPage: { type: 'boolean', default: false }, selector: { type: 'string' }, savePath: { type: 'string' } }, required: ['tabId'] } },
  { name: 'pdf', desc: 'Render trang ra PDF A4. Tùy chọn savePath.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, savePath: { type: 'string' } }, required: ['tabId'] } },

  // Interaction (8)
  { name: 'click', desc: 'Click selector.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, button: { type: 'string', enum: ['left', 'right', 'middle'], default: 'left' }, clickCount: { type: 'number', default: 1 }, timeout: { type: 'number', default: 10000 } }, required: ['tabId', 'selector'] } },
  { name: 'type_text', desc: 'Type ký tự vào element (mô phỏng gõ phím với delay). Set clear=true để xóa value cũ trước.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, text: { type: 'string' }, delay: { type: 'number', default: 30 }, clear: { type: 'boolean', default: false } }, required: ['tabId', 'selector', 'text'] } },
  { name: 'fill', desc: 'Fill nhanh value vào input (không mô phỏng gõ).',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, value: { type: 'string' } }, required: ['tabId', 'selector', 'value'] } },
  { name: 'select_option', desc: 'Chọn option trong <select>.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, values: { type: 'array', items: { type: 'string' } } }, required: ['tabId', 'selector', 'values'] } },
  { name: 'check', desc: 'Check/uncheck checkbox hoặc radio.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, checked: { type: 'boolean', default: true } }, required: ['tabId', 'selector'] } },
  { name: 'hover', desc: 'Hover element.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' } }, required: ['tabId', 'selector'] } },
  { name: 'press_key', desc: 'Nhấn phím (Enter, Tab, ArrowDown...). selector optional → focus rồi nhấn.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, key: { type: 'string' }, selector: { type: 'string' } }, required: ['tabId', 'key'] } },
  { name: 'upload_file', desc: 'Upload file qua <input type="file">.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, filePaths: { type: 'array', items: { type: 'string' } } }, required: ['tabId', 'selector', 'filePaths'] } },

  // Wait (4)
  { name: 'wait_for_selector', desc: 'Chờ selector xuất hiện/biến mất.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, state: { type: 'string', enum: ['attached', 'detached', 'visible', 'hidden'], default: 'visible' }, timeout: { type: 'number', default: 30000 } }, required: ['tabId', 'selector'] } },
  { name: 'wait_for_text', desc: 'Chờ text xuất hiện trong body.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, text: { type: 'string' }, timeout: { type: 'number', default: 30000 } }, required: ['tabId', 'text'] } },
  { name: 'wait_for_url', desc: 'Chờ URL match regex pattern.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, urlPattern: { type: 'string' }, timeout: { type: 'number', default: 30000 } }, required: ['tabId', 'urlPattern'] } },
  { name: 'wait_for_timeout', desc: 'Sleep ms (ưu tiên dùng waitForSelector hơn).',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, ms: { type: 'number' } }, required: ['tabId', 'ms'] } },

  // Query/Eval (5)
  { name: 'query_selector', desc: 'Lấy element đầu tiên match selector (tag, text, attributes).',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' } }, required: ['tabId', 'selector'] } },
  { name: 'query_all', desc: 'Lấy nhiều element match selector (limit mặc định 50).',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, limit: { type: 'number', default: 50 } }, required: ['tabId', 'selector'] } },
  { name: 'evaluate', desc: 'Chạy JS arbitrary trong context page. script là body async function, có biến arg. Dùng làm escape hatch.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, script: { type: 'string' }, arg: {} }, required: ['tabId', 'script'] } },
  { name: 'extract_links', desc: 'Lấy tất cả <a href> với text + URL absolute.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, base: { type: 'string' } }, required: ['tabId'] } },
  { name: 'extract_table', desc: 'Trích xuất <table> ra mảng rows.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string', default: 'table' } }, required: ['tabId'] } },

  // Cookies/Storage (4)
  { name: 'get_cookies', desc: 'Lấy cookies của profile (tùy chọn lọc theo URLs).',
    schema: { type: 'object', properties: { profile: { type: 'string', default: 'default' }, urls: { type: 'array', items: { type: 'string' } } } } },
  { name: 'set_cookies', desc: 'Set cookies (mảng object Playwright cookie format).',
    schema: { type: 'object', properties: { profile: { type: 'string', default: 'default' }, cookies: { type: 'array' } }, required: ['cookies'] } },
  { name: 'clear_cookies', desc: 'Xóa toàn bộ cookies của profile (cần re-login sau).',
    schema: { type: 'object', properties: { profile: { type: 'string', default: 'default' } } } },
  { name: 'get_local_storage', desc: 'Lấy localStorage hiện tại.',
    schema: { type: 'object', properties: { tabId: { type: 'string' } }, required: ['tabId'] } },

  // Profile (3)
  { name: 'profile_login', desc: 'Mở browser ở mode UI để user tự login (đóng browser sau khi xong → cookies tự lưu).',
    schema: { type: 'object', properties: { profile: { type: 'string', default: 'default' }, url: { type: 'string' } } } },
  { name: 'profile_list', desc: 'Liệt kê các profile đã có.', schema: { type: 'object', properties: {} } },
  { name: 'profile_delete', desc: 'Xóa profile (không xóa được default).',
    schema: { type: 'object', properties: { profile: { type: 'string' } }, required: ['profile'] } },

  // Domain shortcut (1)
  { name: 'shopee_scrape', desc: 'Shortcut: scrape product Shopee qua API pdp/get_pc + persistent profile.',
    schema: { type: 'object', properties: { url: { type: 'string' }, profile: { type: 'string', default: 'default' } }, required: ['url'] } },

  // Network/Download (4)
  { name: 'download_file', desc: 'Tải file qua URL (giữ cookies session) và lưu ra savePath.',
    schema: { type: 'object', properties: { url: { type: 'string' }, savePath: { type: 'string' }, profile: { type: 'string', default: 'default' } }, required: ['url', 'savePath'] } },
  { name: 'intercept_response', desc: 'Lắng nghe response API trong khi navigate. Trả về list response match urlPattern (regex). Hữu ích cho XHR/fetch của SPA.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, urlPattern: { type: 'string' }, navigateTo: { type: 'string' }, timeout: { type: 'number', default: 30000 } }, required: ['tabId', 'urlPattern'] } },
  { name: 'set_request_headers', desc: 'Set extra HTTP headers cho mọi request từ tab (auth token, custom UA...).',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, headers: { type: 'object' } }, required: ['tabId', 'headers'] } },
  { name: 'block_resources', desc: 'Block resource types để tăng tốc scrape (image/font/stylesheet/media/script).',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, types: { type: 'array', items: { type: 'string' } } }, required: ['tabId'] } },

  // Frame (2)
  { name: 'iframe_list', desc: 'Liệt kê tất cả iframe trên page với index, url, name.',
    schema: { type: 'object', properties: { tabId: { type: 'string' } }, required: ['tabId'] } },
  { name: 'iframe_eval', desc: 'Chạy JS trong iframe theo index (lấy từ iframe_list).',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, frameIndex: { type: 'number' }, script: { type: 'string' }, arg: {} }, required: ['tabId', 'frameIndex', 'script'] } },

  // Storage state (2)
  { name: 'set_storage_state', desc: 'Bulk set cookies + localStorage từ JSON object Playwright storageState format.',
    schema: { type: 'object', properties: { profile: { type: 'string', default: 'default' }, state: { type: 'object' } }, required: ['state'] } },
  { name: 'export_storage_state', desc: 'Export profile storage state (cookies + localStorage) ra JSON portable. Tùy chọn savePath.',
    schema: { type: 'object', properties: { profile: { type: 'string', default: 'default' }, savePath: { type: 'string' } } } },

  // Interaction extra (2)
  { name: 'scroll', desc: 'Scroll page hoặc element. direction: up/down/left/right. amount: pixel. smooth: animation mượt.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, selector: { type: 'string' }, direction: { type: 'string', enum: ['up', 'down', 'left', 'right'], default: 'down' }, amount: { type: 'number', default: 800 }, smooth: { type: 'boolean', default: false } }, required: ['tabId'] } },
  { name: 'drag_and_drop', desc: 'Drag element nguồn → element đích.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, sourceSelector: { type: 'string' }, targetSelector: { type: 'string' } }, required: ['tabId', 'sourceSelector', 'targetSelector'] } },

  // Captcha (1)
  { name: 'solve_captcha_2captcha', desc: 'Giải reCAPTCHA v2/v3 qua 2captcha service. Cần env CAPTCHA_API_KEY. Tự inject token vào page sau khi solve.',
    schema: { type: 'object', properties: { tabId: { type: 'string' }, type: { type: 'string', enum: ['recaptcha-v2', 'recaptcha-v3'], default: 'recaptcha-v2' }, siteKey: { type: 'string' }, pageUrl: { type: 'string' } }, required: ['tabId', 'siteKey'] } },

  // Workflow (1)
  { name: 'bulk_scrape', desc: 'Scrape nhiều URL song song với concurrency control. extractor: meta (og tags) | text (innerText) | html.',
    schema: { type: 'object', properties: { urls: { type: 'array', items: { type: 'string' } }, profile: { type: 'string', default: 'default' }, concurrency: { type: 'number', default: 3 }, extractor: { type: 'string', enum: ['meta', 'text', 'html'], default: 'meta' } }, required: ['urls'] } },
];

const handlers = {
  tab_open, tab_close, tab_list,
  navigate, go_back, go_forward, reload,
  get_url, get_title, get_html, get_text, screenshot, pdf,
  click, type_text, fill, select_option, check, hover, press_key, upload_file,
  wait_for_selector, wait_for_text, wait_for_url, wait_for_timeout,
  query_selector, query_all, evaluate, extract_links, extract_table,
  get_cookies, set_cookies, clear_cookies, get_local_storage,
  profile_login, profile_list, profile_delete,
  shopee_scrape,
  // Extra tools
  download_file, intercept_response, set_request_headers, block_resources,
  iframe_list, iframe_eval,
  set_storage_state, export_storage_state,
  scroll, drag_and_drop,
  solve_captcha_2captcha,
  bulk_scrape,
};

// ---------- Server wiring ----------
const server = new Server(
  { name: 'cloakbrowser', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: tools.map(t => ({ name: t.name, description: t.desc, inputSchema: t.schema })),
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  const fn = handlers[name];
  if (!fn) {
    return { isError: true, content: [{ type: 'text', text: `Unknown tool: ${name}` }] };
  }
  try {
    const result = await fn(args ?? {});
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  } catch (err) {
    return { isError: true, content: [{ type: 'text', text: `Error in ${name}: ${err.message}` }] };
  }
});

process.on('SIGINT', async () => { await shutdown(); process.exit(0); });
process.on('SIGTERM', async () => { await shutdown(); process.exit(0); });

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[mcp] cloakbrowser server ready (${tools.length} tools)`);
