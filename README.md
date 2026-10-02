# setup-deepseek-harness

Script bootstrap thiết lập môi trường và cấu hình cho DeepSeek Harness (DSH Desktop / Web profile) trên máy mới, tương tự như setup của `.omp`. Default AI Base URL sử dụng `https://openrouter.ai/api/v1`.

## Cấu hình sinh ra (`cordis.patch.yml`)

File cấu hình `cordis.patch.yml` được đặt vào thư mục profile của DSH:
`%APPDATA%\dsh-desktop\harness\profiles\web\cordis.patch.yml`

1. **LLM Provider**: Trỏ về 9router với 4 models chính:
   - `claude-fable-5`
   - `claude-haiku-4-5-20251001`
   - `claude-opus-5`
   - `claude-sonnet-5`
2. **Subagent Models**: Cấp quyền đầy đủ cho subagent sử dụng cả 4 models trên.
3. **Danh sách MCP Servers tích hợp**:
   - **memorix**: Lệnh `memorix serve --mode lite`
   - **gitnexus**: Đường dẫn cmd tuyệt đối trỏ tới bin cài global
   - **company-atlassian**: Pinned version qua `uvx --from mcp-atlassian==0.23.1 mcp-atlassian`
   - **context7**: Lệnh node trỏ file index.js cài global của `@upstash/context7-mcp`
   - **cloakbrowser**: Hỗ trợ quét danh sách ổ đĩa và cho phép chọn vị trí lưu trữ (mặc định D:, C:), tự động kiểm tra và bảo toàn dữ liệu profile cũ nếu thư mục nguồn và mã nguồn đã tồn tại.
  
---

## Hợp đồng hành vi & Nguyên tắc (Contract Updates)

Bộ script tuân thủ 7 hợp đồng nguyên tắc:
1. **Evidence loop**: Không giả định kết quả; mọi thao tác cấu hình và tạo file đều có bước xác thực bằng chứng (evidence) qua test thực tế (`test-bootstrap.ps1`) trước khi kết luận hoàn tất.
2. **MCP generic**: Cấu hình file `cordis.patch.yml` theo chuẩn generic mcpServers, loại bỏ schema cũ 404, tách biệt rõ ràng giữa config và runtime args.
3. **Cloakbrowser + chọn ổ**: Hỗ trợ CloakBrowser MCP với tính năng quét danh sách ổ đĩa và cho phép chọn ổ đĩa cài đặt (mặc định D:, C:), bảo toàn mã nguồn và profile cũ nếu đã có.
4. **uv mcp-atlassian**: Quản lý cài đặt/cập nhật `mcp-atlassian` qua `uv tool install mcp-atlassian==0.23.1 --upgrade`.
5. **Overwrite (Ghi đè an toàn)**: Không ghi đè các file config cá nhân (`cordis.patch.yml`) nếu đã tồn tại; luôn ghi đè (`overwrite`) các file quy tắc (`AGENTS.md`) và thư mục `skills/` (vào `~/.dsh`) để đồng bộ mới nhất.
6. **Reload-context**: Hỗ trợ workflow tải lại ngữ cảnh (`reload-context` / nạp lại rules, skills, agents) ngay sau khi cấu hình/tool cập nhật mà không cần khởi động lại toàn bộ session.
7. **Cleanup skill**: Đồng bộ thư mục `skills/` giúp dọn dẹp các rule và skill lỗi thời hoặc thừa, giữ hệ sinh thái skill tinh gọn và chuẩn xác.

---

## Cài đặt nhanh (1 dòng lệnh duy nhất)

Mở PowerShell trên máy mới và chạy:

```powershell
irm https://raw.githubusercontent.com/thanhpk6120/setup-dsh/main/install.ps1 | iex
```

---

## Chạy thủ công từ repo

## Chạy bootstrap

```powershell
# Chạy cài đặt đầy đủ (yêu cầu Node.js, npm, git)
.\bootstrap.ps1

# Dry-run xem trước thay đổi (không ghi file)
.\bootstrap.ps1 -DryRun

# Bỏ qua bước cài đặt runtime (chỉ tạo file config)
.\bootstrap.ps1 -SkipInstall
```

## Chạy kiểm tra

```powershell
.\test-bootstrap.ps1
```