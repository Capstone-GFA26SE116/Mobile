# Nhóm (Work Group) trên Mobile

Trạng thái: Xong · Branch: `feature/work-group` · Cập nhật: 2026-11-27

<!-- Hiếu 2026-11-27: "làm nốt màn hình đó" — WF-04 cần màn nhóm, Web/Mobile chưa có (issue #35).
Tú: "Mobile ko có mấy chức năng tạo update phức tạp như trên web" → Mobile chỉ xem + thao tác hằng ngày. -->

## 0. Mục tiêu
- Tab **Groups**: lời mời (Tham gia / Từ chối), **việc nhóm của tôi** đang mở, nhóm của tôi.
- **Nhóm**: tiến độ (% xong, còn lại, chưa giao), danh sách việc (người làm, việc con x/y, hạn), thành viên.
- **Việc nhóm**: chi tiết, việc con; đổi trạng thái; **bấm giờ** (Start / Pause / Done); **Gợi ý giờ** (AI FR-25, người được giao) → chọn → thêm vào lịch;
  **Gợi ý người làm** (AI FR-23, Leader) → chạm người → giao; Backend báo bận (`GROUP_ASSIGNEE_BUSY`) → hỏi lại → giao kèm `confirmConflicts`.
- **Tiêu chí xong:** [x] AC1 tab + 3 màn · [x] AC2 nút theo vai trò (Leader / Member / Viewer, nhóm lưu trữ, việc có giờ cố định) · [x] AC3 lỗi Backend `message` / AI `detail` ·
  [x] AC4 thêm giờ bị chiếm trong lúc chờ (409) thì bỏ qua khung đó · [x] AC5 `flutter test` xanh, analyzer không thêm cảnh báo.

## 1. Quyết định
| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| 1 | Tạo / sửa nhóm, việc, giai đoạn, mời người, chat AI kế hoạch nhóm (FR-24) | Để trên **Web** | Tú chốt Mobile không làm phần tạo / sửa phức tạp |
| 2 | Đặt ở đâu | Tab thứ 5 "Groups" (giữa Projects và Profile); code mới trong `lib/features/groups/` | Ít đụng code của người khác |
| 3 | Tên người trong gợi ý AI | Ghép `user_id` với `GET /api/groups/{id}/members` | AI không trả tên (riêng tư) |
| 4 | Ngôn ngữ | Tiếng Anh như các tab khác; câu lý do của AI tiếng Việt | Đồng bộ app |

## 2. Code
`lib/features/groups/` — `models/group_models.dart`, `data/group_repository.dart`, `screens/groups_screen.dart`, `group_detail_screen.dart`,
`group_task_screen.dart` (+ `SlotSuggestionSheet`, `AssigneeSuggestionSheet`), `widgets/group_widgets.dart`; `home/screens/main_shell_screen.dart` (tab);
demo `lib/dev/groups_preview_main.dart`.

## 3. Test
`test/features/groups/groups_test.dart` (9): đọc "việc của tôi", gợi ý AI; thêm slot bỏ khung 409; giao việc + `confirmConflicts`; lỗi AI `detail`;
tab; Member thấy bấm giờ + gợi ý giờ, không thấy gợi ý người; việc giờ cố định không có gợi ý giờ; Leader chọn người → cảnh báo bận → giao.
Emulator (dữ liệu mẫu, chưa có tài khoản thật): `docs/groups/*.png`.

## 4. Nhật ký
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-27 | Tạo + làm xong | WF-04 cần màn nhóm |
