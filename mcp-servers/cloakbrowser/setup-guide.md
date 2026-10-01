# CloakBrowser MCP Server - Hướng dẫn Setup

## Tổng quan

CloakBrowser là thư viện stealth browser automation dựa trên Playwright, tích hợp anti-detect fingerprint. MCP server này cho phép Claude Code (hoặc bất kỳ MCP client nào) điều khiển browser thông qua 45+ tools: mở tab, navigate, click, fill form, screenshot, scrape data, quản lý cookies/profile...

## Yêu cầu hệ thống

- **Node.js** >= 18
- **Python** >= 3.8 (cloakbrowser cài qua pip, nhưng MCP server chạy bằng Node.js)
- **OS**: Windows 10+, macOS, Linux

## Cài đặt

### Bước 1: Cài CloakBrowser (Python package)

```bash
pip install cloakbrowser
```

Lệnh này cài core library + tải Chromium stealth binary.

### Bước 2: Tạo thư mục project MCP server

```bash
mkdir D:\Project\AI\cloakbrowser
cd D:\Project\AI\cloakbrowser
```

### Bước 3: Tạo `package.json`

```json
{
  "name": "cloakbrowser-mcp",
  "version": "1.0.0",
  "description": "MCP server for CloakBrowser stealth automation",
  "type": "module",
  "main": "mcp-server-full.mjs",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "cloakbrowser": "^0.3.31",
    "playwright-core": "^1.60.0"
  }
}
```

### Bước 4: Install dependencies

```bash
npm install
```

### Bước 5: Copy file MCP server

File `mcp-server-full.mjs` chứa toàn bộ logic server. Đặt tại `D:\Project\AI\cloakbrowser\mcp-server-full.mjs`.

## Đăng ký MCP với Claude Code

### Cách 1: CLI

```bash
claude mcp add cloakbrowser -- node "D:/Project/AI/cloakbrowser/mcp-server-full.mjs"
```

### Cách 2: Thêm vào `settings.json`

Mở file `~/.claude/settings.json` (hoặc `.claude/settings.json` trong project) và thêm:

```json
{
  "mcpServers": {
    "cloakbrowser": {
      "command": "node",
      "args": ["D:/Project/AI/cloakbrowser/mcp-server-full.mjs"]
    }
  }
}
```

## Cấu trúc Profile

- Profile data lưu tại cùng thư mục với file server: `D:\Project\AI\cloakbrowser\`
- Profile mặc định: `chrome-profile/` (tên logic: `default`)
- Profile tùy chỉnh: `chrome-profile-{tên}/` (vd: `chrome-profile-shopee/`)

Profile lưu cookies, localStorage, cache — giữ session login giữa các lần chạy.

## Sử dụng cơ bản

### Mở tab và navigate

```
tool: tab_open
args: { "url": "https://example.com" }
→ trả về { tabId: "t1", profile: "default", url: "...", title: "..." }
```

### Screenshot

```
tool: screenshot
args: { "tabId": "t1", "fullPage": true }
→ trả về base64 PNG

tool: screenshot
args: { "tabId": "t1", "savePath": "D:/output/page.png" }
→ lưu file
```

### Click & Fill form

```
tool: click
args: { "tabId": "t1", "selector": "#login-btn" }

tool: fill
args: { "tabId": "t1", "selector": "input[name='email']", "value": "user@example.com" }

