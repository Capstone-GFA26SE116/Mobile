# Nhân vật 3D — bạn đồng hành khi tập trung + huấn luyện viên ước lượng

Trạng thái: Xong · Branch: `feature/focus-companion-coach` · Cập nhật: 2026-11-12

<!-- Hiếu giao 2026-11-11 (mục 5, sau W6-07); Claude Code tự thiết kế và làm. Chỉ Mobile, không đổi AI / Backend. -->

## 0. Mục tiêu
- **Bạn đồng hành:** màn Focus có nhân vật 3D nhỏ + một câu ngắn ở các mốc: bắt đầu, nửa chặng (kế hoạch ≥ 20 phút),
  còn 5 phút (≥ 15 phút), mỗi 50 phút nhắc nghỉ mắt, hết giờ dự kiến (gợi ý dừng hoặc nhờ trợ lý thêm giờ — W6-07),
  quá 15 / 30 / 60 phút. Mỗi câu một lần; mở màn muộn chỉ nói câu mới nhất. Chỉ chữ, không đọc to.
- **Huấn luyện viên ước lượng:** form tạo task Flexible, dưới ô "Estimated Duration": "In Writing you usually take about 30% longer…
  60 min may really take about 80 min." Lấy từ `GET /analytics/overview?range=all` (FR-20, không gọi LLM, không tốn lượt).
- **Tiêu chí xong:**
  - [x] AC1 — Câu đúng mốc, mỗi câu ≤ 20 từ, không tên nội bộ.
  - [x] AC2 — Nút ẩn / hiện nhân vật; màn thấp hơn 780 px không hiện (tránh đẩy nút Stop ra ngoài).
  - [x] AC3 — Coach chỉ thông tin, **không** đổi số ước lượng (lịch đã tự nhân K; đổi số nữa là tính hai lần). Im lặng khi chưa có dữ liệu,
    lệch < 10 %, hoặc lỗi mạng; đang học thì ghi "(early sign, N tasks)".
  - [x] AC4 — `flutter test` xanh; `flutter analyze` sạch phần mới.

## 1. Quyết định
| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| 1 | Hai WebView avatar | `AvatarView.port`; Focus dùng 8081, trợ lý 8080 | Có thể cùng nằm trong stack |
| 2 | Ngôn ngữ | Tiếng Anh như màn Focus / form | Giống W6-02 |
| 3 | Chạy thật | Xem bằng `lib/dev/focus_companion_preview_main.dart` (phiên giả, 1 giây = 1 phút) | Không ghi FocusSession thật |

## 2. Nhật ký thay đổi
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-12 | Xong: `flutter test` 140 xanh (+20). Emulator Pixel 8: nhân vật tải ở cổng 8081, câu đổi theo mốc | Mục 5 |
