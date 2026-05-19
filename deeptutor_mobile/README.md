# DeepTutor Mobile — Flutter Android Application

Production-grade Flutter Android application for the DeepTutor AI-native intelligent tutoring platform.

## Architecture

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # MaterialApp + router + theme
├── core/
│   ├── config/app_config.dart   # Base URL, flavors
│   ├── network/
│   │   ├── dio_client.dart      # Dio factory + interceptors
│   │   └── ws_client.dart       # UnifiedWsClient (WebSocket)
│   ├── storage/
│   │   └── secure_token_store.dart
│   ├── theme/
│   │   ├── app_theme.dart       # Material 3 ThemeData
│   │   ├── app_colors.dart      # Design tokens
│   │   ├── app_spacing.dart     # 4-point grid
│   │   └── app_text_styles.dart
│   └── widgets/                 # Shared reusable widgets
├── data/
│   ├── models/                  # Dart domain models (json_serializable)
│   └── repositories/            # API data layer
├── features/
│   ├── auth/                    # Login, register, splash
│   ├── home/                    # Dashboard (mobile-study parity)
│   ├── chat/                    # WebSocket streaming chat
│   ├── onboarding/              # 8-step learning profile setup
│   ├── practice/                # MCQ quiz flow
│   ├── career/                  # Career path selection
│   ├── missions/                # Daily missions + XP
│   ├── profile/                 # Learning ID / EIP
│   ├── settings/                # Language, theme
│   └── shell/                   # Responsive navigation shell
├── navigation/
│   └── router.dart              # go_router with auth guards
└── l10n/                        # ARB files (en, hi)
```

## Tech Stack

| Layer | Library |
|-------|---------|
| State | Riverpod 2 (`StateNotifier`, `FutureProvider`) |
| Navigation | `go_router` 14 |
| HTTP | `dio` 5 |
| WebSocket | `web_socket_channel` 3 |
| Storage | `flutter_secure_storage` + `hive_flutter` |
| Models | `json_serializable` + `freezed_annotation` |
| UI | Material 3, `google_fonts`, `flutter_markdown` |
| i18n | `flutter_localizations` + ARB |

## Setup

### 1. Backend (required — start this first)
```bash
cd Deep-Tutor
python -m venv .venv
.venv\Scripts\activate
pip install -e ".[server]"
python -m deeptutor.api.run_server
```

The API listens on **http://localhost:8001** by default (`BACKEND_PORT` in `.env`).

### 2. Flutter
```bash
cd deeptutor_mobile
flutter pub get
flutter run
```

> **Chrome / web:** Uses `http://localhost:8001` (same machine as the Flutter dev server).
>
> **Android emulator:** Uses `http://10.0.2.2:8001` (host loopback).
>
> **Physical device:** Run with a reachable host, e.g.
> `flutter run --dart-define=API_BASE=http://192.168.1.10:8001`

If WebSocket or REST calls fail, confirm the backend is running (`curl http://localhost:8001/api/v1/auth/status`).

## Features (Phase 1)

- [x] Auth (JWT, local storage, 401 interceptor)
- [x] Home dashboard (XP, streak, quick tiles, missions preview)
- [x] Unified WebSocket chat (streaming, reconnect, heartbeat)
- [x] Onboarding 8-step flow (syncs to `PUT /learning-profile`)
- [x] Practice MCQ (topics, hints, submit, XP result)
- [x] Career paths (readiness, skill gaps)
- [x] Missions & gamification
- [x] Profile / Learning ID
- [x] Settings (language picker)
- [x] Responsive shell (phone bottom nav, tablet rail)
- [x] i18n: English + Hindi

## Phase 2 (Planned)

- [ ] Code Lab (server-side compile, CodeField editor)
- [ ] Razorpay billing
- [ ] Revision queue
- [ ] Notifications inbox
- [ ] Career WebSocket live updates
- [ ] Tablet dual-pane chat layout

## Environment Variables

Configure via `AppConfig` in `lib/core/config/app_config.dart`:

| Variable | Dev | Prod |
|----------|-----|------|
| `API_BASE` | `http://10.0.2.2:8001` | Set via `--dart-define=API_BASE=https://...` |
