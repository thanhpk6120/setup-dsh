# setup-deepseek-harness

Script bootstrap thiết lập môi trường và cấu hình cho DeepSeek Harness (DSH Desktop / Web profile) trên máy mới, bám sát tài liệu chính thức của từng nhà cung cấp MCP. Default AI Base URL sử dụng `http://localhost:20128/v1`.

## Cấu hình sinh ra (`cordis.patch.yml` & `.credentials.yaml`)

File cấu hình được đặt vào thư mục profile của DSH:
- `%APPDATA%\dsh-desktop\harness\profiles\web\cordis.patch.yml`
- `%APPDATA%\dsh-desktop\harness\.credentials.yaml`
- `%USERPROFILE%\.dsh\AGENTS.md`
- `%USERPROFILE%\.dsh\skills\`

1. **LLM Provider**: Trỏ về 9router với 4 models chính:
   - `claude-fable-5`
   - `claude-haiku-4-5-20251001`
   - `claude-opus-5`
   - `claude-sonnet-5`
2. **Subagent Models**: Cấp quyền đầy đủ cho subagent sử dụng cả 4 models trên.
3. **Danh sách MCP Servers tích hợp**:
   - **gitnexus**: Lệnh cmd trỏ tới bin cài global (`cmd /c <path>\gitnexus mcp`). Yêu cầu Node.js >= 22.18.0.
   - **company-atlassian**: Pinned version qua `uvx --from mcp-atlassian==0.23.1 mcp-atlassian`.
   - **context7**: Lệnh node trỏ file `dist/index.js` cài global của `@upstash/context7-mcp`. Yêu cầu Node.js >= 22.18.0.
   - **glab**: Lệnh `glab mcp serve`.
   - **cloakbrowser**: Quét danh sách ổ đĩa và cho phép chọn vị trí lưu trữ (mặc định D:, C:), tự động kiểm tra và bảo toàn dữ liệu profile cũ nếu thư mục nguồn và mã nguồn đã tồn tại.
   - **memorix** (Tùy chọn / Optional): Cung cấp tính năng Session Memory & MCP server cho DSH (`memorix serve --mode lite`). Mặc định **không cài đặt** để tối ưu hiệu năng và giữ System Prompt sạch sẽ.

---

## Quy tắc an toàn: Không xóa vĩnh viễn (Recycle Bin / Safe-Trash)

Hệ thống tuân thủ nghiêm ngặt quy tắc an toàn dữ liệu:
- **TUYỆT ĐỐI KHÔNG XÓA VĨNH VIỄN:** Mọi thao tác dọn dẹp file tạm, gỡ bỏ gói cũ hoặc xóa tệp tin đều bắt buộc phải chuyển vào Thùng rác (Recycle Bin / Trash) qua API .NET `Microsoft.VisualBasic.FileIO.FileSystem::DeleteDirectory` / `DeleteFile` với tùy chọn `SendToRecycleBin`.
- **KHÔNG CAN THIỆP MÔI TRƯỜNG TOÀN CỤC:** TUYỆT ĐỐI KHÔNG can thiệp vào `$PROFILE`, không sửa file shell (`.bashrc`), không set biến môi trường toàn cục, không ghi đè lệnh hệ thống `global:Remove-Item` để tránh ô nhiễm terminal cá nhân của người dùng. Mọi thao tác dọn dẹp nội bộ gọi trực tiếp hàm `Safe-Trash`.
---

## Cài đặt nhanh (1 dòng lệnh duy nhất)

Mở PowerShell trên máy mới và chạy trực tiếp lệnh duy nhất sau:

```powershell
irm https://raw.githubusercontent.com/thanhpk6120/setup-dsh/main/install.ps1 | iex
```

### Quy trình cài đặt tương tác (Interactive Setup Flow)

Script cài đặt sẽ tự động điều phối toàn bộ quá trình:

1. **Kiểm tra và cài đặt DSH CLI**:
   - Tự động kiểm tra binary/lệnh `dsh` trong biến môi trường `PATH`.
   - Nếu chưa cài đặt, script sẽ nhận diện terminal và hỏi:
     `DSH CLI chưa được cài đặt. Bạn có muốn cài đặt chính gốc ngay bây giờ không? [Y/n]: `
   - Khi xác nhận (nhấn Enter hoặc 'Y'), script tự động thực thi cài đặt chính gốc, đồng thời nạp lại ngay `PATH` cho session hiện tại mà không cần mở lại terminal.

2. **Cấu hình kết nối AI Provider**:
   - Hỏi **AI Base URL** (Mặc định: `http://localhost:20128/v1`): Nhấn Enter để chọn mặc định hoặc nhập URL mới.
   - Hỏi **AI API Key** (Bắt buộc): Bắt buộc nhập khi được hỏi (không có giá trị mặc định, kiểm tra lặp lại nếu để trống).
   - Tự động lưu thông tin vào file `.env` tạm thời tại thư mục làm việc để các bước kế tiếp sử dụng.

