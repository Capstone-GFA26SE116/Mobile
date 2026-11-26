# Trợ lý — chèn việc gấp, để mai, xếp lại việc bị lỡ (FR-22d trên Mobile)

Trạng thái: Xong · Branch: `feature/assistant-reshuffle` · Cập nhật: 2026-11-26

<!-- Hiếu 2026-11-26: "hoàn thiện đầy đủ luôn" sau khi kiểm tra thấy app báo lỗi server khi AI (PR #61)
trả 3 action mới. Phía AI: AI repo plans/FR-22d.md. Chỉ Mobile; Backend dùng API có sẵn. -->

## 0. Mục tiêu
- `/assistant/turn` trả `confirm` + `action.type` `insert_block` / `postpone` / `catch_up` kèm `preview` → app hiện **thẻ đề xuất**,
  người dùng đồng ý thì app ghi qua Backend, giữ **Hoàn tác** 5 phút.
- **Tiêu chí xong:**
  - [x] AC1 — Đọc đủ `preview` (dời gì: giờ cũ → mới, trùng gì + vì sao quan trọng, lựa chọn, gợi ý, giờ khác, việc không kịp hạn).
  - [x] AC2 — Thẻ: việc gấp + giờ, dòng "Trùng: … (việc với khách)" màu cam, tối đa 4 việc bị dời, chọn dự án / loại việc khi AI không có.
        Có trùng → nút theo `options` (Giờ khác hh:mm–hh:mm / Ghi đè / Hủy), nút gợi ý tô đậm; không trùng → Đồng ý / Hủy.
  - [x] AC3 — Giờ khác → gọi lại `POST /schedule/insert-block` với giờ đó → thẻ mới. Nói "Có" = làm theo gợi ý.
  - [x] AC4 — Đồng ý → `POST /api/projects/{id}/tasks` (Fixed) → `GET` + `PUT /api/schedule-slots/{id}` từng việc dời (giữ nguyên các trường khác,
        `Missed` → `Approved`) → Ghi đè: `GET` + `PUT /api/tasks/{id}` `Status = Skipped`. Tạo task lỗi → không đổi gì.
  - [x] AC5 — Hoàn tác (nút hoặc nói "Hoàn tác") trong 5 phút: trả giờ + trạng thái cũ của slot (ngược thứ tự), mở lại task bị ghi đè, xóa task vừa tạo.
  - [x] AC6 — Action lạ (AI mới hơn app) → đọc câu trả lời như `answer`, không báo lỗi server.
  - [x] AC7 — `flutter test` xanh; `flutter analyze` không thêm cảnh báo.

## 1. Quyết định
| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| 1 | AI không có dự án mặc định (`project_id` null, 48/49 dự án) | Tải dự án, chọn sẵn dự án tên "Cá nhân"/"Personal", không có thì dự án đầu; người dùng đổi được | Không chặn luồng giọng nói |
| 2 | `PUT` slot / task thay cả bản ghi | Đọc trước rồi gửi lại đủ trường, chỉ đổi giờ / trạng thái | Như FR-16b (`overrun_repository.dart`); Backend `ApplyRequest` ghi đè mọi trường |
| 3 | Thứ tự ghi | Task Fixed trước (lỗi → dừng, chưa đổi gì), rồi slot, rồi ghi đè | Lỗi sớm thì không để lịch nửa vời |
| 4 | Lưu hoàn tác ở đâu | Trong bộ nhớ của màn trợ lý, 5 phút | Backend không cần sửa |
| 5 | Màn hình chật khi có thẻ | Phần trò chuyện cao tối đa 62% màn (40% khi không có thẻ), cuộn được; quả cầu nhỏ lại | Lần chạy emulator đầu: nút bị che |
| 6 | Chạy thật với Azure | Không: token ký bằng khóa ở máy bị Azure từ chối (khóa khác); không chạy Backend ở máy vì job nền chạy trùng trên DB chung | Kiểm bằng unit test (Backend giả) + màn demo với câu trả lời AI thật |

## 2. Code
- `schedule/models/reshuffle_models.dart`, `schedule/data/reshuffle_repository.dart` (AI + Backend + hoàn tác).
- `assistant/models/assistant_turn.dart` (3 loại action + preview; action lạ → answer).
- `assistant/logic/assistant_controller.dart` (`proposal`, `pick`, `selectProject/Domain`, `undoLast`, "Hoàn tác").
- `assistant/widgets/reshuffle_card.dart`, `assistant/screens/assistant_screen.dart`; demo `lib/dev/reshuffle_preview_main.dart`.

## 3. Test
`test/features/assistant/reshuffle_test.dart`: T1 đọc preview · T2 ghi chèn việc gấp (giữ trường slot, ghi đè) · T3 `Missed` → `Approved` + hoàn tác ·
T4 hoàn tác xóa task / mở lại họp; tạo task lỗi → không đổi · T5 thẻ, ghi đè với dự án đã chọn; "Có" = giờ khác · T6 để mai + hoàn tác bằng giọng, hết 5 phút ·
T7 Hủy / "Không" · T8 widget thẻ. `voice_commands_test`: action lạ → answer. Emulator: `docs/reshuffle/*.png`.

## 4. Nhật ký
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-26 | Tạo + làm xong; sửa bố cục sau lần chụp đầu (#5) | |
