# MVP — Trợ lý 3D nói chuyện bằng giọng (Mobile)

Trạng thái: Nháp · Branch: `feature/avatar-3d` · Cập nhật: 2026-10-28

<!-- Thiết kế trên Claude web (2026-10-28). Hiếu duyệt rồi mới đưa Claude Code.
Claude Code chỉ được tick checkbox ở mục 0 và 4, và DỪNG sau mỗi bước.
Đây là bản THỬ (spike): chứng minh được đường đi giọng nói → API → nhân vật 3D trả lời. -->

## 0. Mục tiêu

- **Làm gì:** Một màn hình trợ lý có nhân vật 3D. User bấm giữ nút micro và nói "Hôm nay tôi nên làm gì?".
  App chuyển giọng thành chữ, gọi API tóm tắt hôm nay có sẵn (FR-12, `GET /briefing/today`),
  rồi nhân vật **đọc to** câu trả lời, **nhép miệng** khi nói, **chớp mắt / thở** khi đứng chờ.
- **Vì sao MVP chỉ 1 lệnh:** chứng minh cả đường ống (micro → chữ → API → giọng đọc → 3D) chạy được trên máy thật
  **mà chưa cần AI service làm thêm gì**. Lệnh thứ 2 trở đi sẽ do agent `/assistant/turn` của AI service xử lý (plan riêng, giai đoạn B).
- **Tiêu chí xong:**
  - [ ] AC1 — Nhân vật VRM hiện trong app (Android emulator + 1 máy thật), có chớp mắt và thở nhẹ khi chờ; không giật, không màn trắng.
  - [ ] AC2 — Bấm giữ micro → thấy chữ nhận dạng hiện dần (tiếng Việt); thả tay → gửi.
  - [ ] AC3 — Câu có ý "hôm nay / làm gì / ưu tiên / việc gì" → gọi `/briefing/today` → nhân vật đọc: số việc trên lịch hôm nay + tối đa 3 việc nên làm trước kèm lý do + deadline nguy hiểm (nếu có).
  - [ ] AC4 — Câu khác → nhân vật nói câu gợi ý "Bạn thử hỏi: Hôm nay tôi nên làm gì?". Không gọi API.
  - [ ] AC5 — Miệng nhép khi đang đọc, dừng khi đọc xong; bấm micro trong lúc đang đọc → dừng đọc ngay.
  - [ ] AC6 — Lỗi (không có mạng, AI 401/5xx, user từ chối quyền micro) → nhân vật nói câu báo lỗi ngắn + hiện chữ; **không** bịa dữ liệu giả.
  - [ ] AC7 — Không sửa hành vi các màn hình cũ; `flutter analyze` sạch.
- **Ngoài phạm vi:** agent hiểu nhiều lệnh (giai đoạn B) · thao tác ghi (start timer, tạo task) · nhép miệng khớp từng âm ·
  animation Mixamo · iOS máy thật (chỉ cần build được simulator) · lưu lịch sử hội thoại.

## 1. Bên ngoài — nói chuyện với ai

### API (đã có, không cần ai làm thêm)
| Method | Endpoint | Ở đâu | Ghi chú |
|---|---|---|---|
| GET | `/briefing/today?language=vi` | AI service (`AppConfig.aiServiceUrl`) | Mobile gọi **thẳng** AI service (nhóm đã chốt, `FR-12.md` ghi qua Backend là bản cũ). Gửi `Authorization: Bearer <JWT>` giống `CopilotRepository`. Response xem `plans/FR-12.md` bên repo AI |

Các trường dùng để đọc:
- `schedule` — đếm số mục (**không** đếm `all_day`).
- `top_tasks[].title` + `top_tasks[].reasons[0].text` — câu có sẵn.
- `at_risk[].title` — **không có `text`**, app tự ghép câu "… có nguy cơ trễ hạn" (chỉ đọc tên, không đọc số).
- `calendar_connected`.