3. **Tùy chọn cài đặt Memorix (MCP & Session Memory)**:
   - **Tự động nhận diện (Smart Detection)**: Nếu hệ thống đã có sẵn `memorix` CLI, script sẽ tự động kích hoạt, in thông báo cập nhật và chạy cài đặt/hook mà không cần hỏi lại.
   - **Nếu chưa cài đặt**: Script hỏi người dùng `Bạn có muốn cài đặt Memorix (MCP & Session Memory) không? [y/N]` (mặc định không cài).
   - **Khi tắt (mặc định khi chưa có CLI và nhấn Enter/N)**:
     * Bỏ qua cài đặt package npm của Memorix và bỏ qua đăng ký hook Agent.
     * Không đưa server Memorix vào file cấu hình `cordis.patch.yml`.
     * Không cài đặt các kỹ năng `skills/memorix-*` vào Agent (nếu đã có từ trước thì chuyển vào Thùng rác qua `Safe-Trash`).
     * Giữ tài liệu `AGENTS.md` sạch sẽ, không chứa các chỉ dẫn Memorix để tiết kiệm token System Prompt.
   - **Khi bật (tự động hoặc chọn Y/y)**:
     * Cài đặt package Memorix (`npm i -g memorix`) và đăng ký hook DSH (`memorix setup --agent dsh --global`).
     * Tự động thêm MCP server `mcp-memorix` vào `cordis.patch.yml`.
     * Cài đặt đầy đủ các kỹ năng Memorix vào `skills/` và tự động ghép phần hướng dẫn Memorix vào `AGENTS.md`.
4. **Quản lý ghi đè và hợp nhất cấu hình (Overwrite / Merge / Skip)**:
   - Quét các file cấu hình đích nếu đã tồn tại:
     * Đối với `cordis.patch.yml`: Hỗ trợ xác nhận `[O]verwrite / [M]erge / [S]kip`. Khi chọn **[M]erge**, script sẽ tự động giữ lại các custom MCP servers của người dùng và hợp nhất với cấu hình mới từ template.
     * Đối với `.credentials.yaml`: Hỗ trợ xác nhận `[O]verwrite / [S]kip`.
   - Tự động tạo bản sao lưu `.bak` trước khi thực hiện ghi đè hoặc hợp nhất.
   - Hỗ trợ tham số `-Force` hoặc `-OverwriteAll` để chạy tự động không cần hỏi lại.

---

## Hợp đồng hành vi & Nguyên tắc (Contract Updates)

Bộ script tuân thủ các nguyên tắc cốt lõi:
1. **Evidence loop**: Mọi thao tác cấu hình và tạo file đều có bước xác thực bằng chứng qua test thực tế (`test-bootstrap.ps1`) đạt 100% pass trước khi kết luận hoàn tất.
2. **MCP generic**: Cấu hình file `cordis.patch.yml` theo chuẩn generic mcpServers, tách biệt rõ ràng giữa config và runtime args.
3. **Cloakbrowser + chọn ổ**: Quét danh sách ổ đĩa và cho phép chọn ổ đĩa cài đặt (mặc định D:, C:), bảo toàn mã nguồn và profile cũ nếu đã có.
4. **uv mcp-atlassian & tránh khóa file**: Kiểm tra `mcp-atlassian` v0.23.1 đã tồn tại hay chưa trước khi gọi `uv tool install`, bỏ qua nếu đã đúng phiên bản nhằm ngăn ngừa lỗi Windows File Lock (`os error 5`). Bọc khối gọi `uv` trong `try/catch` an toàn.
5. **Non-interactive / CI guard**: Tự động phát hiện môi trường non-interactive hoặc CI (`-not [Environment]::UserInteractive`), ném lỗi rõ ràng khi thiếu tham số bắt buộc như `AI_API_KEY` để tránh vòng lặp vô tận.
6. **Separated Templates**: Toàn bộ các file mẫu cấu hình (`cordis.patch.yml`, `.credentials.yaml`, `memorix-agents-section.md`, `.env.example`) được tách riêng trong thư mục `templates/`, có cơ chế fallback chuỗi an toàn.
7. **Safe-Trash & Recycle Bin**: 100% các thao tác dọn dẹp và xóa tệp tạm đều sử dụng Recycle Bin, cấm triệt để xóa vĩnh viễn, không sửa `$PROFILE` hay ô nhiễm môi trường người dùng.
---

## Kiểm thử tự động (Evidence Loop)

Chạy bộ test kiểm tra toàn bộ luồng bootstrap:

```powershell
powershell -ExecutionPolicy Bypass -File .\test-bootstrap.ps1
```
