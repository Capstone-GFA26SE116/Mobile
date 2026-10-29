# Hoàn tất trợ lý 3D (MVP) — chạy 1 mạch tới PR

Trạng thái: Đã duyệt · Branch: `feature/avatar-3d` · Cập nhật: 2026-10-29

<!-- Viết trên Claude web (2026-10-29). Thay cho plans/avatar-3d-finish.md (đánh dấu "Thay bởi avatar-3d-complete.md" ở đầu file đó).
Plan gốc vẫn là plans/avatar-3d-mvp.md (AC, thiết kế, test, nhật ký).

CÁCH CHẠY: Claude Code làm LIỀN từ bước 1 tới bước 12, KHÔNG dừng giữa các bước.
Mỗi bước: làm + tự kiểm (lệnh / test / ảnh chụp simulator), commit riêng, ghi 1 dòng nhật ký vào avatar-3d-mvp.md mục 5.
CHỈ DỪNG khi: (a) cùng 1 lỗi sửa 2 lần vẫn không qua, (b) cần quyết định không có trong plan này hoặc plan gốc,
(c) tới bước 13 (Hiếu duyệt cuối). Không tự đổi thiết kế, không thêm tính năng ngoài plan. -->

## 0. Hiện trạng & đích đến

**Đã xong:** bước 0, 1, 4–8 của plan gốc; `flutter analyze` sạch, `flutter test` 22/22 xanh. Android emulator: nghe giọng thật, đọc dữ liệu thật.
**Còn chặn:** bước 2–3 chưa tick vì emulator Android không vẽ morph (`GL error 0x501`); iPhone thật bị hồ sơ quản lý chặn cài app
(`ManagedConfiguration`) → **iOS Simulator là nơi duyệt chính**.

**Đích đến (định nghĩa "xong"):**
- [x] D1 — Trên iOS Simulator: nhân vật hiện, chớp mắt, thở, 4 biểu cảm, miệng nhép khi đọc — có **ảnh chụp làm bằng chứng** trong repo.
- [x] D2 — Video demo ~30 giây trên Simulator: hỏi "Hôm nay tôi nên làm gì?" → nhân vật nghĩ → cười → đọc **dữ liệu thật**, miệng nhép.
- [x] D3 — `model.vrm` < 10 MB, nhìn không khác bản cũ.
- [x] D4 — `flutter analyze` sạch, `flutter test` xanh, build Android + iOS Simulator đều qua.
- [ ] D5 — PR `feature/avatar-3d` → `main` sạch: không Team ID / bundle ID riêng của Hiếu, không token, không file rác; mô tả PR đủ để bạn mobile review.
- [x] D6 — Plan gốc mọi bước tick (trừ phần cần iPhone thật, ghi rõ lý do), trạng thái "Xong".

**Ngoài phạm vi:** Google Sign-In trên iOS (cần OAuth client iOS — việc riêng, ghi ở open questions) · iPhone thật (bị chặn) ·
agent nhiều lệnh (giai đoạn B: `avatar-3d-agent.md` + `FR-22.md` repo AI) · đổi `flutter_inappwebview` sang bản ổn định.

## 1. Hiếu chuẩn bị TRƯỚC khi chạy (khoảng 10 phút)

1. **Token thật cho Simulator** (vì iOS chưa đăng nhập Google được):
   chạy app trên Android emulator → đăng nhập Google → Claude Code đọc token theo bước 2 dưới đây.
   Token sống khoảng 60 phút → **làm ngay trước khi bắt đầu**, để bước 10 (quay video) còn hạn.
2. **Giọng tiếng Việt cho Simulator:** mở Simulator (iPhone bất kỳ) → Settings → Accessibility → Spoken Content → Voices → Vietnamese → tải 1 giọng.
   (Không có giọng Việt thì TTS iOS im lặng → miệng không nhép.)
3. **(Nên) xuất lại VRM nhẹ hơn:** VRoid → Export → Texture Atlas **1024 × 1024**, Reduce Bones / Hair 50 → lưu
   `~/Desktop/Metanoia Assistant.vrm`. Không làm cũng được — bước 3 có cách tự giảm.
4. Mở Claude Code ở repo Mobile, chế độ **tự chấp nhận sửa file**, rồi dán prompt ở mục 4.

## 2. Quyết định

| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| 1 | Simulator không đăng nhập Google | `lib/dev/assistant_preview_main.dart` đọc `const String.fromEnvironment('DEV_JWT')`; **chỉ khi `kDebugMode`** và chuỗi không rỗng → `StorageService.saveAccessToken` trước `runApp`. Release build bỏ qua | Lấy dữ liệu thật mà không đụng luồng đăng nhập |
| 2 | Lấy token từ Android | Claude Code đọc qua `adb`: thêm tạm `debugPrint('DEV_JWT=...')` sau đăng nhập **trong 1 commit KHÔNG push** rồi `git reset` ngay; hoặc nếu `StorageService` dùng secure storage thì đọc log. Token chỉ nằm trong terminal, **không ghi vào file nào trong repo** | Không lộ token |
| 3 | Mic trên Simulator | Không phụ thuộc mic: thêm `--dart-define=DEV_UTTERANCE="Hôm nay tôi nên làm gì?"` — chỉ `kDebugMode`, màn xem thử tự "nói" câu này 2 giây sau khi nhân vật `ready` (đi qua đúng luồng bước 8, bỏ qua STT) | Quay video tự động, lặp lại được. Mic thật đã kiểm trên Android |
| 4 | Tự kiểm hình | Thêm `--dart-define=DEV_AVATAR_TOUR=true` (chỉ debug): lần lượt `neutral` → `happy` → `thinking` → `sad` → nói 3 giây, mỗi trạng thái 2 giây. Claude Code chụp `xcrun simctl io booted screenshot` ở từng trạng thái và **tự xem ảnh** | Claude Code tự duyệt bước 2–3 thay vì chờ người nhìn |
| 5 | Ảnh / video bằng chứng | Ảnh: `docs/avatar/screenshots/*.png` (≤ 300 KB mỗi ảnh, commit). Video: `docs/avatar/demo.mp4` **không commit** (thêm vào `.gitignore`), Hiếu tự đính kèm vào PR / báo cáo | Repo không phình |
| 6 | Giảm `model.vrm` khi Hiếu chưa xuất lại | Script `assets/avatar/avatar_src/shrink_vrm.py` (Python, Pillow): đọc GLB, thu mọi ảnh > 1024 px về 1024 (giữ PNG/JPEG gốc), dựng lại buffer + bufferView, **giữ nguyên JSON extensions VRM**. Kiểm: file mới nạp được trong Chrome headless (Playwright) + Simulator, số morph / expression giữ nguyên. Không đạt → giữ file cũ, ghi nhật ký | Không phụ thuộc thao tác tay trong VRoid |
| 7 | 3 file plugin macOS / Windows / Linux | **Commit** — đó là file Flutter tự sinh khi thêm plugin, repo đã theo dõi sẵn; bỏ ra thì build desktop của người khác lệch | Chuẩn Flutter |
| 8 | File iOS đổi khi ký app | `project.pbxproj`: **bỏ** mọi dòng `DEVELOPMENT_TEAM` và đổi `PRODUCT_BUNDLE_IDENTIFIER` về `com.metanoia.metanoiaMobile`; **giữ** thay đổi do CocoaPods / Flutter sinh. Commit `Podfile`, `Podfile.lock`. Không commit `ios/Pods/`, `xcuserdata/` | Không lộ Team ID; người khác vẫn build được |
| 9 | Beta `flutter_inappwebview` + cảnh báo Kotlin `flutter_tts` | Giữ nguyên; ghi vào mô tả PR mục "Theo dõi" | Ngoài phạm vi |

## 3. Các bước (Claude Code chạy liền)

