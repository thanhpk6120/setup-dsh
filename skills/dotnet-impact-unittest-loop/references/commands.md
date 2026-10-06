# .NET Test & Coverage Commands Cheat Sheet

## 1. Map Git Diff tới Method C# thay đổi

Xem các thay đổi kèm ngữ cảnh tên method C# trong hunk header:
```bash
# Hiển thị diff với ngữ cảnh hàm (function context)
git diff -W src/

# Hiển thị các khối thay đổi không kèm dòng context, hiển thị rõ tên method tại header @@
git diff -U0 HEAD~1 -- "*.cs"
```

Lấy danh sách các file C# vừa sửa:
```bash
git diff --name-only HEAD~1 -- "*.cs"
```

---

## 2. Chạy Test chọn lọc (dotnet test --filter)

Chạy tất cả test trong một Test Class:
```bash
dotnet test --filter "FullyQualifiedName~MyNamespace.Services.OrderServiceTests"
```

Chạy một test method cụ thể:
```bash
dotnet test --filter "FullyQualifiedName=MyNamespace.Services.OrderServiceTests.CreateOrder_ValidInput_ReturnsSuccess"
```

Chạy kết hợp nhiều class hoặc namespace:
```bash
dotnet test --filter "FullyQualifiedName~OrderServiceTests|FullyQualifiedName~PaymentServiceTests"
```

---

## 3. Thu thập Coverage với Coverlet (XPlat Code Coverage)

Chạy test chọn lọc kèm cờ thu thập coverage (mặc định sinh `coverage.cobertura.xml`):
```bash
dotnet test --filter "FullyQualifiedName~OrderServiceTests" --collect "XPlat Code Coverage"
```
File báo cáo được tạo tại: `[ProjectTestDir]/TestResults/{guid}/coverage.cobertura.xml`

Thiết lập Coverlet Threshold (90% Line & Branch):
```bash
dotnet test --collect "XPlat Code Coverage" -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Threshold=90 DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.ThresholdType="line,branch"
```

---

## 4. Lọc coverage.cobertura.xml theo Method

Cấu trúc block method trong file Cobertura do Coverlet sinh:
```xml
<class name="MyNamespace.Services.OrderService" ...>
  <methods>
    <method name="CreateOrderAsync" signature="(...)" line-rate="0.95" branch-rate="0.90">
      <lines>
        <line number="45" hits="3" branch="False"/>
        <line number="48" hits="0" branch="True" condition-coverage="50% (1/2)"/>
      </lines>
    </method>
  </methods>
</class>
```

### Lọc bằng PowerShell (Native trên Windows):
```powershell
$xml = [xml](Get-Content (Get-ChildItem -Recurse -Filter "coverage.cobertura.xml" | Select -First 1).FullName)
$method = $xml.SelectSingleNode("//class[@name='MyNamespace.Services.OrderService']/methods/method[@name='CreateOrderAsync']")
if ($method) {
    [PSCustomObject]@{
        Method = $method.name
        LineRate = "{0:P2}" -f [double]$method.'line-rate'
        BranchRate = "{0:P2}" -f [double]$method.'branch-rate'
    } | Format-Table
} else {
    Write-Host "Method not found"
}
```

### Lọc bằng Python (Cross-platform):
```bash
python -c "import xml.etree.ElementTree as ET, glob; f = glob.glob('**/coverage.cobertura.xml', recursive=True)[0]; root = ET.parse(f).getroot(); m = root.find('.//class[@name=\"MyNamespace.Services.OrderService\"]/methods/method[@name=\"CreateOrderAsync\"]'); print(f'Line: {float(m.attrib[\"line-rate\"])*100:.1f}%, Branch: {float(m.attrib[\"branch-rate\"])*100:.1f}%') if m is not None else print('Method not found')"
```

---

## 5. Tạo HTML Report trực quan (ReportGenerator)

Cài đặt ReportGenerator global tool (nếu chưa có):
```bash
dotnet tool install -g dotnet-reportgenerator-globaltool
```

Sinh HTML report từ file Cobertura:
```bash
reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:"coveragereport" -reporttypes:Html
```

---

## 6. Mở HTML Report và Đóng gói kết quả cuối cùng

### Mở HTML report trong trình duyệt:
```powershell
# Trên Windows / PowerShell
Start-Process "coveragereport\index.html"

# Trên Linux/macOS
xdg-open coveragereport/index.html || open coveragereport/index.html
```

### Nén thư mục report thành file ZIP (Chỉ làm 1 lần vào cuối quy trình):
Tạo thư mục `evidence` nếu chưa có và lưu file nén với tên `dotnet-final-coverage.zip`.

```powershell
# PowerShell
New-Item -ItemType Directory -Force -Path evidence
Compress-Archive -Path "coveragereport\*" -DestinationPath "evidence\dotnet-final-coverage.zip" -Force

# Bash / Linux
mkdir -p evidence
zip -r evidence/dotnet-final-coverage.zip coveragereport/
```

---

## 7. Mẫu xUnit & Moq / NSubstitute chuẩn

### Mẫu Mock với Moq:
```csharp
public class OrderServiceTests
{
    private readonly Mock<IOrderRepository> _repoMock;
    private readonly OrderService _sut; // System Under Test

    public OrderServiceTests()
    {
        _repoMock = new Mock<IOrderRepository>();
        _sut = new OrderService(_repoMock.Object);
    }

    [Fact]
    public async Task CreateOrderAsync_ValidOrder_ReturnsId()
    {
        // Arrange
        var order = new Order { Amount = 100 };
        _repoMock.Setup(r => r.SaveAsync(It.IsAny<Order>())).ReturnsAsync(1);

        // Act
        var result = await _sut.CreateOrderAsync(order);

        // Assert
        Assert.Equal(1, result);
        _repoMock.Verify(r => r.SaveAsync(It.IsAny<Order>()), Times.Once);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-10)]
    public async Task CreateOrderAsync_InvalidAmount_ThrowsArgumentException(decimal amount)
    {
        var order = new Order { Amount = amount };
        await Assert.ThrowsAsync<ArgumentException>(() => _sut.CreateOrderAsync(order));
    }
}
```

### Mẫu Mock với NSubstitute:
```csharp
public class OrderServiceTests
{
    private readonly IOrderRepository _repo = Substitute.For<IOrderRepository>();
    private readonly OrderService _sut;

    public OrderServiceTests()
    {
        _sut = new OrderService(_repo);
    }

    [Fact]
    public async Task CreateOrderAsync_ValidOrder_CallsSave()
    {
        var order = new Order { Amount = 50 };
        _repo.SaveAsync(Arg.Any<Order>()).Returns(Task.FromResult(1));

        var result = await _sut.CreateOrderAsync(order);

        Assert.Equal(1, result);
        await _repo.Received(1).SaveAsync(Arg.Any<Order>());
    }
}
```

---

## 8. Anti-pattern (Nghiêm cấm)

1. Sửa access modifier trong `src` (đổi `private` thành `public` hoặc `internal`) chỉ để phục vụ viết test thay vì kiểm thử qua public contract.
2. Đặt `[Fact(Skip = "...")]` lên các test case đang fail để làm đẹp tỷ lệ pass/coverage.
3. Chạy `dotnet test` toàn bộ solution khi chỉ sửa 1 method trong 1 class. Luôn dùng `--filter` để giữ tốc độ phản hồi dưới 5 giây.
