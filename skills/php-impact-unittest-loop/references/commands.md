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

Xem tổng quan metrics:

```bash
grep -o '<metrics[^>]*>' clover.xml | head -n 5
```

Lọc metrics của 1 file cụ thể:

```bash
grep -A2 'name=".*OrderService.php"' clover.xml
php -r '$x = simplexml_load_file("clover.xml"); foreach ($x->xpath("//file[@name][contains(@name,\"OrderService.php\")]//metrics") as $m) { echo $m->asXML(), PHP_EOL; }'
```

Liệt kê dòng chưa cover (count=0) trong file đổi:

```bash
php -r '$x = simplexml_load_file("clover.xml"); foreach ($x->xpath("//file[contains(@name,\"OrderService.php\")]//line[@count=\"0\"]") as $l) { echo $l["num"], ":", $l["type"], PHP_EOL; }'
```

Tính phần trăm statements của 1 file:

```bash
php -r '$x = simplexml_load_file("clover.xml"); foreach ($x->xpath("//file[contains(@name,\"OrderService.php\")]//metrics") as $m) { $s=(int)$m["statements"]; $c=(int)$m["coveredstatements"]; printf("statements=%d covered=%d pct=%.1f%%\n", $s, $c, $s ? $c*100/$s : 100); }'
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

## 7. Nén evidence thành ZIP mỗi vòng

Đặt tên file theo vòng lặp (`loop1`, `loop2`):

```bash
zip -r evidence-loop1.zip clover.xml coverage/
```

Windows PowerShell (nếu không có lệnh zip):

```powershell
Compress-Archive -Path clover.xml,coverage -DestinationPath evidence-loop1.zip -Force
```

Kiểm tra file ZIP vừa tạo:

```bash
ls -lh evidence-loop*.zip
unzip -l evidence-loop1.zip | head -n 20
```
