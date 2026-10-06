# Angular Unittest Commands & Configurations

## 1. Xác định vùng ảnh hưởng (Git Diff)

Lấy danh sách file thay đổi gần nhất:
```bash
git diff --name-only HEAD~1
```

Lấy chi tiết thay đổi trên file cụ thể để map phương thức/dòng code bị đổi:
```bash
git diff -U0 HEAD~1 -- src/app/path/to/target.component.ts
```

## 2. Lệnh Chạy Test Chọn Lọc (Selective Test)

Chạy test một file `.spec.ts` cụ thể ở chế độ headless và sinh coverage:
```bash
ng test --include="src/app/path/to/target.component.spec.ts" --no-watch --code-coverage --browsers=ChromeHeadless
```

Chạy test cho một thư mục tính năng:
```bash
ng test --include="src/app/features/target/**/*.spec.ts" --no-watch --code-coverage --browsers=ChromeHeadless
```

*Ghi chú các cờ CLI:*
- `--include="path/to/*.spec.ts"`: Giới hạn tập tin test thực thi, tối ưu tốc độ.
- `--no-watch`: Chạy xong tự thoát process, dùng cho automation và CI.
- `--code-coverage`: Kích hoạt bộ thu thập độ phủ qua Karma/Istanbul.
- `--browsers=ChromeHeadless`: Chạy ngầm trong nền không bật cửa sổ trình duyệt.

## 3. Cấu hình Thresholds và Reporters

### Cấu hình `angular.json`
Đảm bảo builder karma kích hoạt code coverage và loại trừ file không cần thiết:
```json
"test": {
  "builder": "@angular-devkit/build-angular:karma",
  "options": {
    "codeCoverage": true,
    "codeCoverageExclude": [
      "src/environments/**",
      "src/main.ts",
      "src/polyfills.ts"
    ]
  }
}
```

### Cấu hình `karma.conf.js`
Định nghĩa đường dẫn thư mục xuất báo cáo mặc định và các định dạng báo cáo:
```javascript
module.exports = function (config) {
  config.set({
    coverageReporter: {
      dir: require('path').join(__dirname, './coverage/<project-name>'),
      subdir: '.',
      reporters: [
        { type: 'html' },
        { type: 'lcovonly' }
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
  });
};
```

## 4. Đọc và Lọc Báo Cáo lcov.info

Đọc các chỉ số coverage (Functions, Lines, Branches) của một file mã nguồn cụ thể từ `lcov.info`:
```bash
node -e "const fs=require('fs');const p=process.argv[2];const b=fs.readFileSync(process.argv[1],'utf8').split('end_of_record').find(x=>x.includes('SF:'+p));if(b){const m=(r)=>b.match(r)?.[1]||'0';const fnf=m(/FNF:(\d+)/),fnh=m(/FNH:(\d+)/);const lf=m(/LF:(\d+)/),lh=m(/LH:(\d+)/);const brf=m(/BRF:(\d+)/),brh=m(/BRH:(\d+)/);console.log('Functions: %s/%s (%s%)',fnh,fnf,fnf>0?((fnh/fnf)*100).toFixed(1):'100');console.log('Lines: %s/%s (%s%)',lh,lf,lf>0?((lh/lf)*100).toFixed(1):'100');console.log('Branches: %s/%s (%s%)',brh,brf,brf>0?((brh/brf)*100).toFixed(1):'100');}else{console.log('File not found in lcov');}" coverage/<project-name>/lcov.info src/app/path/to/target.component.ts
```

Kiểm tra số lần một hàm cụ thể được gọi (FNDA):
```bash
node -e "const fs=require('fs');const b=fs.readFileSync(process.argv[1],'utf8').split('end_of_record').find(x=>x.includes('SF:'+process.argv[2]));if(b){const lines=b.split('\n').filter(l=>l.startsWith('FNDA:')&&l.includes(process.argv[3]));console.log(lines.length?lines.join('\n'):'0 hits');}else{console.log('File not found');}" coverage/<project-name>/lcov.info src/app/path/to/target.component.ts targetMethodName
```

## 5. Mở Báo Cáo HTML Trực Quan

```bash
# Windows
start coverage/<project-name>/index.html

# Linux
xdg-open coverage/<project-name>/index.html

# MacOS
open coverage/<project-name>/index.html
```

## 6. Nén Bằng Chứng (Evidence)

Lưu báo cáo coverage và bằng chứng vòng lặp vào file zip:
```bash
mkdir -p evidence
zip -r evidence/angular-loop-1.zip coverage/
```

## 7. Mẫu Thiết Lập Mock Test Với `jasmine.createSpyObj`

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { TargetComponent } from './target.component';
import { DataService } from './data.service';

describe('TargetComponent', () => {
  let component: TargetComponent;
  let fixture: ComponentFixture<TargetComponent>;
  let mockDataService: jasmine.SpyObj<DataService>;

  beforeEach(async () => {
    mockDataService = jasmine.createSpyObj('DataService', ['getData', 'updateData']);

    await TestBed.configureTestingModule({
      declarations: [TargetComponent],
      providers: [
        { provide: DataService, useValue: mockDataService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(TargetComponent);
    component = fixture.componentInstance;
  });

  it('should handle happy path', () => {
    mockDataService.getData.and.returnValue(of({ id: 1, name: 'Sample' }));
    component.loadData();
    expect(mockDataService.getData).toHaveBeenCalled();
    expect(component.data).toBeDefined();
  });

  it('should handle error branch', () => {
    mockDataService.getData.and.returnValue(throwError(() => new Error('Server Error')));
    component.loadData();
    expect(component.hasError).toBeTrue();
  });
});
```