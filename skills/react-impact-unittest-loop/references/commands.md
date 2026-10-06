# React Test & Coverage Commands Cheat Sheet

## 1. Lệnh Git Diff xác định vùng thay đổi

Xem danh sách file bị thay đổi:
```bash
git status -s
git diff --name-only
```

Xem chi tiết dòng code và hàm bị thay đổi (bỏ qua context lines để dễ map sang file báo cáo):
```bash
git diff -U0 HEAD~1
# Hoặc so sánh với branch base
git diff -U0 origin/main...HEAD -- "src/**/*.{ts,tsx,js,jsx}"
```

## 2. Chạy test chọn lọc và thu thập Coverage

### Chạy test theo File cụ thể (Vitest)
```bash
npx vitest run src/components/TargetComponent.test.tsx --coverage
```

### Chạy tất cả test liên quan đến file bị thay đổi (Vitest)
```bash
npx vitest related src/components/TargetComponent.tsx --coverage
```

### Chạy test theo File và giới hạn phạm vi coverage (Jest)
```bash
npx jest src/components/TargetComponent.test.tsx --coverage --collectCoverageFrom="src/components/TargetComponent.tsx"
```

### Chạy toàn bộ test suite (Chỉ dùng khi cần thiết và đã có xác nhận của user)
```bash
# Vitest
npx vitest run --coverage

# Jest
npx jest --coverage
```

Vị trí file kết quả coverage mặc định:
- HTML Report: `coverage/index.html` (Vitest) hoặc `coverage/lcov-report/index.html` (Jest)
- LCOV: `coverage/lcov.info`
- JSON: `coverage/coverage-final.json`

## 3. Xem báo cáo HTML mặc định & Mở HTML

Mở trực tiếp file `index.html` trên trình duyệt:

Trên Windows (PowerShell/CMD):
```cmd
start coverage/index.html
```

Trên macOS:
```bash
open coverage/index.html
```

Trên Linux:
```bash
xdg-open coverage/index.html
```

Hoặc sử dụng serve HTTP cục bộ:
```bash
npx serve coverage
```

## 4. Cách đọc và lọc Coverage từ lcov.info theo Dòng thay đổi

Các công cụ React (Vitest v8/Istanbul, Jest) không tự lọc changed-methods. Sau khi lấy được vùng dòng code thay đổi từ lệnh `git diff -U0` (ví dụ file `Counter.tsx` từ dòng `10` đến `20`), dùng script Node.js dưới đây để đọc file `coverage/lcov.info` và trích xuất trực tiếp tỷ lệ Line & Branch coverage cho các dòng đó.

### Script Node.js trích xuất Line & Branch Coverage theo Line Range
```bash
node -e "const fs=require('fs');const lines=fs.readFileSync(process.argv[1],'utf8').split('\n');const file=process.argv[2],start=+process.argv[3],end=+process.argv[4];let inTarget=false,lt=0,lc=0,bt=0,bc=0;for(const l of lines){if(l.startsWith('SF:')&&l.includes(file))inTarget=true;else if(l==='end_of_record')inTarget=false;else if(inTarget&&l.startsWith('DA:')){const [ln,h]=l.slice(3).split(',').map(Number);if(ln>=start&&ln<=end){lt++;if(h>0)lc++;}}else if(inTarget&&l.startsWith('BRDA:')){const p=l.slice(5).split(',');const ln=Number(p[0]),tk=p[3];if(ln>=start&&ln<=end){bt++;if(tk!=='-'&&Number(tk)>0)bc++;}}}console.log(\`File: \${file} | Lines \${start}-\${end} | Line: \${lt?((lc/lt)*100).toFixed(2)+'%':'N/A'} | Branch: \${bt?((bc/bt)*100).toFixed(2)+'%':'N/A'}\`);" "coverage/lcov.info" "TargetComponent.tsx" 10 20
```

