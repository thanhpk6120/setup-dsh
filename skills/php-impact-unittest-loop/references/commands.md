# PHP Impact Unittest Loop - Commands

Tài liệu lệnh chạy được cho skill `php-impact-unittest-loop`. Copy-paste trực tiếp vào terminal tại thư mục gốc dự án.

## 1. Xác định file và hàm đổi (git diff)

```bash
git status --short
git diff --name-only HEAD
git diff -U0 HEAD -- '*.php'
```

Lọc riêng file nguồn, bỏ qua test cũ:

```bash
git diff --name-only HEAD -- 'src/*.php' 'app/*.php'
```

Xem method chứa dòng đổi (ví dụ kiểm tra file `src/Service/OrderService.php`):

```bash
git diff -U0 HEAD -- src/Service/OrderService.php
grep -n "function " src/Service/OrderService.php
```

## 2. Kiểm tra môi trường coverage PHP

```bash
php -v
php -m | grep -Ei "pcov|xdebug"
vendor/bin/phpunit --version
```

Nếu thiếu driver coverage, cài một trong hai:

```bash
pecl install pcov
php -d pcov.enabled=1 -m | grep pcov
```

```bash
php -m | grep xdebug
XDEBUG_MODE=coverage php -v
```

## 3. Chạy PHPUnit chọn lọc theo filter

Chạy 1 class test:

```bash
vendor/bin/phpunit --filter OrderServiceTest
```

Chạy 1 method test cụ thể:

```bash
vendor/bin/phpunit --filter "OrderServiceTest::testCalculateTotalReturnsCorrectValue"
```

Chạy nhiều class trong 1 thư mục:

```bash
vendor/bin/phpunit --filter "OrderServiceTest|PaymentServiceTest"
vendor/bin/phpunit tests/Unit/Service/OrderServiceTest.php
```

## 4. Chạy kèm coverage (clover + html)

Dùng PCOV (nhanh, khuyên dùng local):

```bash
php -d pcov.enabled=1 vendor/bin/phpunit --filter OrderServiceTest --coverage-clover clover.xml --coverage-html coverage/
```

Dùng Xdebug (khi không có PCOV):

```bash
XDEBUG_MODE=coverage vendor/bin/phpunit --filter OrderServiceTest --coverage-clover clover.xml --coverage-html coverage/
```

Chạy full suite khi impact lan rộng (có xác nhận user):

```bash
php -d pcov.enabled=1 vendor/bin/phpunit --coverage-clover clover.xml --coverage-html coverage/
```

## 5. Đọc và lọc clover.xml theo method đổi

Cấu trúc Clover thật do php-code-coverage sinh (nguồn mẫu: https://raw.githubusercontent.com/sebastianbergmann/php-code-coverage/main/tests/_files/Report/Clover/BankAccount-line.xml):
- Thẻ gốc `<coverage>` chứa `<project>` chứa nhiều `<file name="...">` (namespaced thì bọc thêm `<package name="...">`).
- Mỗi `<file>` chứa `<class name="..." namespace="...">`, các `<line num type name count>` và một `<metrics>` con trực tiếp ở cuối file.
- Không có thẻ `<method>` riêng: method là `<line type="method" name="TenMethod" count="...">` (count lớn hơn 0 là đã cover). Statement là `<line type="stmt" count="...">`.
- Tỉ lệ file nằm ở `<metrics statements coveredstatements methods coveredmethods>` là thẻ con trực tiếp của `<file>`.
- PCOV chỉ cho line coverage; muốn branch/path coverage phải dùng Xdebug.

Xem tổng quan metrics:

```bash
grep -o '<metrics[^>]*>' clover.xml | head -n 5
```

Lọc metrics của 1 file cụ thể (dùng thẻ con trực tiếp `/metrics` để tránh trùng metrics cấp `<class>`):

```bash
grep -A2 'name=".*OrderService.php"' clover.xml
php -r '$x = simplexml_load_file("clover.xml"); foreach ($x->xpath("//file[contains(@name,\"OrderService.php\")]/metrics") as $m) { echo $m->asXML(), PHP_EOL; }'
```

Liệt kê dòng chưa cover (count=0) trong file đổi:

```bash
php -r '$x = simplexml_load_file("clover.xml"); foreach ($x->xpath("//file[contains(@name,\"OrderService.php\")]/line[@count=\"0\"]") as $l) { echo $l["num"], ":", $l["type"], PHP_EOL; }'
```

Liệt kê trạng thái cover từng method trong file đổi (method là line type=method):

```bash
php -r '$x = simplexml_load_file("clover.xml"); foreach ($x->xpath("//file[contains(@name,\"OrderService.php\")]/line[@type=\"method\"]") as $l) { $c = (int)$l["count"]; printf("%s count=%d %s\n", $l["name"], $c, $c > 0 ? "COVERED" : "UNCOVERED"); }'
```

Tính phần trăm statements của 1 file (chỉ đọc metrics cấp file):

```bash
php -r '$x = simplexml_load_file("clover.xml"); foreach ($x->xpath("//file[contains(@name,\"OrderService.php\")]/metrics") as $m) { $s=(int)$m["statements"]; $c=(int)$m["coveredstatements"]; printf("statements=%d covered=%d pct=%.1f%%\n", $s, $c, $s ? $c*100/$s : 100); }'
```

Tính phần trăm statements của 1 method cụ thể (đếm các line type=stmt từ method đó đến method kế tiếp, ví dụ method calculateTotal):

```bash
php -r '$f = "OrderService.php"; $target = "calculateTotal"; $x = simplexml_load_file("clover.xml"); foreach ($x->xpath("//file[contains(@name,\"" . $f . "\")]") as $file) { $in = false; $s = 0; $c = 0; $miss = []; foreach ($file->line as $l) { if ((string)$l["type"] === "method") { if ($in) { break; } if ((string)$l["name"] === $target) { $in = true; } } elseif ($in && (string)$l["type"] === "stmt") { $s++; if ((int)$l["count"] > 0) { $c++; } else { $miss[] = (int)$l["num"]; } } } printf("method=%s statements=%d covered=%d pct=%.1f%%\n", $target, $s, $c, $s ? $c*100/$s : 100); if ($miss) { echo "uncovered lines: " . implode(",", $miss) . PHP_EOL; } }'
```

## 6. Mở báo cáo HTML để tương tác

```bash
ls coverage/index.html
```

Mở trên Windows (PowerShell):

```powershell
start coverage/index.html
```

Mở trên macOS / Linux:

```bash
open coverage/index.html
xdg-open coverage/index.html
```

Serve thư mục coverage để xem qua browser:

```bash
php -S 127.0.0.1:8000 -t coverage/
```

## 7. Nén evidence thành ZIP khi hoàn tất

Chỉ tạo file ZIP một lần duy nhất khi thành công hoặc dừng ở cuối quy trình. Tạo thư mục `evidence` nếu chưa có:

```bash
mkdir -p evidence
zip -r evidence/php-final-coverage.zip clover.xml coverage/
```

Windows PowerShell (nếu không có lệnh zip):

```powershell
New-Item -ItemType Directory -Force -Path evidence
Compress-Archive -Path clover.xml,coverage -DestinationPath evidence/php-final-coverage.zip -Force
```

Kiểm tra file ZIP vừa tạo:

```bash
ls -lh evidence/php-final-coverage.zip
unzip -l evidence/php-final-coverage.zip | head -n 20
```
