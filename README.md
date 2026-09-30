# setup-deepseek-harness

Script bootstrap thiết lập môi trường và cấu hình cho DeepSeek Harness (DSH Desktop / Web profile) trên máy mới, tương tự như setup của `.omp`.

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
   - **cloakbrowser**: Chạy script local `cloakbrowser/mcp-server-full.mjs`

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
