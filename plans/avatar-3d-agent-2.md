# Trợ lý 3D — giai đoạn 2: lệnh bằng giọng có xác nhận (W6-07), phía Mobile

Trạng thái: Xong · Branch: `feature/voice-commands` · Cập nhật: 2026-11-12

<!-- Hiếu chốt 2026-11-11: AI chỉ hiểu câu và trả `confirm` + `action`; **Mobile** gọi Backend sau khi user đồng ý.
Phía AI: plans/FR-22c.md (repo AI, PR #28). -->

## 0. Mục tiêu
- **Làm gì:** Lượt `confirm` → nhân vật hỏi lại, hiện nút **Có / Không**; user bấm hoặc nói "có / ok / đồng ý" → app gọi Backend,
  "không / thôi / huỷ" → huỷ; nói câu khác → bỏ lệnh, hỏi như thường. Câu "Có / Không" không gửi lên AI (không tốn lượt).
- **Tiêu chí xong:**
  - [x] AC1 — Bắt đầu / tạm dừng / xong / thêm giờ / duyệt lịch đề xuất chạy đúng API Backend sau "Có".
  - [x] AC2 — "Thêm N phút": hỏi W4-09 (`/schedule/overrun`) trước, đọc tóm tắt ("nên dời 2 việc…") rồi mới hỏi "Áp dụng nhé?".
  - [x] AC3 — Lỗi (409 đang có phiên khác, mất mạng…) → nhân vật nói rõ, không giả là đã làm.
  - [x] AC4 — `flutter analyze` sạch phần trợ lý, `flutter test` xanh.

## 1. Code
- `models/assistant_turn.dart`: `TurnKind.confirm`, `TurnAction` (kiểm id cần có).
- `data/command_repository.dart`: chạy hành động trên Backend; `previewExtend` dùng `OverrunRepository` (FR-16b).
- `logic/assistant_controller.dart`: giữ lệnh chờ, `confirmation()` đọc có / không, nút Có / Không qua `suggestions`.

## 2. Nhật ký thay đổi
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-12 | Xong: `flutter test` assistant 90 xanh (+21). Emulator, Backend + AI thật, tài khoản đã hết lượt AI: "Bắt đầu bấm giờ việc landing page" → hỏi lại → "Có" → Backend tạo phiên; "Tôi đang bấm giờ việc gì" đọc đúng; "Dừng lại" → "Có" → Backend dừng (`Interrupted`). Tạo 1 phiên thật trên task [TEST] của Hiếu | W6-07 |