tool: type_text
args: { "tabId": "t1", "selector": "input[name='password']", "text": "mypass", "delay": 50 }
```

### Chờ element

```
tool: wait_for_selector
args: { "tabId": "t1", "selector": ".dashboard", "timeout": 10000 }
```

### Đóng tab

```
tool: tab_close
args: { "tabId": "t1" }
```

## Quản lý Profile & Login

### Login thủ công (mở browser UI)

```
tool: profile_login
args: { "profile": "shopee", "url": "https://shopee.vn" }
```

Browser mở ở chế độ có giao diện (headed). Bạn tự login, sau đó đóng cửa sổ. Cookies tự động lưu vào profile `shopee`.

### Dùng profile đã login

```
tool: tab_open
args: { "url": "https://shopee.vn/user/account", "profile": "shopee" }
```

### Liệt kê profile

```
tool: profile_list
→ { "profiles": ["default", "shopee", "tiki"] }
```

### Xóa profile

```
tool: profile_delete
args: { "profile": "shopee" }
```

## Tools nâng cao

### Scrape song song nhiều URL

```
tool: bulk_scrape
args: {
  "urls": ["https://a.com", "https://b.com", "https://c.com"],
  "concurrency": 3,
  "extractor": "meta"
}
```

Extractor options:
- `meta`: lấy og tags, title, h1
- `text`: lấy innerText (max 5000 chars)
- `html`: lấy full HTML

### Bắt API response (SPA)

```
tool: intercept_response
args: {
  "tabId": "t1",
  "urlPattern": "/api/v4/.*",
  "navigateTo": "https://shopee.vn/product/123"
}
→ trả về list response match pattern
```

### Block resources để tăng tốc

```
tool: block_resources
args: { "tabId": "t1", "types": ["image", "font", "stylesheet", "media"] }
```

### Download file (giữ cookies)

```
tool: download_file
args: {
  "url": "https://example.com/report.pdf",
  "savePath": "D:/downloads/report.pdf",
  "profile": "default"
}
```

### Chạy JS tùy ý trong page

```
tool: evaluate
args: {
  "tabId": "t1",
  "script": "return document.querySelectorAll('.product-card').length;"
}
```

### Scrape Shopee (shortcut)

```
tool: shopee_scrape
args: { "url": "https://shopee.vn/product/123/456", "profile": "shopee" }
→ trả về tên, giá, rating, hình ảnh, mô tả...
```

### Giải CAPTCHA (cần 2captcha API key)

Set env `CAPTCHA_API_KEY` trước khi chạy server, sau đó:

```
tool: solve_captcha_2captcha
args: { "tabId": "t1", "siteKey": "6Le...", "type": "recaptcha-v2" }
```

### Export/Import storage state

```
tool: export_storage_state
args: { "profile": "shopee", "savePath": "D:/backup/shopee-state.json" }

tool: set_storage_state
args: { "profile": "shopee", "state": { "cookies": [...], "origins": [...] } }
```

## Cấu hình Browser Context

Mặc định server khởi tạo browser với:

| Tham số | Giá trị |
|---------|---------|
| headless | true |
| humanize | true (mô phỏng hành vi người) |
| locale | vi-VN |
| timezoneId | Asia/Ho_Chi_Minh |
| viewport | 1366x768 |

Nếu cần thay đổi, sửa hàm `getContext()` trong `mcp-server-full.mjs`.

## Danh sách Tools (45 tools)

| Nhóm | Tools |
|------|-------|
| Tab/Session | `tab_open`, `tab_close`, `tab_list` |
| Navigation | `navigate`, `go_back`, `go_forward`, `reload` |
| Page State | `get_url`, `get_title`, `get_html`, `get_text`, `screenshot`, `pdf` |
| Interaction | `click`, `type_text`, `fill`, `select_option`, `check`, `hover`, `press_key`, `upload_file` |
| Wait | `wait_for_selector`, `wait_for_text`, `wait_for_url`, `wait_for_timeout` |
| Query/Eval | `query_selector`, `query_all`, `evaluate`, `extract_links`, `extract_table` |
| Cookies/Storage | `get_cookies`, `set_cookies`, `clear_cookies`, `get_local_storage` |
| Profile | `profile_login`, `profile_list`, `profile_delete` |
| Network | `download_file`, `intercept_response`, `set_request_headers`, `block_resources` |
| Frame | `iframe_list`, `iframe_eval` |
| Storage State | `set_storage_state`, `export_storage_state` |
| Scroll/Drag | `scroll`, `drag_and_drop` |
| Captcha | `solve_captcha_2captcha` |
| Workflow | `bulk_scrape` |
| Domain | `shopee_scrape` |

## Troubleshooting

### Server không start

```
Error: Cannot find module 'cloakbrowser'
```

→ Chạy `npm install` trong thư mục `D:\Project\AI\cloakbrowser`.

### Browser không mở

→ Kiểm tra `cloakbrowser` đã cài đúng chưa: `pip show cloakbrowser`. Thư viện tự tải Chromium binary khi cài.

### Profile login không lưu cookies

→ Đảm bảo đóng cửa sổ browser sau khi login (không kill process). Context cleanup tự lưu state.

### Timeout khi navigate

→ Tăng `timeout` parameter hoặc dùng `waitUntil: "domcontentloaded"` thay vì `"networkidle"` cho trang nặng.

### Lỗi "Tab X không tồn tại"

→ Tab đã bị đóng hoặc chưa mở. Dùng `tab_list` để kiểm tra tabs đang active.
