# Angular Unittest Commands & Configurations

## 1. Lệnh Git Diff (Xác định ảnh hưởng)

Xem danh sách các file thay đổi gần nhất:
```bash
git diff --name-only HEAD~1
```

Xem chi tiết các thay đổi (dòng nào, hàm nào) trong một file cụ thể:
```bash
git diff -U0 HEAD~1 -- src/app/target.component.ts
```

## 2. Commands Chạy Test

Chạy test chọn lọc (selective run) cho một file cụ thể và sinh báo cáo coverage:
```bash
ng test --include="src/app/path/to/target.spec.ts" --no-watch --code-coverage
```

Chạy test cho nhiều file hoặc thư mục bằng glob pattern:
```bash
ng test --include="src/app/feature/**/*.spec.ts" --no-watch --code-coverage
```

- `--include="..."`: Chỉ chạy test cho file được chỉ định, giúp tăng tốc (không chạy cả project).
- `--no-watch`: Chạy xong tự tắt (CI mode), không giữ process sống để chờ thay đổi.
- `--code-coverage`: Bật tính năng sinh báo cáo coverage qua Karma/Istanbul.

## 3. Tính Coverage và Đọc lcov.info

Báo cáo coverage sinh ra mặc định tại `coverage/<project-name>/`.

**Lệnh mở báo cáo HTML trực quan:**
Windows:
```bash
start coverage/project-name/index.html
```
MacOS:
```bash
open coverage/project-name/index.html
```
Linux:
```bash
xdg-open coverage/project-name/index.html
```

**Đọc tỷ lệ tổng quát của một file từ lcov.info (Node.js one-liner):**
*Thay thế `coverage/project-name/lcov.info` và `src/app/target.component.ts` bằng file thực tế của bạn.*
```bash
node -e "const fs=require('fs');const p=process.argv[2];const b=fs.readFileSync(process.argv[1],'utf8').split('end_of_record').find(x=>x.includes('SF:'+p));if(b){const fnf=b.match(/FNF:(\d+)/)?.[1]||0;const fnh=b.match(/FNH:(\d+)/)?.[1]||0;const lf=b.match(/LF:(\d+)/)?.[1]||0;const lh=b.match(/LH:(\d+)/)?.[1]||0;const brf=b.match(/BRF:(\d+)/)?.[1]||0;const brh=b.match(/BRH:(\d+)/)?.[1]||0;console.log('Functions: %s/%s',fnh,fnf);console.log('Lines: %s/%s',lh,lf);console.log('Branches: %s/%s',brh,brf);}else{console.log('File not found in coverage');}" coverage/project-name/lcov.info src/app/target.component.ts
```

**Kiểm tra xem một hàm cụ thể có được chạy qua chưa (FNDA > 0):**
*Tham số thứ 3 là tên hàm (ví dụ: `ngOnInit` hoặc `calculateTotal`).*
```bash
node -e "const fs=require('fs');const b=fs.readFileSync(process.argv[1],'utf8').split('end_of_record').find(x=>x.includes('SF:'+process.argv[2]));if(b){console.log('Executions:');console.log(b.split('\n').filter(l=>l.startsWith('FNDA:')&&l.includes(process.argv[3])).join('\n')||'0 hits');}else{console.log('File not found');}" coverage/project-name/lcov.info src/app/target.component.ts targetMethodName
```

## 4. Lưu trữ bằng chứng (Evidence)

Nén thư mục coverage (và file log nếu có) để lưu lại bằng chứng của một vòng lặp:
*(Ví dụ cho vòng lặp số 1)*
```bash
mkdir -p evidence
zip -r evidence/angular-loop-1.zip coverage/
```

## 5. Cấu hình Coverage Thresholds trong angular.json

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

## 6. Mock Service bằng `jasmine.createSpyObj`

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

## 7. Anti-patterns

- Không mock quá mức: Nếu dependency quá đơn giản (như utility function thuần), hãy dùng dependency thật.
- Gọi service thật trong test Component: Gây side-effect, làm test chậm, khó setup kịch bản lỗi. Luôn mock các service.
- Không kiểm tra DOM khi không cần thiết: Trừ khi hành vi UI quan trọng, ưu tiên kiểm tra logic trên class.
- Bỏ qua `fixture.detectChanges()`: Dẫn đến state của component chưa được đồng bộ với template.
- Test chạy quá lâu do không destroy/cleanup đúng cách.