- [x] **1. Dọn plan.** `avatar-3d-finish.md` thêm dòng "Thay bởi `avatar-3d-complete.md`". Plan gốc: AC1 → "iOS Simulator (thay cho máy thật — iPhone bị hồ sơ quản lý chặn cài app)"; T4 → "iOS Simulator"; thêm #1–#9 vào bảng quyết định.
- [x] **2. Hook debug (#1, #3, #4).** `assistant_preview_main.dart` + `AssistantScreen` nhận `devUtterance` / `devTour` qua constructor (màn chính không truyền → hành vi cũ). Unit/widget test: không có define → không làm gì thêm; `devUtterance` → gọi đúng luồng như câu nói thật. Kiểm `kDebugMode` bằng test hoặc ghi rõ trong nhật ký.
- [x] **3. Giảm VRM (#6).** Có `~/Desktop/Metanoia Assistant.vrm` mới hơn file trong repo → dùng file đó. Không có → chạy `shrink_vrm.py`. Mục tiêu < 10 MB. Kiểm nạp được bằng Playwright Chrome headless (`index.html` qua server tĩnh tạm, chờ `ready`, chụp ảnh).
- [x] **4. iOS build.** `flutter pub get` → `cd ios && pod install` (đặt `platform :ios, '15.0'` nếu cần) → `flutter build ios --simulator --debug`. Lỗi build → sửa theo log.
- [x] **5. Chạy Simulator.** Boot 1 iPhone (`xcrun simctl boot "<iPhone mới nhất có sẵn>"`, `open -a Simulator`). `flutter run -d <id> -t lib/dev/assistant_preview_main.dart --dart-define=DEV_AVATAR_TOUR=true`. Chờ `ready` (tối đa 60 s, đọc log).
- [x] **6. Tự duyệt hình (#4).** Chụp 6 ảnh: chờ (mắt mở), chớp mắt (chụp liên tục 10 ảnh trong 6 s, giữ 1 ảnh mắt nhắm), `happy`, `thinking` (đầu nghiêng), `sad`, đang nói (miệng mở). Xem từng ảnh: đúng → lưu vào `docs/avatar/screenshots/`. Sai → tìm nguyên nhân (log WebView, thử Chrome headless cùng model) và sửa; vẫn sai sau 2 lần → DỪNG báo Hiếu kèm ảnh.
- [x] **7. Tick bước 2–3** plan gốc + AC1 (Simulator). Ghi fps (đọc từ overlay/log) và thời gian nạp model.
- [x] **8. Lấy token (#2)** từ Android emulator đang đăng nhập. Không lấy được / emulator không chạy → DỪNG, nhờ Hiếu đăng nhập lại.
- [x] **9. Chạy luồng thật trên Simulator:** `--dart-define=DEV_JWT=<token> --dart-define=DEV_UTTERANCE="Hôm nay tôi nên làm gì?"`. Log phải thấy `GET /briefing/today` 200, TTS bắt đầu, `setSpeaking(true)` rồi `false`. Không có giọng Việt → DỪNG nhắc Hiếu mục 1.2.
- [x] **10. Quay video (D2).** `xcrun simctl io booted recordVideo --codec h264 docs/avatar/demo.mp4` → chạy lại bước 9 từ đầu → dừng quay sau khi đọc xong + 2 s. Video 20–40 s. Thêm `docs/avatar/demo.mp4` vào `.gitignore`.
- [x] **11. Kiểm toàn bộ (D4).** `flutter analyze`, `flutter test`, `flutter build apk --debug`, `flutter build ios --simulator --debug` — tất cả qua. Tick bước 9 plan gốc.
- [x] **12. Dọn & PR (D5, #7, #8).**
  - `git status` sạch rác; không còn `debugPrint` token; grep repo không có chuỗi `eyJ` (JWT) hay Team ID.
  - `project.pbxproj` theo #8 (`git diff` kiểm lại).
  - Plan gốc → "Xong" (ghi rõ: iPhone thật chưa kiểm do hồ sơ quản lý; mic thật đã kiểm trên Android).
  - Push, tạo PR bằng `gh pr create` (nếu `gh` chưa đăng nhập → in nội dung PR ra để Hiếu dán). Mô tả PR:
    **Làm gì** (3 dòng) · **Cách chạy thử** (lệnh màn xem thử + `DEV_JWT` / `DEV_UTTERANCE` / `DEV_AVATAR_TOUR`) ·
    **Ảnh** (link `docs/avatar/screenshots/`) · **Thư viện mới** (`flutter_inappwebview` beta + lý do, `flutter_tts`, `speech_to_text`) ·
    **Quyền mới** (micro, nhận giọng nói) · **Theo dõi** (#9, Google Sign-In iOS, VRM) · **Không đổi** (các màn cũ; FAB có `heroTag`).
- [ ] **13. DỪNG — báo Hiếu:** link PR, đường dẫn video, 6 ảnh, bảng D1–D6 (đạt / chưa), việc còn lại cho người.

## 4. Prompt dán vào Claude Code

```
Đọc plans/avatar-3d-complete.md và plans/avatar-3d-mvp.md.
Làm liền bước 1 → 12 trong avatar-3d-complete.md, không dừng giữa các bước.
Mỗi bước tự kiểm (lệnh / test / ảnh simulator), commit riêng, ghi nhật ký.
Chỉ dừng theo đúng 3 điều kiện ở đầu file. Xong thì làm bước 13.
Token Android: emulator đang chạy và đã đăng nhập Google.
```

## 5. Việc cho người sau khi PR mở (không chặn PR)
- Bạn mobile review PR.
- ⚠️ Người quản Google Cloud: OAuth client iOS → cấu hình Google Sign-In iOS (plan riêng) để demo bằng đăng nhập thật.
- iPhone thật: gỡ hồ sơ quản lý / Screen Time chặn cài app (Settings → Screen Time → Content & Privacy Restrictions → iTunes & App Store Purchases → Installing Apps → Allow; nếu là hồ sơ MDM thì vào Settings → General → VPN & Device Management) → thử mic thật.
- Giai đoạn B: `plans/FR-22.md` (repo AI) rồi `plans/avatar-3d-agent.md`.
