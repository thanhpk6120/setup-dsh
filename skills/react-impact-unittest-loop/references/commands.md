# React Test & Coverage Commands Cheat Sheet

Tổng hợp các lệnh thực thi thực tế trong quy trình Vitest / Jest cho React.

---

## 1. Git Diff xác định dòng & hàm thay đổi

### Danh sách file bị sửa
```bash
git status -s
git diff --name-only HEAD~1 -- "src/**/*.{ts,tsx,js,jsx}"
```

### Lấy khoảng dòng bị sửa (hunks)
```bash
# -U0 loại bỏ dòng ngữ cảnh xung quanh để chỉ lấy chính xác dòng đổi
git diff -U0 HEAD~1 -- "src/components/MyComponent.tsx"
```

### Trích xuất danh sách hàm & khoảng dòng thay đổi bằng Node.js
```bash
node -e "
const { execSync } = require('child_process');
const diff = execSync('git diff -U0 HEAD~1 -- \"src/**/*.{ts,tsx,js,jsx}\"', { encoding: 'utf-8' });
const hunks = [];
let currentFile = '';

for (const line of diff.split('\n')) {
  if (line.startsWith('+++ b/')) {
    currentFile = line.replace('+++ b/', '').trim();
  } else if (line.startsWith('@@')) {
    const match = line.match(/@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/);
    if (match) {
      const start = parseInt(match[1], 10);
      const count = match[2] !== undefined ? parseInt(match[2], 10) : 1;
      hunks.push({ file: currentFile, start, end: start + Math.max(count - 1, 0), header: line });
    }
  }
}
console.table(hunks);
"
```

---

## 2. Chạy test chọn lọc (Selective Testing)

Chỉ chạy test liên quan đến file bị thay đổi, không chạy full suite.

### Vitest (v8 / istanbul)
```bash
# 1. Chạy đúng file test với coverage (cần khai báo reporter lcov/json vì Vitest v8 không tự sinh lcov)
npx vitest run src/components/MyComponent.test.tsx --coverage --coverage.reporter=lcov --coverage.reporter=json

# 2. Tự động tìm và chạy test liên quan tới file source vừa sửa
npx vitest related src/components/MyComponent.tsx --run --coverage --coverage.reporter=lcov --coverage.reporter=json
```

### Jest
```bash
# 1. Chạy file test cụ thể và chỉ gom coverage cho file component đó
npx jest src/components/MyComponent.test.tsx --coverage --collectCoverageFrom="src/components/MyComponent.tsx"

# 2. Tìm test liên quan tới file thay đổi
npx jest --findRelatedTests src/components/MyComponent.tsx --coverage --collectCoverageFrom="src/components/MyComponent.tsx"
```

### Vị trí file coverage mặc định
- HTML: `coverage/index.html` (Vitest) hoặc `coverage/lcov-report/index.html` (Jest)
- LCOV: `coverage/lcov.info`
- JSON: `coverage/coverage-final.json`

---

## 3. Lọc và tính Coverage trên hàm/dòng thay đổi

Vì Vitest và Jest không hỗ trợ sẵn `--changed-lines-coverage`, ta parse `coverage/lcov.info` hoặc `coverage/coverage-final.json` theo dải dòng đã lấy từ git diff.

### Node.js script tính Statement, Branch & Function coverage từ lcov.info
```bash
# Lưu file thành check-coverage.js và chạy: node check-coverage.js <file-path> <start-line> <end-line> [lcov-path]
# Hoặc chạy trực tiếp qua node -e như bên dưới:
node -e "
const fs = require('fs');
const args = process.argv[1] && process.argv[1].endsWith('.js') ? process.argv.slice(2) : process.argv.slice(1);
const [targetFile, startLine, endLine, lcovPath] = [
  args[0],
  parseInt(args[1], 10),
  parseInt(args[2], 10),
  args[3] || 'coverage/lcov.info'
];

if (!fs.existsSync(lcovPath)) {
  console.error('File lcov không tồn tại:', lcovPath);
  process.exit(1);
}

const content = fs.readFileSync(lcovPath, 'utf8');
const lines = content.split('\n');

let inFile = false;
let linesTotal = 0, linesHit = 0;
let branchTotal = 0, branchHit = 0;
let fnMap = {}; // name -> { line, hit }
const normalizePath = (p) => p.replace(/\\\\/g, '/');

for (const line of lines) {
  if (line.startsWith('SF:') && normalizePath(line).includes(normalizePath(targetFile))) {
    inFile = true;
  } else if (line === 'end_of_record') {
    inFile = false;
  } else if (inFile) {
    if (line.startsWith('DA:')) {
      const [lineNum, hitCount] = line.slice(3).split(',').map(Number);
      if (lineNum >= startLine && lineNum <= endLine) {
        linesTotal++;
        if (hitCount > 0) linesHit++;
      }
    } else if (line.startsWith('BRDA:')) {
      const parts = line.slice(5).split(',');
      const lineNum = Number(parts[0]);
      const taken = parts[3];
      if (lineNum >= startLine && lineNum <= endLine) {
        branchTotal++;
        if (taken !== '-' && Number(taken) > 0) branchHit++;
      }
    } else if (line.startsWith('FN:')) {
      const [ln, name] = line.slice(3).split(',');
      fnMap[name] = { line: Number(ln), hit: 0 };
    } else if (line.startsWith('FNDA:')) {
      const [hit, name] = line.slice(5).split(',');
      if (fnMap[name]) fnMap[name].hit = Number(hit);
    }
  }
}

let fnTotal = 0, fnHit = 0;
for (const [name, data] of Object.entries(fnMap)) {
  if (data.line >= startLine && data.line <= endLine) {
    fnTotal++;
    if (data.hit > 0) fnHit++;
  }
}

const linePct = linesTotal ? ((linesHit / linesTotal) * 100).toFixed(2) : '100.00';
const branchPct = branchTotal ? ((branchHit / branchTotal) * 100).toFixed(2) : '100.00';
const fnPct = fnTotal ? ((fnHit / fnTotal) * 100).toFixed(2) : '100.00';

console.log(\`[Coverage Dòng Sửa] \${targetFile} (Lines \${startLine}-\${endLine})\`);
console.log(\`- Line: \${linePct}% (\${linesHit}/\${linesTotal})\`);
console.log(\`- Branch: \${branchPct}% (\${branchHit}/\${branchTotal})\`);
console.log(\`- Function: \${fnPct}% (\${fnHit}/\${fnTotal})\`);
console.log(Number(linePct) >= 90 && Number(branchPct) >= 90 && Number(fnPct) >= 90 ? '=> PASS (>= 90%)' : '=> FAIL (< 90%)');
" "src/components/MyComponent.tsx" 15 35
```

