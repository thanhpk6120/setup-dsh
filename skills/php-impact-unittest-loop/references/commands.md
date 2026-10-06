# PHPUnit Commands and References

## 1. Tìm hàm thay đổi (Mapping `git diff`)

Xem những file nào thay đổi:
```bash
git status
# hoặc
git diff --name-only
```

Lấy danh sách các thay đổi chính xác đến từng dòng mã mà không bị dính context (để map ra function/method PHP tương ứng bị đổi):
```bash
git diff -U0
```

## 2. Chạy test và tạo Coverage Report (Chạy Selective)

**Bắt buộc** phải sử dụng biến môi trường kích hoạt coverage (Xdebug hoặc PCOV) và cờ `--filter` để không chạy toàn bộ test suite.

Chạy với **Xdebug**:
```bash
XDEBUG_MODE=coverage vendor/bin/phpunit --filter TênTestClass --coverage-html coverage-report/ --coverage-clover coverage.xml
```

Chạy với **PCOV** (nhanh hơn nếu được hỗ trợ):
```bash
php -d pcov.enabled=1 vendor/bin/phpunit --filter TênTestClass --coverage-html coverage-report/ --coverage-clover coverage.xml
```

*File xuất ra sẽ gồm thư mục `coverage-report/` chứa HTML và file `coverage.xml` chuẩn Clover.*

## 3. Cách đọc và tính Coverage từ coverage.xml

File `coverage.xml` (Clover) chứa số lượng metrics cho toàn project, từng file và từng class.
Ví dụ cấu trúc của một class trong file clover:
```xml
<class name="App\Services\UserService" namespace="App\Services">
    <metrics complexity="5" methods="2" coveredmethods="1" statements="10" coveredstatements="8" elements="12" coveredelements="9"/>
</class>
```
Công thức tính % độ phủ chung (elements): `(coveredelements / elements) * 100`

**Lệnh PHP 1 dòng để tính % coverage của một class cụ thể (vd `App\Services\UserService`):**
```bash
php -r "$xml = simplexml_load_file('coverage.xml'); $c = $xml->xpath('//class[@name=\"App\\\\Services\\\\UserService\"]/metrics'); if($c) { $m = $c[0]; $cov = (int)$m['coveredelements']; $tot = (int)$m['elements']; echo $tot > 0 ? sprintf('%.2f%% elements covered', ($cov/$tot)*100) : 'No elements'; } else { echo 'Class not found'; }"
```
*(Lưu ý: Namespace `\` trong XPath cần được escape thành `\\\\` khi viết oneliner trên Bash).*

## 4. Tương tác và Lưu bằng chứng (Evidence)

Mở báo cáo HTML để xem dòng code nào chưa được phủ (tùy theo OS):
```bash
# Windows
start coverage-report/index.html

# macOS
open coverage-report/index.html

# Linux
xdg-open coverage-report/index.html
```

Nén toàn bộ bằng chứng (evidence) sau mỗi vòng lặp:
```bash
mkdir -p evidence
zip -r evidence/php-loop-1.zip coverage-report/ coverage.xml phpunit_output.log
```

## 5. Pattern Mocking cơ bản

Tạo mock cơ bản với `createMock()`:
```php
$mock = $this->createMock(Dependency::class);
$mock->method('someMethod')->willReturn('value');
```

Dùng `MockBuilder` khi cần giữ nguyên constructor gốc hoặc chỉ mock vài method cụ thể:
```php
$mock = $this->getMockBuilder(Dependency::class)
    ->onlyMethods(['methodToMock'])
    ->disableOriginalConstructor()
    ->getMock();
```

Sử dụng `expects` và `with` để verify hành vi:
```php
$mock->expects($this->once())
     ->method('save')
     ->with($this->equalTo('expected_value'))
     ->willReturn(true);
```

## 6. Anti-patterns (Nghiêm cấm)

1. **Test implementation details**: Assert trực tiếp vào các thuộc tính private/protected. Hãy test bằng output/public APIs.
2. **Over-mocking**: Nếu dependency chỉ là một class dữ liệu (Value Object, DTO) không có I/O hoặc logic phức tạp, hãy dùng object thật thay vì mock.
3. **Che đậy việc thiếu test bằng cách loại trừ (exclude)**: Không bao giờ thêm các file bị ảnh hưởng thay đổi vào thẻ `<exclude>` trong `phpunit.xml` để tăng ảo độ phủ.
4. **Bypass chạy selective**: Chạy toàn bộ test suite dự án khi thay đổi một module nhỏ mà chưa hỏi người dùng.
