# .NET Test & Coverage Commands Cheat Sheet

## 1. Lệnh Git Diff xác định vùng thay đổi

Xem danh sách file bị thay đổi:
```bash
git status -s
git diff --name-only
```

Xem chi tiết dòng code và hàm bị thay đổi:
```bash
git diff -U0 HEAD~1
# Hoặc so sánh với branch base
git diff -U0 origin/main...HEAD -- "src/**/*.cs"
```

## 2. Chạy test chọn lọc và thu thập Coverage

### Chạy test theo Class cụ thể
```bash
dotnet test --filter "FullyQualifiedName~Namespace.TestClass" --collect:"XPlat Code Coverage"
```

### Chạy test theo Method cụ thể
```bash
dotnet test --filter "FullyQualifiedName=Namespace.TestClass.TestMethodName" --collect:"XPlat Code Coverage"
```

### Chạy toàn bộ test (Chỉ dùng khi cần thiết và đã có xác nhận của user)
```bash
dotnet test --collect:"XPlat Code Coverage"
```

Vị trí file kết quả coverage:
- `TestResults/<guid>/coverage.cobertura.xml`

## 3. Sinh báo cáo HTML mặc định với ReportGenerator & Mở HTML

### Tạo báo cáo HTML và TextSummary
```bash
reportgenerator -reports:"TestResults/**/coverage.cobertura.xml" -targetdir:"coveragereport" -reporttypes:"Html;TextSummary"
```

### Mở file index.html xem trực tiếp
Trên Windows:
```cmd
start coveragereport/index.html
```

Trên macOS:
```bash
open coveragereport/index.html
```

Trên Linux:
```bash
xdg-open coveragereport/index.html
```

## 4. Cách đọc và lọc Coverage từ coverage.cobertura.xml theo Method

Do Coverlet và ReportGenerator không tự lọc changed-methods, sử dụng script dưới đây để trích xuất tỷ lệ Line & Branch coverage của một method cụ thể trong class.

### Script Python trích xuất coverage theo Class và Method
```bash
python3 -c "import xml.etree.ElementTree as ET, glob, sys; files = glob.glob(sys.argv[1], recursive=True); root = ET.parse(files[0]).getroot() if files else None; method = root.find(f'.//class[@name=\"{sys.argv[2]}\"]//method[@name=\"{sys.argv[3]}\"]') if root else None; print(f'Method: {sys.argv[3]} | Line: {float(method.attrib.get(\"line-rate\", 0))*100:.2f}% | Branch: {float(method.attrib.get(\"branch-rate\", 0))*100:.2f}%' if method is not None else 'Method or Class not found')" "TestResults/**/coverage.cobertura.xml" "Namespace.TargetClass" "TargetMethod"
```

### Script PowerShell (dành cho môi trường Windows không có Python)
```powershell
[xml]$xml = Get-Content (Get-ChildItem -Path "TestResults/**/coverage.cobertura.xml" | Select-Object -First 1).FullName; $m = $xml.SelectSingleNode("//class[@name='Namespace.TargetClass']//method[@name='TargetMethod']"); if ($m) { $line = [double]$m.'line-rate' * 100; $branch = [double]$m.'branch-rate' * 100; Write-Host "Method: TargetMethod | Line: $line% | Branch: $branch%" } else { Write-Host "Method or Class not found" }
```

## 5. Lệnh đóng gói Evidence (Bằng chứng từng vòng lặp)

Tạo thư mục evidence nếu chưa có:
```bash
mkdir -p evidence
```

Nén thư mục `TestResults`, `coveragereport`, và file `test.log`:
- Trên Linux / macOS:
```bash
zip -r evidence/dotnet-loop-1.zip TestResults coveragereport test.log
```
- Trên Windows PowerShell:
```powershell
Compress-Archive -Path TestResults, coveragereport, test.log -DestinationPath evidence/dotnet-loop-1.zip -Force
```

## 6. 5 Pattern xUnit & Moq tối thiểu

### 1. Mock dependencies (Service / Repository)
```csharp
public class UserServiceTests
{
    private readonly Mock<IUserRepository> _userRepoMock;
    private readonly UserService _sut;

    public UserServiceTests()
    {
        _userRepoMock = new Mock<IUserRepository>();
        _sut = new UserService(_userRepoMock.Object);
    }
}
```

### 2. Giả lập hành vi (Setup) và xác minh (Verify)
```csharp
[Fact]
public async Task GetUser_ShouldReturnUser_WhenUserExists()
{
    var expectedUser = new User { Id = 1, Name = "Test" };
    _userRepoMock.Setup(r => r.GetByIdAsync(1))
                 .ReturnsAsync(expectedUser);

    var result = await _sut.GetUserAsync(1);

    Assert.NotNull(result);
    Assert.Equal("Test", result.Name);
    _userRepoMock.Verify(r => r.GetByIdAsync(1), Times.Once);
}
```

### 3. Bắt tham số bằng Callback hoặc It.Is
```csharp
[Fact]
public async Task CreateUser_ShouldPassCorrectUserToRepository()
{
    User capturedUser = null;
    _userRepoMock.Setup(r => r.SaveAsync(It.IsAny<User>()))
                 .Callback<User>(u => capturedUser = u)
                 .Returns(Task.CompletedTask);

    await _sut.CreateUserAsync("Alice");

    Assert.NotNull(capturedUser);
    Assert.Equal("Alice", capturedUser.Name);
    _userRepoMock.Verify(r => r.SaveAsync(It.Is<User>(u => u.Name == "Alice")), Times.Once);
}
```

### 4. Kiểm tra Exception (ThrowsAsync / Throws)
```csharp
[Fact]
public async Task GetUser_ShouldThrowKeyNotFoundException_WhenUserNotFound()
{
    _userRepoMock.Setup(r => r.GetByIdAsync(99))
                 .ReturnsAsync((User)null);

    await Assert.ThrowsAsync<KeyNotFoundException>(() => _sut.GetUserAsync(99));
}
```

### 5. Kiểm thử biên với [Theory] và [InlineData]
```csharp
[Theory]
[InlineData(-1, false)]
[InlineData(0, false)]
[InlineData(17, false)]
[InlineData(18, true)]
[InlineData(65, true)]
public void IsValidAge_ShouldReturnExpectedResult(int age, boolean expected)
{
    var result = _sut.IsValidAge(age);
    Assert.Equal(expected, result);
}
```

## 7. Anti-pattern (Nghiêm cấm)

1. Sửa source code chính trong project (như đổi quyền truy cập method từ `private` sang `public`, xóa validation) chỉ để dễ viết test và đẩy nhanh coverage.
2. Hạ thấp ngưỡng coverage yêu cầu (dưới 90%) hoặc cheat test assertions (`Assert.True(true)`) để bypass vòng lặp.
3. Thêm các class có logic thay đổi vào cờ `[ExcludeFromCodeCoverage]` hoặc cấu hình exclude của Coverlet để che giấu việc thiếu test.
4. Mock các cấu trúc dữ liệu thuần túy (DTO, POCO, primitives, collections) thay vì khởi tạo đối tượng trực tiếp.
5. Tự ý chạy toàn bộ test suite mà không hỏi ý kiến người dùng khi chưa có filter cụ thể.
