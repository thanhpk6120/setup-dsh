# Angular Unittest Commands & Configurations

## Commands
Chạy test cho một file cụ thể và sinh báo cáo coverage:
```bash
ng test --include=src/app/path/to/your-file.spec.ts --no-watch --code-coverage
```
- `--include=...`: Chỉ chạy test cho file được chỉ định (hỗ trợ glob pattern).
- `--no-watch`: Chạy xong tự tắt (CI mode), không chạy lại khi đổi file.
- `--code-coverage`: Sinh báo cáo coverage.

## Tính Coverage
Báo cáo sẽ được sinh ra ở thư mục `coverage/`. Mở file `coverage/lcov-report/index.html` bằng trình duyệt để xem chi tiết những dòng/nhánh nào chưa được cover.

## Cấu hình Coverage Thresholds trong angular.json
Để ép buộc dự án phải đạt một ngưỡng coverage nhất định, cập nhật `angular.json`:
```json
"projects": {
  "your-project-name": {
    "architect": {
      "test": {
        "options": {
          "codeCoverage": true,
          "codeCoverageExclude": ["src/environments/**"],
          "karmaConfig": "karma.conf.js"
        }
      }
    }
  }
}
```
Và trong `karma.conf.js`:
```javascript
coverageReporter: {
  dir: require('path').join(__dirname, './coverage/your-project-name'),
  subdir: '.',
  reporters: [
    { type: 'html' },
    { type: 'text-summary' }
  ],
  check: {
    global: {
      statements: 90,
      branches: 90,
      functions: 90,
      lines: 90
    }
  }
}
```

## Mock Service bằng \`jasmine.createSpyObj\`
```typescript
let mockAuthService: jasmine.SpyObj<AuthService>;

beforeEach(() => {
  mockAuthService = jasmine.createSpyObj('AuthService', ['login', 'logout']);
  // Setup default return value if needed
  mockAuthService.login.and.returnValue(of(true));

  TestBed.configureTestingModule({
    providers: [
      { provide: AuthService, useValue: mockAuthService }
    ]
  });
});
```

## Anti-patterns
- Không mock quá mức: Nếu dependency quá đơn giản (như utility function thuần), hãy dùng dependency thật.
- Gọi service thật trong test Component: Gây side-effect, làm test chậm, khó setup kịch bản lỗi. Luôn mock các service.
- Không kiểm tra DOM khi không cần thiết: Trừ khi hành vi UI quan trọng, ưu tiên kiểm tra logic trên class.
- Bỏ qua \`fixture.detectChanges()\`: Dẫn đến state của component chưa được đồng bộ với template.
- Test chạy quá lâu do không destroy/cleanup đúng cách.