## 5. Lệnh đóng gói Evidence (Bằng chứng từng vòng lặp)

Tạo thư mục evidence nếu chưa có:
```bash
mkdir -p evidence
```

Nén thư mục `coverage/` và test log:
- Trên Linux / macOS:
```bash
zip -r evidence/react-loop-1.zip coverage/ logs/
```
- Trên Windows PowerShell:
```powershell
Compress-Archive -Path coverage, logs -DestinationPath evidence/react-loop-1.zip -Force
```

## 6. 5 Pattern Vitest/Jest & Testing Library tối thiểu

### 1. Mock API / External Modules
```tsx
import { vi } from 'vitest'; // Jest: dùng jest.spyOn
import * as api from './api';

// Happy path
vi.spyOn(api, 'fetchUserData').mockResolvedValue({ id: 1, name: 'Alice' });

// Error branch
vi.spyOn(api, 'fetchUserData').mockRejectedValue(new Error('Network error'));
```

### 2. Mock Child Component
Giúp cô lập component cha, bỏ qua logic bên trong component con.
```tsx
import { vi } from 'vitest';

vi.mock('./ChildComponent', () => ({
  default: () => <div data-testid="mocked-child">Mocked Child</div>
}));
```

### 3. Giả lập tương tác userEvent
```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi } from 'vitest';
import { Counter } from './Counter';

test('click event increments count', async () => {
  const user = userEvent.setup();
  const onClickMock = vi.fn();

  render(<Counter onClick={onClickMock} />);

  const button = screen.getByRole('button', { name: /increment/i });
  await user.click(button);

  expect(onClickMock).toHaveBeenCalledTimes(1);
});
```

### 4. Kiểm tra Exception / Async Error (Error Boundary / Rejects)
```tsx
test('handles api failure gracefully', async () => {
  vi.spyOn(api, 'saveData').mockRejectedValue(new Error('Save failed'));
  const user = userEvent.setup();

  render(<Form />);
  await user.click(screen.getByRole('button', { name: /submit/i }));

  const errorMsg = await screen.findByText(/Save failed/i);
  expect(errorMsg).toBeInTheDocument();
});
```

### 5. Kiểm thử biên với test.each (Parameterized)
```tsx
import { test, expect } from 'vitest';

test.each([
  { age: 17, expected: false },
  { age: 18, expected: true },
  { age: 65, expected: true },
  { age: -1, expected: false }
])('isValidAge($age) returns $expected', ({ age, expected }) => {
  expect(isValidAge(age)).toBe(expected);
});
```

## 7. Cấu hình coverage chuẩn

Cấu hình ngưỡng (thresholds) tối thiểu 90% (ví dụ với `vitest.config.ts`):
```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8', // hoặc 'istanbul'
      reporter: ['text', 'html', 'lcov', 'json'],
      thresholds: {
        lines: 90,
        functions: 90,
        branches: 90,
        statements: 90
      }
    }
  }
});
```

## 8. Anti-pattern (Nghiêm cấm)

1. Sửa source code chính trong project (như bỏ hook khó, đổi cấu trúc component tùy tiện) chỉ để dễ viết test và đẩy nhanh coverage mà không hỏi ý kiến team/user.
2. Hạ thấp ngưỡng coverage yêu cầu (dưới 90%) hoặc cheat test (dùng `expect(true).toBe(true)`) để bypass vòng lặp.
3. Test chi tiết cài đặt (Implementation Details): Query trực tiếp css class nội bộ (`.active`), thay vì test theo vai trò và label của người dùng (`getByRole`, `getByLabelText`).
4. Bỏ quên kiểm tra nhánh Error và Null/Empty: Chỉ test Happy Path khiến nhánh xử lý ngoại lệ không được bảo vệ.
5. Tự ý chạy toàn bộ test suite (full coverage run) làm chậm máy tính mà không hỏi ý kiến khi vùng ảnh hưởng chỉ ở 1-2 file.