Bỏ qua ở MVP: `all_day`, `has_pending_proposal`, `productive_hint` (giữ câu ≤ 60 từ).
Không đọc mã nội bộ (`code`, `missing_minutes`…).

### Thư viện mới (đề xuất)
| Gói | Dùng làm gì |
|---|---|
| `flutter_inappwebview` `^6.2.0-beta.3` | (bản 6.1.5 ổn định không build được với AGP 9.1 của project — lỗi `proguard-android.txt`; đổi về bản ổn định khi 6.2.0 ra chính thức) Hiện trang HTML chạy three.js; có sẵn `InAppLocalhostServer` để phục vụ file trong `assets/` qua `http://localhost` (tránh lỗi đọc file `file://` khi tải model trên Android) |
| `speech_to_text` | Giọng → chữ ngay trên máy, có `vi_VN` |
| `flutter_tts` | Chữ → giọng đọc, có giọng `vi-VN`; có sự kiện bắt đầu / kết thúc để điều khiển miệng |

### File 3D
- Nhân vật tự tạo bằng **VRoid Studio** (miễn phí, chạy trên Mac) → xuất `.vrm` (giảm texture để file ≤ 10 MB).
  Không dùng model tải trên mạng để tránh rủi ro license.
- `three.js` + `@pixiv/three-vrm` **đóng gói sẵn thành 1 file JS** trong `assets/avatar/` (không tải từ CDN, chạy được khi mạng yếu).

### Quyền hệ điều hành
- Android `AndroidManifest.xml` (main):
  - `INTERNET` — hiện chỉ có ở `debug`/`profile` nên bản release không gọi mạng được (lỗi cũ, sửa luôn ở bước 1).
  - `android:networkSecurityConfig="@xml/network_security_config"` — Android 9+ chặn WebView tải `http://`; file
    `res/xml/network_security_config.xml` chỉ cho phép `http` với `localhost` / `127.0.0.1` (**không** bật `usesCleartextTraffic` cho cả app). Dio không bị ảnh hưởng.
  - `RECORD_AUDIO` (bước 5); trong `<queries>` thêm intent `android.speech.RecognitionService` và `android.intent.action.TTS_SERVICE`.
- `pubspec.yaml`: khai báo `assets/avatar/` (Flutter không lấy thư mục con → `avatar_src/` không bị đóng gói vào app).
- iOS `Info.plist`: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` (câu tiếng Việt).

### Vấn đề & quyết định
| # | Vấn đề | Đề xuất | Lý do |
|---|---|---|---|
| 1 | Vẽ 3D bằng gì | WebView + three.js + three-vrm | Điều khiển được biểu cảm / miệng của VRM; nhẹ hơn nhúng Unity rất nhiều |
| 2 | Nguồn nhân vật | Tự tạo bằng VRoid Studio | Nhân vật thuộc quyền nhóm, có sẵn biểu cảm + khẩu hình |
| 3 | Nhép miệng | Khi TTS đang đọc: biểu cảm `aa` dao động theo hình sin (≈ 8 lần/giây, biên độ ngẫu nhiên nhẹ); dừng khi TTS xong | Đủ thuyết phục cho demo, không cần phân tích âm thanh |
| 4 | Hiểu câu lệnh ở MVP | Luật từ khóa trên máy (1 lệnh) | Chưa cần AI service; giai đoạn B thay bằng `/assistant/turn` |
| 5 | Màn hình đặt ở đâu | Nút nổi (FAB) trên màn **Today** mở `AssistantScreen` | Không đổi thanh tab của bạn mobile |
| 6 | Gọi AI service | Tạo `AssistantRepository` riêng, dùng `Dio` + interceptor JWT giống `CopilotRepository` | Không sửa code cũ |
| 7 | Lỗi API | Báo lỗi thật, **không** dùng dữ liệu giả như fallback trong `CopilotRepository` | Demo trước hội đồng phải là dữ liệu thật |
| 8 | Token hết hạn (~60', app chưa tự refresh) | **Không** sửa trong plan này; trước demo đăng nhập lại. Tự refresh token làm plan riêng cho cả app | Sửa `ApiClient` dùng chung sẽ đụng mọi màn hình (AC7) |
| 9 | Test repository không có server thật | Tự viết `HttpClientAdapter` giả trong file test, **không** thêm gói; `AssistantRepository` nhận `Dio?` qua constructor (không truyền → tự tạo như Copilot) | Project ít gói; 4 tình huống tự viết là đủ |

## 2. Bên trong — logic

### Code nằm ở đâu
```
assets/avatar/
  index.html          — canvas + nạp avatar.js
  avatar.js           — three.js + three-vrm đã đóng gói (build 1 lần, xem bước 2)
  avatar_src/main.js  — mã nguồn trước khi đóng gói (scene, đèn, camera, idle, miệng, biểu cảm)
  avatar_src/package.json + README.md — phiên bản three / three-vrm / esbuild cố định, lệnh build
                        (README để trong avatar_src/ cho khỏi bị đóng gói vào app)
  model.vrm           — nhân vật từ VRoid (VRM 1.0)
