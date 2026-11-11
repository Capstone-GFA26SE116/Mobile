# W6-02 — Thẻ "AI Focus Today" trên tab Today (Mobile)

Trạng thái: Xong · Branch: `feature/today-briefing` · Cập nhật: 2026-11-11

<!-- Hiếu chốt 2026-11-11: Claude Code soạn plan rồi làm liền. Sheet W6-02 "Hôm nay trên Mobile: như W4-01, gọi thẳng
AI service". Tab Today đã có lịch hôm nay (Backend) nhưng chưa có phần AI của W4-01. -->

## 0. Mục tiêu
- **Làm gì:** Thêm thẻ "AI Focus Today" vào tab Today, đọc `GET /briefing/today?language=en` (FR-12, không tốn lượt AI):
  tối đa 3 việc nên làm trước + lý do + cảnh báo từ việc tương tự, deadline nguy hiểm, gợi ý giờ hiệu quả,
  có lịch đề xuất đang chờ duyệt.
- **Tiêu chí xong:**
  - [x] AC1 — Hiện đúng dữ liệu: tên việc, dự án, hạn, thời gian còn lại, lý do (tối đa 2), cảnh báo việc tương tự.
  - [x] AC2 — Deadline nguy hiểm: tên, hạn, thiếu bao nhiêu phút.
  - [x] AC3 — Không có việc → câu mời thêm việc; lỗi → câu báo + kéo để thử lại; không dữ liệu giả.
  - [x] AC4 — Kéo làm mới tab Today thì thẻ tải lại.
  - [x] AC5 — `flutter analyze` sạch, `flutter test` xanh; phần cũ của tab Today không đổi.
- **Ngoài phạm vi:** bấm vào việc để mở task / bắt đầu bấm giờ (W6-03, W6-07).

## 1. Code
- `features/dashboard/models/today_briefing.dart` — model đủ trường (khác `Briefing` gọn của trợ lý).
- `features/dashboard/data/briefing_repository.dart` — gọi AI service (Dio truyền vào để test), lỗi → `BriefingException`.
- `features/dashboard/widgets/today_briefing_card.dart` — thẻ tự tải; `refreshKey` đổi thì tải lại.
- `dashboard_screen.dart` — đặt thẻ sau dải ngày trong tuần; `_loadAllData` tăng `refreshKey`.

## 2. Test
| ID | Loại | Tình huống | Mong đợi | AC |
|---|---|---|---|---|
| T1 | unit | parse JSON đầy đủ / thiếu trường | đúng | AC1, AC2 |
| T2 | unit | repository: query `language=en`, lỗi mạng / 500 | đúng | AC3 |
| T3 | widget | thẻ: có việc / không việc / lỗi / tải lại | đúng | AC1–AC4 |

## 3. Nhật ký thay đổi
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-11 | Tạo plan | W6-02 |
| 2026-11-11 | Xong: `flutter test` 86 (+8). Emulator với dữ liệu thật: thẻ hiện việc "[TEST] Làm trang landing page…", dự án, hạn, thời gian còn lại, lý do "Overdue by 20 days". Lần tải đầu chậm (AI + Backend khởi động nguội) | — |