### Node.js script tính từ coverage-final.json (Phương án thay thế)
```bash
node -e "
const fs = require('fs');
const args = process.argv[1] && process.argv[1].endsWith('.js') ? process.argv.slice(2) : process.argv.slice(1);
const [targetFile, startLine, endLine, jsonPath] = [args[0], parseInt(args[1], 10), parseInt(args[2], 10), args[3] || 'coverage/coverage-final.json'];

if (!fs.existsSync(jsonPath)) process.exit(1);
const covData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const normalizePath = (p) => p.replace(/\\\\/g, '/');
const fileKey = Object.keys(covData).find(k => normalizePath(k).includes(normalizePath(targetFile)));
if (!fileKey) { console.log('Không tìm thấy file trong coverage'); process.exit(0); }

const fileCov = covData[fileKey];
let stTotal=0, stHit=0, brTotal=0, brHit=0, fnTotal=0, fnHit=0;

for(const [k, v] of Object.entries(fileCov.statementMap)) {
  if(v.start.line >= startLine && v.start.line <= endLine) {
     stTotal++;
     if(fileCov.s[k] > 0) stHit++;
  }
}

for(const [k, v] of Object.entries(fileCov.branchMap)) {
  if(v.loc.start.line >= startLine && v.loc.start.line <= endLine) {
     fileCov.b[k].forEach(hit => {
       brTotal++;
       if(hit > 0) brHit++;
     });
  }
}

for(const [k, v] of Object.entries(fileCov.fnMap)) {
  if(v.decl.start.line >= startLine && v.decl.start.line <= endLine) {
     fnTotal++;
     if(fileCov.f[k] > 0) fnHit++;
  }
}

const stPct = stTotal ? ((stHit/stTotal)*100).toFixed(2) : '100.00';
const brPct = brTotal ? ((brHit/brTotal)*100).toFixed(2) : '100.00';
const fnPct = fnTotal ? ((fnHit/fnTotal)*100).toFixed(2) : '100.00';

console.log(\`[Coverage JSON] \${targetFile} (Lines \${startLine}-\${endLine})\`);
console.log(\`- Statement: \${stPct}% (\${stHit}/\${stTotal})\`);
console.log(\`- Branch: \${brPct}% (\${brHit}/\${brTotal})\`);
console.log(\`- Function: \${fnPct}% (\${fnHit}/\${fnTotal})\`);
" "src/components/MyComponent.tsx" 15 35
```

## 4. Xem báo cáo HTML (Mở trên trình duyệt)

### Mở trực tiếp file HTML
- **Windows (CMD/PowerShell)**:
  ```cmd
  start coverage/index.html
  ```
- **macOS**:
  ```bash
  open coverage/index.html
  ```
- **Linux**:
  ```bash
  xdg-open coverage/index.html
  ```

### Mở qua Local Server (nếu gặp hạn chế CORS/file URL)
```bash
# Dùng serve
npx serve coverage -p 3000

# Hoặc dùng Vite preview nếu có cấu hình thư mục build tương ứng
npx vite preview --outDir coverage
```

---

## 5. Nén và lưu trữ Evidence (Bằng chứng)

Tạo thư mục `evidence/` và nén artifact để báo cáo một lần duy nhất ở cuối quy trình:

### Linux / macOS
```bash
mkdir -p evidence
zip -r evidence/react-final-coverage.zip coverage/
```

### Windows (PowerShell)
```powershell
if (!(Test-Path -Path "evidence")) { New-Item -ItemType Directory -Path "evidence" }
Compress-Archive -Path coverage -DestinationPath evidence/react-final-coverage.zip -Force
```

### Cross-platform (Node.js script không cần cài thêm tool ngoài)
```bash
node -e "
const fs = require('fs');
const { execSync } = require('child_process');
if (!fs.existsSync('evidence')) fs.mkdirSync('evidence');
const isWin = process.platform === 'win32';
const cmd = isWin
  ? 'powershell Compress-Archive -Path coverage -DestinationPath evidence/react-final-coverage.zip -Force'
  : 'zip -r evidence/react-final-coverage.zip coverage/';
execSync(cmd, { stdio: 'inherit' });
"
```

---

## 6. Patterns Mock chuẩn trong Vitest / Testing Library

### Mock Function & Spy
```tsx
import { vi } from 'vitest';

const onClick = vi.fn();
const fetchSpy = vi.spyOn(api, 'getUser').mockResolvedValue({ id: 1, name: 'Alice' });
```

### Mock Component con (giảm tải logic phụ thuộc)
```tsx
vi.mock('./ComplexChild', () => ({
  default: () => <div data-testid="mock-child">Mocked Child</div>
}));
```

### Mock Browser API (LocalStorage, ResizeObserver)
```tsx
vi.stubGlobal('localStorage', {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
});
```
