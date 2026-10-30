# Trợ lý 3D — giai đoạn 1: hỏi đáp dữ liệu bằng giọng (Mobile)

Trạng thái: Đã duyệt · Branch: `feature/avatar-3d-agent` (tách từ `feature/avatar-3d` sau khi MVP merge) · Cập nhật: 2026-10-30

<!-- Viết trên Claude web (2026-10-30). Phía server: plans/FR-22.md (repo AI) — giai đoạn 1 CHỈ ĐỌC.
Bắt đầu cụm 2 khi FR-22 đã lên Azure. Claude Code làm theo cụm, dừng ở cuối cụm. -->

## 0. Mục tiêu
- **Làm gì:** Thay luật từ khóa của MVP bằng `POST /assistant/turn` (FR-22) → nhân vật trả lời 10 loại câu hỏi đọc dữ liệu;
  câu ngoài phạm vi → "chưa hỗ trợ" + nút gợi ý câu hỏi.
- **Tiêu chí xong:**
  - [ ] AC1 — Hỏi được 10 loại câu (FR-22 mục 1), nhân vật đọc dữ liệu thật, đúng biểu cảm.
  - [ ] AC2 — `unsupported` / `smalltalk help` → hiện 2–3 nút gợi ý; bấm nút = gửi câu đó (không cần nói).
  - [ ] AC3 — `clarify` → hiện ≤ 3 nút lựa chọn; bấm → gửi lại câu cũ kèm `selected_id`.
  - [ ] AC4 — 429 (hết lượt) / 409 / mất mạng / 502 → câu "hôm nay làm gì" vẫn chạy bằng luật từ khóa MVP (gọi `/briefing/today`); câu khác → báo đúng lỗi. Không dữ liệu giả.
  - [ ] AC5 — `flutter analyze` sạch, `flutter test` xanh; màn cũ không đổi.
- **Ngoài phạm vi:** lệnh ghi + thẻ xác nhận (giai đoạn 2) · nhớ hội thoại qua lần mở màn · đánh thức bằng giọng.

## 1. Bên ngoài
- `POST /assistant/turn` (AI service, JWT như FR-12). Shape `Turn`: `plans/FR-22.md` mục 1 (repo AI).
- Lịch sử gửi lên: 6 lượt gần nhất trong phiên màn hình (mất khi đóng màn).

## 2. Bên trong
- `models/assistant_turn.dart` — `Turn`, `TurnKind`, `TurnOption`, map `emotion` → `AvatarEmotion`.
- `data/assistant_repository.dart` — thêm `turn(text, history, {selectedId})`; lỗi thêm `quotaExceeded` (429), `noPlan` (409).
- `logic/assistant_controller.dart` — trạng thái `idle → listening → thinking → speaking`, lịch sử, options / suggestions;
  quyết định: gọi `turn` → lỗi 429/409/mạng/502 và câu khớp luật MVP → `getTodayBriefing()` + `BriefingSpeech`.
- `screens/assistant_screen.dart` — hàng nút gợi ý / lựa chọn dưới vùng chữ.
- Giữ `intent_router.dart` + `briefing_speech.dart` làm **đường dự phòng**.

## 3. Test
| ID | Loại | Tình huống | Mong đợi | AC |
|---|---|---|---|---|
| T1 | unit | repository adapter giả: 200 mỗi `kind`, 409, 429, 502, timeout | đúng model / lỗi | AC4 |
| T2 | unit | controller với repo giả: answer, unsupported → bấm gợi ý, clarify → chọn, 429 + câu briefing, 429 + câu khác | đúng trạng thái + lời gọi + biểu cảm | AC1–AC4 |
| T3 | widget | nút gợi ý / lựa chọn hiện và bấm được | đúng | AC2, AC3 |
| T4 | tay | 10 câu thật trên Simulator / emulator | đạt | AC1 |

## 4. Các bước
**Cụm 1 — logic (không cần FR-22 chạy thật)**
- [x] **1.** Model + repository `turn` — T1.
- [ ] **2.** `assistant_controller` — T2.
**→ DỪNG: Hiếu đọc `assistant_controller.dart`.**

**Cụm 2 — màn hình + chạy thật (cần FR-22 trên Azure)**
- [ ] **3.** UI nút gợi ý / lựa chọn — T3.
- [ ] **4.** Chạy thật T4; quay video 60 giây (hôm nay làm gì → chiều nay có gì → tôi hay trễ việc gì → câu ngoài phạm vi).
- [ ] **5.** `flutter analyze` + `flutter test`; PR vào `main`.

## 5. Nhật ký thay đổi
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-10-29 | Tạo plan (có lệnh ghi + thẻ xác nhận) | Đi cùng FR-22 |
| 2026-10-30 | Viết lại cho giai đoạn 1 chỉ đọc: bỏ thẻ xác nhận / `confirm_words`, thêm nút gợi ý + `clarify` | Hiếu chốt: bước đầu chỉ nối API GET |
