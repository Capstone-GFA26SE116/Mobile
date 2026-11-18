# Trợ lý 3D — gõ chữ thay vì nói

Trạng thái: Xong · Branch: `feature/assistant-text-input` · Cập nhật: 2026-11-18

<!-- Hiếu giao 2026-11-18 ("thêm phần text cho con 3D"); Claude Code hiểu là ô gõ câu hỏi. Chỉ Mobile, không đổi AI / Backend. -->

## 0. Mục tiêu
- Màn trợ lý có ô gõ câu hỏi + nút gửi, nằm trên nút mic. Gửi chữ đi đúng đường của câu nói (`AssistantController.ask`
  → `POST /assistant/turn`), nên nhân vật trả lời, đọc to, hiện lựa chọn / gợi ý y như khi nói.
- Dùng khi ở chỗ ồn, không muốn nói to, hoặc máy không có mic / không nhận tiếng Việt.
- **Tiêu chí xong:**
  - [x] AC1 — Gõ rồi bấm nút gửi hoặc phím "send" trên bàn phím → gửi câu đã cắt khoảng trắng, xoá ô, ẩn bàn phím.
  - [x] AC2 — Ô trống / chỉ có khoảng trắng → không gửi được.
  - [x] AC3 — Tắt khi nhân vật chưa tải xong hoặc đang giữ mic.
  - [x] AC4 — Tối đa 500 ký tự (giới hạn `text` của FR-22).
  - [x] AC5 — Câu gõ trả lời "Có" / "Không" cho lệnh đang chờ xác nhận (FR-22c) như câu nói, vì cùng đi qua `ask`.
  - [x] AC6 — `flutter test` xanh; `flutter analyze` không có cảnh báo mới.

## 1. Quyết định
| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| 1 | Đặt ở đâu | Một hàng ô chữ + nút gửi, ngay trên nút mic; mic giữ nguyên | Không đổi cách dùng bằng giọng nói |
| 2 | Gửi khi nhân vật đang nói | Dừng giọng rồi gửi, như bấm gợi ý (`_onPromptTapped`) | Giống hành vi hiện có |
| 3 | Ngôn ngữ chữ trên nút | Tiếng Anh ("Type a question…", "Send") | Giống "Hold to speak" trên cùng màn |

## 2. Test
| ID | Tình huống | Kết quả |
|---|---|---|
| T1 | Gõ + bấm gửi | Gửi câu đã cắt khoảng trắng, ô trống |
| T2 | Phím send trên bàn phím | Gửi |
| T3 | Ô trống / khoảng trắng | Nút tắt, không gửi |
| T4 | `enabled = false` | Ô và nút đều tắt |
| T5 | Giới hạn ký tự | `maxLength` = `AssistantController.textMaxChars` |

## 3. Nhật ký thay đổi
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-18 | Xong: `flutter test` 145 xanh (+5), `flutter analyze` phần trợ lý không có lỗi mới. Chưa chạy trên máy thật: máy dev không có emulator Android, chỉ có iPhone của Hiếu | Hiếu giao |
| 2026-11-18 | Chạy trên emulator Pixel 8 (Android 14): ô hiện trên mic; gõ "What should I do today" → gửi, ô xoá, bàn phím ẩn, câu hiện như câu nói, nhân vật trả lời. Câu trả lời là 401 "Phiên đăng nhập hết hạn" vì emulator chưa đăng nhập (đường gọi AI giống hệt khi nói) | Hiếu cho chạy thử |
