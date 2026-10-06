# Commands & References

## 1. Chạy Selective Coverage

**Vitest:**
```bash
# Chạy một file test cụ thể kèm coverage
npx vitest run path/to/file.test.tsx --coverage

# Chạy tất cả test liên quan đến file bị thay đổi (dựa trên git)
npx vitest related path/to/source.tsx --coverage
```

**Jest:**
```bash
# Chạy một file test cụ thể kèm coverage
npx jest path/to/file.test.tsx --coverage

# Giới hạn coverage chỉ trên file source đang test để tăng tốc độ
npx jest path/to/file.test.tsx --coverage --collectCoverageFrom="path/to/source.tsx"
```

## 2. Cấu hình package.json / Config tự check (Enforce Coverage)

Cấu hình ngưỡng (thresholds) tối thiểu 90% để cảnh báo hoặc dừng build:

**Vitest (`vitest.config.ts`):**
```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
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

**Jest (`package.json` hoặc `jest.config.js`):**
```json
{
  "jest": {
    "coverageReporters": ["text", "html", "lcov"],
    "coverageThreshold": {
      "global": {
        "branches": 90,
        "functions": 90,
        "lines": 90,
        "statements": 90
      }
    }
  }
}
```

## 3. Mock & Tương tác

### Mock API (Vitest / Jest)
```typescript
import { vi } from 'vitest'; // Jest: dùng jest.spyOn
import * as api from './api';

// Happy path
vi.spyOn(api, 'fetchUserData').mockResolvedValue({ id: 1, name: 'Alice' });

// Error branch
vi.spyOn(api, 'fetchUserData').mockRejectedValue(new Error('Network error'));
```

### Mock Child Component
Giúp cô lập component cần test, giảm chi phí render.
```tsx
import { vi } from 'vitest';

vi.mock('./ChildComponent', () => ({
  default: () => <div data-testid="mocked-child">Mocked Child</div>
}));
```

### Mock Click & Event
Sử dụng `@testing-library/user-event` để mô phỏng sự kiện chân thực nhất.
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

## 4. Anti-patterns

- **Test chi tiết cài đặt (Implementation Details):** Query trực tiếp state, CSS class nội bộ (`.active`), hoặc private methods thay vì test hành vi người dùng (User-visible behavior: Text, Role, Label).
- **Chạy toàn bộ coverage khi đang dev:** Chạy `npm test -- --coverage` trên toàn bộ dự án làm chậm vòng lặp phản hồi. Luôn chạy selective cho file liên quan.
- **Bỏ qua `await` khi dùng `userEvent` hoặc `waitFor`:** Dẫn đến test chạy không đồng bộ thất thường (flaky) hoặc sinh cảnh báo `act(...)`.
- **Lạm dụng Mocking:** Mock cả các helper thuần túy hoặc logic nội bộ của component làm sai lệch kết quả thực tế. Chỉ mock external dependencies, I/O hoặc network.
- **Bỏ quên kiểm tra nhánh Error và Null:** Chỉ test Happy Path khiến nhánh xử lý ngoại lệ không được bảo vệ và tỷ lệ Branch Coverage không đạt ngưỡng 90%.
