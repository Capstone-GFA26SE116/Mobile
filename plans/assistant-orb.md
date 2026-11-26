# Trợ lý — quả cầu thay nhân vật 3D

Trạng thái: Xong · Branch: `feature/assistant-orb` · Cập nhật: 2026-11-26

<!-- Hiếu chọn 2026-11-26 ("mình chọn quả cầu nha, bạn triển khai đi") sau khi xem trang mô phỏng
https://claude.ai/artifact/VgvQquzAuRWkgpnh7yGN3e (A quả cầu / B linh vật 2D / C chữ là chính).
Lý do đổi: nhân vật VRM "hơi kì", WebView + mô hình 47 MB nặng, emulator Android không vẽ được morph. Chỉ Mobile, AI / Backend không đổi. -->

## 0. Mục tiêu
- Màn trợ lý và bạn đồng hành ở màn Focus dùng **quả cầu vẽ bằng Flutter** (`CustomPainter`) thay nhân vật VRM trong WebView.
- **Tiêu chí xong:**
  - [x] AC1 — Quả cầu có 4 kiểu chuyển động: chờ (thở chậm), nghe (2 vòng sóng lan ra), nghĩ (vòng cung xoay), nói (nhịp như giọng nói).
  - [x] AC2 — Màu theo `emotion` của `/assistant/turn`: neutral xanh thương hiệu `#00D992`, happy xanh sáng + nảy 1 lần, thinking xanh ngọc, sad xám xanh + nhỏ lại.
  - [x] AC3 — Giữ nguyên API cho các màn: `AvatarController.setSpeaking / setEmotion` (+ mới `setListening / setThinking`), `AvatarView(controller, onReady)`; `onReady` gọi sau khung hình đầu (không còn chờ tải mô hình).
  - [x] AC4 — Tắt hiệu ứng chuyển động của máy (`disableAnimations`) → quả cầu đứng yên.
  - [x] AC5 — Gỡ `flutter_inappwebview` và `assets/avatar/` (47 MB).
  - [x] AC6 — `flutter test` xanh; `flutter analyze` không có cảnh báo mới; chạy trên Android emulator, chụp ảnh từng trạng thái.

## 1. Quyết định
| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| 1 | Đổi tên lớp `Avatar…` | Giữ tên (`avatar_view.dart`, `AvatarController`, `AvatarView`, `AvatarEmotion`) | ~20 test + 2 màn dùng; "avatar" = gương mặt trợ lý |
| 2 | Nhiều trạng thái cùng lúc | Ưu tiên: nghe > nghĩ > nói > chờ; màu lấy từ `emotion` | Nghe / nghĩ do app biết (`AssistantPhase`), cảm xúc do AI trả |
| 3 | Vẽ bằng gì | `CustomPainter` + một `Ticker`, `RepaintBoundary` | Không cần gói mới, không file ảnh |
| 4 | Port của WebView (8080 / 8081) | Bỏ | Không còn máy chủ asset cục bộ |

## 2. Code
- `lib/features/assistant/widgets/avatar_view.dart`: `AvatarController` (ChangeNotifier), `orbMode`, `orbColors`, `orbScale`, `OrbPainter`, `AvatarView`.
- `assistant_screen.dart`: báo `setListening` / `setThinking` theo `AssistantPhase`; `devTour` thêm nghe + nghĩ; dispose controller.
- `focus_companion_view.dart`: bỏ port, dispose controller.

## 3. Test
| ID | Tình huống | Kết quả |
|---|---|---|
| T1 | Controller chỉ báo khi đổi thật; happy đếm "nảy" 1 lần mỗi lần đổi | đúng |
| T2 | Thứ tự ưu tiên trạng thái | nghe > nghĩ > nói > chờ |
| T3 | `orbScale` mọi trạng thái × cảm xúc trong [0,88; 1,08]; nói dao động hơn chờ; buồn nhỏ hơn | đúng |
| T4 | Widget: `onReady` sau khung đầu, nhãn trợ năng theo trạng thái | đúng |
| T5 | `disableAnimations` → không chạy đồng hồ | đúng |
| T6 | Màn Focus chạy quả cầu thật trong test | đúng |
| T7 | Emulator Pixel 8 (`DEV_AVATAR_TOUR=true`) | ảnh `docs/orb/*.png` |

## 4. Nhật ký
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-26 | Tạo + làm xong. Lần chụp đầu thấy mép gắt ở chỗ sáng → thêm điểm màu; tâm hơi hồng do trắng trong suốt → đổi màu đặc. `listening-sad.png` chụp khi demo còn màu buồn (demo nay trả về neutral trước khi nghe) | Tự xem ảnh |
