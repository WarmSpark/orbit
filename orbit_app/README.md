# Orbit 🪐

Find spontaneous hangouts happening around you. Orbit is a bright, map-first
mobile app: sign in with Google, drop a pin for something you want to do
(watch a movie, grab coffee, play football), and let people nearby ask to join.
Every hangout gets a private, self-destructing group chat, and the whole region
shares one live "Town Hall".

> **Beta scope:** Orbit is currently limited to the **Delhi NCR**. Outside the
> zone the app shows a friendly *"The Orbit is coming soon…"* screen.

This is the fresh Flutter frontend in **`orbit_app/`** talking to the Go backend
in **`hangout-backend/`**. The older `orbit/` folder is intentionally left
untouched.

---

## Features

| Requirement | Where it lives |
|---|---|
| Google sign-in | `screens/login_screen.dart`, `services/auth_service.dart` |
| Onboarding — avatar, username (live availability), bio | `screens/onboarding_screen.dart` |
| Map dashboard, zoom to your location | `screens/map_dashboard.dart` |
| Search places like Google Maps → fly to result | `_SearchBar` + `services/geocoding_service.dart` (Nominatim) |
| Simple, elegant pins showing type + title (tap for place/time/desc) | `widgets/hangout_pin.dart`, `screens/hangout_detail_sheet.dart` |
| Tap a pin → join a hangout | `hangout_detail_sheet.dart` → "Request to join" |
| Post a hangout (one per user) with a drag-to-place pin | `screens/post_hangout_screen.dart` |
| Requests panel — tap a photo to review the applicant's profile | `screens/requests_screen.dart` + `widgets/profile_preview.dart` |
| Per-hangout group chat, slide-to-reply, "disappears after 24h" | `screens/chat_screen.dart`, `screens/chat_view.dart` |
| Members list: host can kick / cancel; members can leave | `screens/members_sheet.dart` |
| NCR-wide Town Hall local chat | `screens/townhall_screen.dart` (backend `ServeTownhall`) |
| Map capped to NCR + "coming soon" gate | `main.dart` `LocationGate`, `CameraConstraint` in the maps |

Chat protections (server-authoritative identity, text sanitisation, and a
15-messages / 5-seconds flood limit) are enforced on the backend and mirrored
client-side so users get instant feedback instead of silently dropped messages.

---

## Project layout (`orbit_app/lib`)

```
config.dart            Base URL, Google client id, NCR bounds (all --dart-define-able)
theme.dart             Bright Material 3 theme + categories
main.dart              RootGate (auth) → LocationGate (NCR) → HomeShell
models/                user, hangout, applicant, member, chat_message, join_request
services/              api_client, auth, profile, event, request, chat (WS), location, geocoding
state/app_state.dart   ChangeNotifier: session, current user, service handles
widgets/               orbit_avatar, category_chip, hangout_pin, empty_state, profile_preview
screens/               splash, login, onboarding, coming_soon, map_dashboard,
                       hangout_detail_sheet, post_hangout, requests, chats,
                       chat_view/chat_screen, townhall, members_sheet, profile, home_shell
```

State is `provider` + `ChangeNotifier`. There is no local database — the backend
keeps everything in RAM and reaps expired data, so the app is a thin, live client.

---

## Running the backend

```bash
cd hangout-backend
go run ./cmd/server          # listens on :8000
```

All state is in-memory and resets on restart. Configuration is via environment
variables (nothing secret is committed):

| Env var | Purpose | Leave unset? |
|---|---|---|
| `JWT_SECRET` | Stable session signing key | Optional (random per-process if unset — sessions reset on restart) |
| `GOOGLE_CLIENT_ID` | **Web** OAuth client id; enforces the id_token `aud` | Set in production; unset only while wiring UI |
| `ALLOWED_ORIGINS` | Comma-separated CORS/WS origin allow-list | Unset = allow all (dev only) |
| `CAMPUS_LAT` / `CAMPUS_LNG` / `CAMPUS_RADIUS_KM` | Optional campus geofence for posting | **Leave unset for NCR testing** — otherwise posting is restricted to that campus |

> ⚠️ **For NCR testing, do not set `CAMPUS_*`.** When unset, `withinCampus`
> returns `true`, so hangouts can be posted anywhere the client allows (i.e. the
> NCR). The NCR gate itself (`withinNCR`) is always active for the Town Hall.

---

## Running the app

```bash
cd orbit_app
flutter pub get

# Android emulator (reaches your host at 10.0.2.2):
flutter run \
  --dart-define=ORBIT_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=ORBIT_GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com

# Physical device on the same Wi-Fi — use your machine's LAN IP:
flutter run --dart-define=ORBIT_BASE_URL=http://192.168.1.5:8000 --dart-define=ORBIT_GOOGLE_CLIENT_ID=...
```

Defaults if you omit them: `ORBIT_BASE_URL=http://10.0.2.2:8000`,
`ORBIT_GOOGLE_CLIENT_ID=""` (sign-in disabled with a clear on-screen note).

### Google Sign-In setup

1. In Google Cloud Console → **Credentials**, create a **Web** OAuth client.
   Its id is what both the backend (`GOOGLE_CLIENT_ID`) and the app
   (`ORBIT_GOOGLE_CLIENT_ID`) must use — they have to match.
2. Also create an **Android** OAuth client registered with your app's package
   name (`com.orbit.orbit_app`) and signing **SHA-1**
   (`cd android && ./gradlew signingReport`).
3. The app requests an `idToken` using the web client id as `serverClientId`
   and posts it to `POST /api/v1/auth/google`; the backend verifies it and
   returns a session JWT.

The Android manifest already declares `INTERNET` + location permissions and
allows cleartext traffic (for the `http://…` dev backend). Use HTTPS in
production and drop `usesCleartextTraffic`.

---

## How the pieces connect

- **Auth:** `POST /auth/google` → JWT held by `ApiClient`, persisted in
  `SharedPreferences`, restored on launch by `AppState.bootstrap()`.
- **Map:** `GET /events` returns privacy-safe pins (host email stripped,
  coordinates fuzzed ~110 m). Pins are capped to NCR both by camera constraint
  and by the region gate.
- **Join flow:** applicant `POST /events/join` → host sees them in
  `GET /events/requests` → `POST /events/requests/respond`
  (`approved`/`declined`, capacity enforced atomically).
- **Chat:** WebSocket `GET /chat/ws?room_id=&token=` (host/approved only) and
  `GET /townhall/ws?token=&lat=&lng=` (any NCR user). History arrives on connect;
  kicks/cancels arrive as `action` frames; everything expires after 24 h via the
  server reaper.
- **Members/moderation:** `GET /events/members` returns member profiles; the
  host additionally receives participant emails (and nobody else does) so
  `POST /events/kick` and `POST /events/cancel` work while preserving privacy.

---

## Tests & checks

```bash
# Frontend
cd orbit_app && flutter analyze && flutter test

# Backend
cd hangout-backend && go build ./... && go vet ./...
```

All of the above currently pass clean.
