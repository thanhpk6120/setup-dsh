# Jacoco & Test Commands Cheat Sheet

## 1. Chạy test và tạo Jacoco Report (Chỉ định Class)

### Maven
Chạy test cho các class cụ thể và xuất report:
```bash
mvn -Dtest=com.example.ClassATest,com.example.ClassBTest -Dsurefire.failIfNoSpecifiedTests=false test jacoco:report
```

Chạy toàn bộ test và xuất report:
```bash
mvn clean test jacoco:report
```

Vị trí file report:
- `target/site/jacoco/jacoco.xml`
- `target/site/jacoco/index.html`

### Gradle
Chạy test cho các class cụ thể và xuất report:
```bash
./gradlew test --tests "com.example.ClassATest" --tests "com.example.ClassBTest" jacocoTestReport
```

Vị trí file report:
- `build/reports/jacoco/test/jacocoTestReport.xml`
- `build/reports/jacoco/test/html/index.html`

## 2. Cách đọc và tính Coverage từ jacoco.xml

Cấu trúc block counter trong file `jacoco.xml`:
```xml
<counter type="INSTRUCTION" missed="15" covered="85"/>
<counter type="BRANCH" missed="5" covered="45"/>
<counter type="LINE" missed="4" covered="36"/>
```
Công thức tính %: `(covered / (covered + missed)) * 100`

Script Python 1 dòng để tính % LINE coverage của một class (ví dụ `com/example/TargetClass`):
```bash
python -c "import xml.etree.ElementTree as ET, sys; root = ET.parse(sys.argv[1]).getroot(); n = root.find('.//class[@name=\"com/example/TargetClass\"]'); c = n.find('counter[@type=\"LINE\"]') if n is not None else None; print(f'{int(c.attrib[\"covered\"]) / (int(c.attrib[\"covered\"]) + int(c.attrib[\"missed\"])) * 100:.2f}%' if c is not None else 'Class not found')" target/site/jacoco/jacoco.xml
```

## 3. Ngưỡng check tự động (jacoco-check)

Cấu hình rule trong `pom.xml` (Maven) để check coverage trên class bị ảnh hưởng (không áp dụng toàn project):
```xml
<execution>
    <id>jacoco-check</id>
    <goals>
        <goal>check</goal>
    </goals>
    <configuration>
        <includes>
            <include>com/example/TargetClass.class</include>
        </includes>
        <rules>
            <rule>
                <element>CLASS</element>
                <limits>
                    <limit>
                        <counter>INSTRUCTION</counter>
                        <value>COVEREDRATIO</value>
                        <minimum>0.90</minimum>
                    </limit>
                    <limit>
                        <counter>BRANCH</counter>
                        <value>COVEREDRATIO</value>
                        <minimum>0.90</minimum>
                    </limit>
                </limits>
            </rule>
        </rules>
    </configuration>
</execution>
```

## 4. 5 Pattern Mockito & JUnit5 tối thiểu

Mock dependencies (Service/Repository):
```java
@ExtendWith(MockitoExtension.class)
class TargetClassTest {
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;
}
```

Giả lập hành vi (when) và xác minh (verify):
```java
@Test
void testFindUser() {
    when(userRepository.findById(1L)).thenReturn(Optional.of(new User(1L, "Test")));
    
    userService.getUser(1L);
    
    verify(userRepository, times(1)).findById(1L);
}
```

Bắt tham số bằng ArgumentCaptor:
```java
@Test
void testSaveUser() {
    ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
    
    userService.createUser("NewUser");
    
    verify(userRepository).save(captor.capture());
    assertEquals("NewUser", captor.getValue().getName());
}
```

Kiểm tra Exception (assertThrows):
```java
@Test
void testUserNotFound() {
    when(userRepository.findById(99L)).thenReturn(Optional.empty());
    
    assertThrows(UserNotFoundException.class, () -> {
        userService.getUser(99L);
    });
}
```

Kiểm thử biên với @ParameterizedTest:
```java
@ParameterizedTest
@CsvSource({"0, false", "-1, false", "18, true"})
void testAgeValidation(int age, boolean expected) {
    assertEquals(expected, userService.isValidAge(age));
}
```

## 5. Anti-pattern (Nghiêm cấm)

1. Sửa source code `src/main` (như xóa logic khó test, thay đổi quyền truy cập biến) chỉ để dễ viết test và tăng coverage.
2. Hạ threshold (từ 0.90 xuống thấp hơn) để bypass CI pipeline thay vì viết thêm test cho các trường hợp thiếu.
3. Thêm các class bị ảnh hưởng hoặc có thay đổi logic vào danh sách `exclude` của plugin Jacoco để che giấu việc thiếu test.

## 6. Nén Bằng Chứng (Evidence)

Thực hiện sau khi kết thúc/thoát vòng lặp:
```bash
mkdir -p evidence
# Với Maven:
zip -r evidence/java-final-coverage.zip target/site/jacoco/
# Với Gradle:
zip -r evidence/java-final-coverage.zip build/reports/jacoco/test/
```