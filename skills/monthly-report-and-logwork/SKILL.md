---
name: monthly-report-and-logwork
description: Rà soát meeting notes Confluence và các task Jira trong tháng để lập báo cáo tháng (monthly report) hoàn chỉnh, bổ sung các ngày thiếu và tự động logwork đủ 8 tiếng/ngày lên Jira.
---

# Skill: Monthly Report & Worklog Automation

> **Mục tiêu:** Tự động hóa quy trình đối soát công việc tháng: Đọc Confluence Meeting Notes + Jira Issues/Changelogs -> Lập bảng `monthly-report-YYYY-MM.md` hoàn chỉnh (kể cả những ngày không ghi note) -> Tự động logwork đủ 8 giờ/ngày (số nguyên dương) lên Jira.

---

## Quy Trình Thực Hiện (Workflow 4 Bước)

### Bước 1: Xác định thông tin cá nhân & Khoảng thời gian
1. Đọc thông tin cá nhân từ `personal.md` (Họ và tên, Username / Key Jira, Email).
2. Xác định tháng và năm cần làm báo cáo (Ví dụ: `YYYY-MM`).
3. Lập danh sách **tất cả các ngày làm việc** trong tháng (từ Thứ Hai đến Thứ Sáu, loại trừ Thứ Bảy, Chủ Nhật và ngày nghỉ lễ chính thức theo luật lao động).

---

### Bước 2: Thu thập dữ liệu từ Confluence & Jira

#### 2.1. Đọc Confluence Meeting Notes
1. Sử dụng tool `confluence_get_page_children` hoặc `confluence_search` với space `CT` và parent page của tháng tương ứng (Cấu trúc: `Meeting Notes` -> `Năm YYYY` -> `Tháng MM`).
2. Với từng ngày có note:
   - Đọc nội dung bảng phân công công việc.
   - Tìm dòng tương ứng với thành viên (theo họ tên hoặc `@mention`).
   - Trích xuất danh sách mã Jira ticket (`issue_key`), mô tả công việc, khó khăn, đề xuất.

#### 2.2. Đối soát Jira Audit & Tìm task cho những ngày thiếu note
1. Dùng `jira_search` với JQL:
   ```jql
   assignee = '<username>' AND ((created >= 'YYYY-MM-01' AND created <= 'YYYY-MM-31 23:59') OR (updated >= 'YYYY-MM-01' AND updated <= 'YYYY-MM-31 23:59'))
   ```
2. Với các ngày **không có trang Meeting Note** trên Confluence:
   - Kiểm tra `changelog` và thời gian `updated`/`created` của từng issue Jira để xác định chính xác task nào bạn đã thao tác/xử lý vào ngày đó.
   - Kiểm tra `project` và `assignee` để đảm bảo 100% đúng dự án và đúng người được giao.

---

### Bước 3: Tạo File Monthly Report (`monthly-report-YYYY-MM.md`)
Tạo hoặc cập nhật file `monthly-report-YYYY-MM.md` với cấu trúc chuẩn:

1. **4 Nhóm công việc trọng tâm (High-Level Summary):**
   - Format: `[Tên Dự Án] Tóm tắt nhóm công việc chính`
2. **Bảng tổng hợp theo từng ngày làm việc (Table):**
   - Cột: `Ngày` | `Thứ` | `Meeting Note` (✅ Có / ❌ Không) | `Mã Task` | `Dự Án` | `Nội Dung Công Việc / Tóm Tắt` | `Trạng Thái`
3. **Bảng tổng hợp danh sách toàn bộ task trong tháng (Table):**
   - Cột: `STT` | `Mã Task` | `Dự Án` | `Tóm Tắt Nhiệm Vụ` | `Trạng Thái Hiện Tại`

---

### Bước 4: Tự Động Logwork Lên Jira (`jira_add_worklog`)

#### Quy tắc logwork:
1. **Đủ thời lượng:** Mỗi ngày làm việc phải được log **chính xác 8 giờ** (tổng tháng = số ngày làm việc * 8h).
2. **Chia thời gian:** Chỉ sử dụng **số nguyên dương** (Ví dụ: `2h`, `4h`, `8h`), không dùng số lẻ hoặc phút (`1h30m`, `3.5h` là không hợp lệ).
   - Nếu ngày có 1 task: Log `8h` cho task đó.
   - Nếu ngày có 2 task: Log `4h` + `4h`.
   - Nếu ngày có 4 task: Log `2h` + `2h` + `2h` + `2h`.
3. **Nội dung (Comment):** Trích xuất **nguyên văn / tóm tắt trung thực** từ `summary`, `description`, hoặc `changelog` của task. **Tuyệt đối không tự bịa đặt nội dung.**
4. **Thời gian bắt đầu (`started`):** Đặt vào đầu giờ sáng ngày làm việc đó (format ISO: `YYYY-MM-DDTHH:mm:ss.000+0700` hoặc tương đương).