lib/dev/assistant_preview_main.dart — chạy thẳng màn trợ lý, bỏ qua đăng nhập (chỉ dùng khi dev)
lib/features/assistant/
  data/assistant_repository.dart     — gọi /briefing/today
  logic/intent_router.dart           — luật từ khóa (#4)
  logic/briefing_speech.dart         — ghép câu đọc từ JSON briefing
  widgets/avatar_view.dart           — InAppWebView + cầu nối JS
  screens/assistant_screen.dart      — màn hình: avatar, chữ nhận dạng, nút micro
lib/core/constants/api_endpoints.dart — thêm aiBriefingToday
```

### Cầu nối Flutter ↔ JS (trong `avatar_view.dart`)
- Flutter → JS (`evaluateJavascript`):
  - `avatar.setSpeaking(true|false)` — bật / tắt nhép miệng.
  - `avatar.setEmotion('neutral'|'happy'|'thinking'|'sad')` — map sang biểu cảm VRM (`neutral`, `happy`, `relaxed`, `sad`).
- JS → Flutter (handler `AvatarBridge`): `ready` (model nạp xong) · `error` (kèm thông điệp).
- Flutter chỉ gửi lệnh sau khi nhận `ready`.

### Luồng một lần nói
1. User bấm giữ micro → dừng TTS nếu đang đọc → `setEmotion('neutral')` → `speech_to_text.listen(localeId: 'vi_VN')`, hiện chữ dần.
2. Thả tay → lấy câu cuối → `intent_router`:
   - Khớp lệnh briefing → `setEmotion('thinking')` → gọi `/briefing/today?language=vi`.
   - Không khớp → câu gợi ý (AC4).
3. Có kết quả → `briefing_speech` ghép câu → `setEmotion('happy')` (có deadline nguy hiểm thì `'neutral'`).
4. `flutter_tts.speak()`; `onStart` → `setSpeaking(true)`; `onComplete` / `onCancel` / `onError` → `setSpeaking(false)`.

### Luật & trường hợp đặc biệt
- **Từ khóa (#4):** chữ thường, bỏ dấu rồi so: `hom nay`, `lam gi`, `uu tien`, `viec gi`, `today`. Có 1 từ là khớp.
- **Câu đọc (`briefing_speech`):** tối đa khoảng 60 từ. Mẫu:
  "Hôm nay bạn có {n} việc trên lịch. Nên làm trước: {việc 1}, vì {lý do}. Sau đó là {việc 2}. … {Cảnh báo deadline nếu có}."
  Cảnh báo deadline: "Cẩn thận: {A} có nguy cơ trễ hạn." / nhiều việc → "Cẩn thận: {A} và {B} có nguy cơ trễ hạn."
  Không có việc → "Hôm nay bạn chưa có việc nào cần làm. Muốn mình xếp lịch không?" (chỉ nói, chưa làm gì).
  `calendar_connected = false` → thêm "Bạn chưa kết nối Google Calendar."
- **TTS:** `setLanguage('vi-VN')`, tốc độ 0.5 (Android) / tương đương iOS; không có giọng Việt trên máy → đọc chữ ra màn hình + báo "Máy chưa có giọng tiếng Việt".
- **Hiệu năng:** giới hạn 30 fps trong JS, pixel ratio ≤ 2; dừng render khi màn hình không hiển thị.
- **Lỗi:** 401 → "Phiên đăng nhập hết hạn"; mạng / 5xx → "Mình chưa kết nối được máy chủ, thử lại sau nhé"; từ chối micro → hướng dẫn bật quyền.

## 3. Test
| ID | Loại | Tình huống | Kết quả mong đợi | AC |
|---|---|---|---|---|
| T1 | unit | `intent_router`: có dấu / không dấu / tiếng Anh / câu không liên quan | Khớp đúng | AC3, AC4 |
| T2 | unit | `briefing_speech`: 0 / 1 / 3+ việc, có / không deadline nguy hiểm, chưa kết nối lịch | Câu đúng mẫu, ≤ 60 từ, không có tên nội bộ | AC3 |
| T3 | unit | `assistant_repository` với Dio giả: 200, 401, 500, timeout | Đúng model / đúng loại lỗi | AC6 |
| T4 | tay | Mở màn trợ lý trên emulator và máy thật | Nhân vật hiện, chớp mắt, thở | AC1 |
| T5 | tay | Nói "Hôm nay tôi nên làm gì" | Chữ hiện, nhân vật đọc dữ liệu thật, miệng nhép | AC2, AC3, AC5 |
| T6 | tay | Bấm micro khi đang đọc | Dừng đọc ngay | AC5 |
| T7 | tay | Tắt mạng; từ chối quyền micro | Câu báo lỗi, không dữ liệu giả | AC6 |
| T8 | lệnh | `flutter analyze`, `flutter test` | Sạch, xanh | AC7 |

## 4. Các bước code
*(Mỗi bước = 1 việc nhỏ. Claude Code DỪNG sau mỗi bước, chờ Hiếu chạy thử.)*
- [x] **0.** Đọc project: cách lấy JWT (`StorageService`), `CopilotRepository`, `DashboardScreen` (chỗ đặt FAB), manifest Android, `Info.plist`.
  Báo Hiếu chỗ nào lệch plan. Không code.
- [x] **1.** **Spike 3D (quan trọng nhất):** thêm `flutter_inappwebview`; `assets/avatar/index.html` hiện **1 khối lập phương xoay** (WebGL thuần, chưa cần three.js) qua `InAppLocalhostServer`;
  `INTERNET` + `network_security_config` (chỉ localhost) + khai báo `assets/avatar/`;
  màn `AssistantScreen` tạm mở từ FAB. Chạy được trên emulator thì mới đi tiếp. Không chạy → dừng, báo Hiếu để đổi cách (#1).
- [ ] **2.** Đóng gói three.js + three-vrm thành `assets/avatar/avatar.js` (dùng `esbuild` qua `npx`, ghi lệnh build vào `assets/avatar/avatar_src/README.md`);
  nạp `model.vrm` (Hiếu đưa file), camera ngang ngực, đèn, chớp mắt + thở. Gửi `ready` / `error` về Flutter — test: T4.
- [ ] **3.** `avatar_view.dart` + API JS `setSpeaking` / `setEmotion` — thêm 2 nút thử tạm trên màn hình để bật/tắt miệng, đổi biểu cảm.
- [ ] **4.** TTS: `flutter_tts` đọc 1 câu cố định, nối `onStart` / `onComplete` với `setSpeaking` — test: T6 (phần dừng đọc).
- [ ] **5.** STT: `speech_to_text` + quyền Android / iOS, nút bấm giữ micro, hiện chữ — test: T7 (phần quyền).
- [ ] **6.** `intent_router` + `briefing_speech` (logic thuần, chưa gọi API) — test: T1, T2.
- [ ] **7.** `AssistantRepository` (nhận `Dio?` qua constructor) + `ApiEndpoints.aiBriefingToday` — test: T3 (adapter giả, #9).
- [ ] **8.** Ghép toàn luồng trong `AssistantScreen`, xóa 2 nút thử ở bước 3 — test: T5, T6, T7.
- [ ] **9.** `flutter analyze` + `flutter test` (T8); quay video demo 30 giây; ghi kết quả vào mục 5.

## 5. Nhật ký thay đổi
| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-10-28 | Tạo plan | Thử MVP trợ lý 3D trên mobile trước khi làm agent `/assistant/turn` (giai đoạn B) |
| 2026-10-28 | Bước 0 xong; cập nhật: trường API thật (`at_risk` không có `text`, bỏ `all_day` / `has_pending_proposal` / `productive_hint`), `INTERNET` ở main manifest, `network_security_config` cho localhost, khai báo assets, quyết định #8 (token) và #9 (Dio giả) | Đọc project + `FR-12.md`; Hiếu chốt. Mobile gọi thẳng AI và giọng nói nằm trong phạm vi capstone (FR-12 ghi khác là bản cũ) |
| 2026-10-28 | Bước 1: dùng `flutter_inappwebview ^6.2.0-beta.3` thay vì 6.1.5 | 6.1.5 (`flutter_inappwebview_android` 1.1.3) dùng `getDefaultProguardFile('proguard-android.txt')`, AGP 9.1 từ chối → build fail. Bản beta đã sửa |
| 2026-10-28 | Bước 1 chạy được trên emulator (Android 14, arm64): khối lập phương xoay qua `http://localhost:8080`, ~23 fps (GPU giả lập). Thêm `lib/dev/assistant_preview_main.dart` mở thẳng màn trợ lý (`flutter run -t lib/dev/assistant_preview_main.dart`) | Google Sign-In trên máy Hiếu chưa được (SHA-1 debug chưa đăng ký trên Google Cloud); đăng nhập email là token giả, bị `/api/me` trả 401. Từ bước 7 cần Google Sign-In thật |
| 2026-10-28 | Bước 2 (chờ Hiếu duyệt): three 0.186.1 + three-vrm 3.5.5 → `avatar.js` 747 KB; camera đặt đầu ở 1/3 trên, hạ tay khỏi T-pose, chớp mắt 2–6 s, thở 4 s/lần, 30 fps, dừng vẽ khi trang ẩn; gửi `ready` / `error` về Flutter. Chạy được trên emulator | `model.vrm` 11,8 MB (> 10 MB mục tiêu) — giảm texture trong VRoid khi rảnh. Emulator có 1 cảnh báo `GL_INVALID_VALUE glBufferData` lúc nạp, không ảnh hưởng hiển thị; kiểm lại trên máy thật |
| 2026-10-28 | Bước 3 (chờ Hiếu duyệt): `AvatarView` + `AvatarController` (`setSpeaking` / `setEmotion`, bỏ qua lệnh trước `ready`), JS `window.avatar`, 2 nút thử tạm. Lệnh tới JS đúng, three.js đặt đúng giá trị morph; **emulator Pixel 8 (arm64, `hw.gpu.mode=auto`) không vẽ morph** (miệng, biểu cảm, chớp mắt đều không hiện; kèm cảnh báo `GL_INVALID_VALUE glBufferData`). Cùng trang trên Chrome Mac hiện đúng `sad` + miệng mở | Giới hạn GPU giả lập, không phải lỗi code. Kiểm biểu cảm / miệng / chớp mắt trên **máy thật** (AC1 cũng yêu cầu máy thật) |
| 2026-10-28 | Ghi chú: `test/widget_test.dart` đã lỗi sẵn trước plan này (`DotEnv has not been initialized`, từ commit `a91a0cd`) | Cần sửa trước bước 9 (T8 yêu cầu `flutter test` xanh) |
