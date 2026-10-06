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
# 1. Chạy đúng file test với coverage
npx vitest run src/components/MyComponent.test.tsx --coverage

# 2. Tự động tìm và chạy test liên quan tới file source vừa sửa
npx vitest related src/components/MyComponent.tsx --run --coverage
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

## 3. Lọc và tính Coverage trên hàm/dòng thay đổi từ `lcov.info`

Vì Vitest và Jest không hỗ trợ sẵn `--changed-lines-coverage`, ta parse `coverage/lcov.info` theo dải dòng đã lấy từ git diff.

### Node.js script tính Statement & Branch coverage cho khoảng dòng cụ thể
```bash
# Cú pháp: node check-coverage.js <file-path> <start-line> <end-line> [lcov-path]
node -e "
const fs = require('fs');
const [targetFile, startLine, endLine, lcovPath] = [
  process.argv[1],
  parseInt(process.argv[2], 10),
  parseInt(process.argv[3], 10),
  process.argv[4] || 'coverage/lcov.info'
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

for (const line of lines) {
  if (line.startsWith('SF:') && line.includes(targetFile)) {
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
    }
  }
}

const linePct = linesTotal ? ((linesHit / linesTotal) * 100).toFixed(2) : '100.00';
const branchPct = branchTotal ? ((branchHit / branchTotal) * 100).toFixed(2) : '100.00';

console.log(\`[Coverage Dòng Sửa] \${targetFile} (Lines \${startLine}-\${endLine})\`);
console.log(\`- Line: \${linePct}% (\${linesHit}/\${linesTotal})\`);
console.log(\`- Branch: \${branchPct}% (\${branchHit}/\${branchTotal})\`);
console.log(Number(linePct) >= 90 && Number(branchPct) >= 90 ? '=> PASS (>= 90%)' : '=> FAIL (< 90%)');
" "src/components/MyComponent.tsx" 15 35
```

---

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

## 5. Nén và lưu trữ Evidence (Bằng chứng từng vòng lặp)

Tạo thư mục `evidence/` và nén artifact để báo cáo sau mỗi lượt chạy:

### Linux / macOS
```bash
mkdir -p evidence
zip -r evidence/react-loop-1.zip coverage/
```

### Windows (PowerShell)
```powershell
if (!(Test-Path -Path "evidence")) { New-Item -ItemType Directory -Path "evidence" }
Compress-Archive -Path coverage -DestinationPath evidence/react-loop-1.zip -Force
```

### Cross-platform (Node.js script không cần cài thêm tool ngoài)
```bash
node -e "
const fs = require('fs');
const { execSync } = require('child_process');
if (!fs.existsSync('evidence')) fs.mkdirSync('evidence');
const isWin = process.platform === 'win32';
const cmd = isWin
  ? 'powershell Compress-Archive -Path coverage -DestinationPath evidence/react-loop-1.zip -Force'
  : 'zip -r evidence/react-loop-1.zip coverage/';
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
