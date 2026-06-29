# Trenzy Beta-Prep Changelog

This document tracks every change made to the Trenzy codebase against the founder's 20-user beta scope:

- **Keep**: Auth · Discover · Search · Product Details · Wishlist · AI Recs · Decision History · Blend · Profile
- **Hide/Remove**: Payments · Cart · Orders · Affiliate · Vibes · Social Rooms
- **Priority 1**: Auth security · Prod URL · 500+ products · Analytics · Crash monitoring

## Phase A — Hide fake features

### Files removed
- `lib/screens/vibes_screen.dart` — fully hardcoded fake screen ("Maya", "Tokyo Pop-up", fake vote counts). Was already orphaned (no route, no nav link). Zero-risk delete.

### Backend routes disabled (`backend/app/main.py`)
Commented out `app.include_router(...)` for:
- `cart.router` — useless without checkout
- `checkout.router` — back-door for "free" orders without payment
- `orders.router` — only populated by fake payment flow
- `payments.router` — fake end-to-end (returns random order IDs, never calls Razorpay)
- `affiliate.router` — backend reads non-existent `affiliate_link` attribute (model has `affiliate_links` plural); always returns empty URL

### Flutter routes removed (`lib/router/app_router.dart`)
- Shell route `/social` (bottom-nav Social tab)
- Full-screen route `/social` (SocialRoomScreen)
- Routes for `/cart`, `/orders`, `/checkout`
- Imports for `social_room_screen.dart`, `cart_screen.dart`, `orders_screen.dart`, `checkout_screen.dart` commented out

### Bottom nav simplified (`lib/widgets/app_shell.dart`)
- Removed the "Social" `NavItem`. Nav is now 4 tabs: Home · Blend · Wishlist · Profile.

### Cart UI removed (`lib/widgets/product_card.dart`, `lib/screens/product_details_screen.dart`, `lib/screens/cart_screen.dart`)
- `product_card.dart`: removed the `_QuickAddButton` (cart quick-add) from the product card row.
- `product_details_screen.dart`: removed the "Add to Cart" / "Buy" button (which was actually a fake `recordAffiliateClick` call that fell through to `addItem` when the URL was empty). Added `wishlist_add`/`wishlist_remove` analytics on the detail screen wishlist toggle (was previously missing).
- `cart_screen.dart`: removed the "Proceed to Checkout" button.

### "Ask Friends" button removed (`lib/screens/suggestions_screen.dart`)
- Removed the "Ask Friends" `OutlinedButton` (opened Social Room) and the orphaned `_openSocialRoom` method.
- Added `recommendation_click` analytics event when a user taps a suggestion card (previously missing).

---

## Phase B — Auth blockers fixed

### `backend/app/firebase_auth.py` — REMOVED THE JWT BYPASS
- **Removed**: The `jwt.decode(token, options={"verify_signature": False})` fallback that activated whenever Firebase Admin init failed. This was a total auth bypass — any forged JWT with no signature would be accepted.
- **Added**: `verify_token_string(token)` helper for the Socket.IO auth layer.
- **Behavior change**: If Firebase Admin is not initialized, every protected endpoint returns `503 Authentication backend unavailable`. The app refuses to start without working Firebase Admin (see main.py startup hook).

### `backend/app/main.py` — fail-fast on Firebase init
- Added `init_firebase_admin()` call in the `startup` hook. If it returns `_firebase_initialized == False`, the app raises `RuntimeError` and refuses to boot. The auth module no longer has a fallback, so this guard is mandatory.

### `backend/app/socket_server.py` — Socket.IO now requires auth
- **`connect` handler**: now reads a Firebase ID token from the `auth` payload (or `?token=` query param fallback), verifies it via `verify_token_string`, and stores the verified uid in the session. Connections without a valid token are refused with `ConnectionRefusedError`.
- **All event handlers** (`join_blend`, `blend_swipe`, `join_room`, `send_vote`, `send_message`): now use `_verified_uid(sid)` from the session instead of the client-supplied `userId` field. The client can no longer impersonate other users.
- **CORS**: `cors_allowed_origins="*"` is now configurable via `SOCKET_ALLOWED_ORIGINS` env var. Defaults to `*` for local dev; set to your real domain in production.

### `lib/providers/auth_provider.dart` — web login fixed
- After `api.login()` returns `idToken`, the code now calls `FirebaseAuth.instance.signInWithCustomToken(idToken)` so that `FirebaseAuth.instance.currentUser` is populated and subsequent `ApiService._getToken()` calls return a real token. Previously the token was discarded and every subsequent API call 401'd.

### `lib/services/blend_socket_service.dart` — passes Firebase token on connect
- Added `import 'package:firebase_auth/firebase_auth.dart';`
- `connect()` now fetches the current user's ID token and passes it via `OptionBuilder().setAuth({'token': idToken})`. The backend `connect` handler verifies this token.

---

## Phase C — URL config + Crashlytics

### `lib/services/environment_config.dart` — fail-closed in release
- Release builds now throw `StateError` if `TRENZY_API_BASE_URL` is not provided via `--dart-define`. Previously they silently fell back to `localhost:8000` and every API call failed on real devices.
- Build command for beta:
  ```
  flutter build apk --release \
    --dart-define=TRENZY_API_BASE_URL=https://api.trenzy.example.com
  ```

### `backend/app/main.py` — CORS configurable
- Replaced the hardcoded `allow_origin_regex` (localhost-only) with `allow_origins` list read from `CORS_ALLOWED_ORIGINS` env var. Defaults to localhost for dev; set to your real domain in production.

### `lib/main.dart` — Crashlytics collection explicitly enabled
- Added `await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);` — required on iOS (defaults to disabled) and recommended on Android.
- Changed `PlatformDispatcher.instance.onError` to use `fatal: false` (most async errors are non-fatal; the previous `fatal: true` flooded the crash dashboard with non-crashes).
- Added `await FirebaseAnalytics.instance.logAppOpen();` (Phase D, see below).

### `android/app/build.gradle.kts` — Crashlytics Gradle plugin applied
- Added `id("com.google.firebase.crashlytics")` to the `plugins` block. Required for native stack deobfuscation on release builds (`minifyEnabled = true` strips symbols without it).

### `android/settings.gradle.kts` — Crashlytics plugin version declared
- Added `id("com.google.firebase.crashlytics") version("3.0.2") apply false`.

### `android/app/google-services.json` — file moved into place
- The file was previously only in `backend/google-services.json` (where it's useless — the backend reads Firebase Admin from env vars). Copied it to `android/app/google-services.json` where the Android Gradle plugin expects it. Without this, Android release builds fail.

### `backend/Dockerfile` — removed unnecessary COPY
- Removed `COPY google-services.json ./google-services.json`. The backend doesn't read this file.

---

## Phase D — Analytics wired

### `pubspec.yaml`
- Added `firebase_analytics: ^12.0.0`. (Was missing entirely — every "event" was a `debugPrint` to console.)

### `lib/analytics/analytics_service.dart` — real Firebase implementation
- Added `FirebaseAnalyticsService` class that routes `logEvent`, `setUserId`, `setUserProperty` to `FirebaseAnalytics.instance`.
- Kept `NoopAnalyticsService` as a fallback for web (web support requires extra config; defer to post-beta).

### `lib/providers/analytics_service_provider.dart`
- Returns `FirebaseAnalyticsService` on mobile/desktop, `NoopAnalyticsService` on web.

### Events wired (9/9 required events now tracked)
| Event | Location | Notes |
|---|---|---|
| `app_open` | `lib/main.dart` | Fires after `Firebase.initializeApp()`. |
| `signup` | `lib/screens/auth_screen.dart` | Now a distinct event (previously both flows fired `login`). Only fires on success. |
| `login` | `lib/screens/auth_screen.dart` | Only fires on success (previously fired on failure too). |
| `search` | `lib/screens/search_screen.dart` | Already wired, no change. |
| `product_view` | `lib/screens/product_details_screen.dart` | Already wired, no change. |
| `wishlist_add` / `wishlist_remove` | `lib/widgets/product_card.dart` + `lib/screens/product_details_screen.dart` | Added the detail-screen toggle call (was previously missing). |
| `blend_created` | `lib/screens/blend_hub_screen.dart` | Added after successful `api.createBlend`. |
| `blend_joined` | `lib/screens/blend_hub_screen.dart` | Added after successful `api.joinBlend`. |
| `recommendation_click` | `lib/screens/suggestions_screen.dart` | Added on tap of a suggestion card. |

Also calls `setUserId` after successful login so the analytics dashboard can identify users.

---

## Phase F — Blend Chat one-liner fix

### `backend/app/socket_server.py`
- Added `@sio.event` decorator above `async def send_message(sid, data):`. Without it, socket.io never registered the handler and messages were silently dropped. Blend Chat is now functional end-to-end (create → join → swipe → chat → results).

---

## Phase G — Secrets cleanup

### Files removed
- `backup.sql` (root) — contained real user PII (Firebase UIDs + emails) and full DB schema.
- `backend/backup.sql` — junk file (literally contained the string `"Password: "`).

### `.gitignore` — expanded coverage
Added:
```
/android/app/google-services.json
backend/google-services.json
backend/firebase-service-account*.json
firebase-service-account*.json
*.sql
backup.sql
backend/backup.sql
```

### `backend/app/config.py` — fail-closed on missing DSN
- Changed `POSTGRES_DSN` default from `postgresql+psycopg://postgres:root@localhost:5433/trenzy` (leaked password in source) to `None` with a `RuntimeError` if unset. Forces operators to set the env var explicitly.

### `backend/docker-compose.yml` — env-var substitution
- Replaced hardcoded `POSTGRES_PASSWORD: root` with `${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}`.
- Added `env_file: .env` to the backend service so secrets come from the gitignored `.env`.
- Removed the hardcoded `FIREBASE_API_KEY` line — now reads from env.
- Added `CORS_ALLOWED_ORIGINS`, `SOCKET_ALLOWED_ORIGINS`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_SERVICE_ACCOUNT_FILE` env wiring.

### `backend/.env.example` — new file
- Documents every required env var with example values. Copy to `.env` (gitignored) and fill in real values.

---

## What's NOT done (deferred to post-beta per founder's scope)

- **500+ products**: The catalog still has only 5 products in `backend/data/products.json`. `backend/app/scripts/load_hf_products.py` is broken (wrong import path, can't extract images from the HF dataset). Fixing this requires either (a) curating a real catalog JSON or (b) fixing the import script + downloading image binaries to `backend/data/images/`. Estimated 3-4 hours.
- **iOS `GoogleService-Info.plist`**: Still missing. iOS beta builds will fail Crashlytics init until this is downloaded from the Firebase console and placed at `ios/Runner/GoogleService-Info.plist`.
- **Notifications**: Already orphaned (no route, no nav link, backend router never registered in main.py). Left as-is — no action needed.
- **Web analytics**: `firebase_analytics` web support requires extra setup (measurementId + gtag.js). Falls back to `NoopAnalyticsService` on web for now.

---

## Build & deploy instructions

### Backend (production)
1. Create `backend/.env` from `backend/.env.example`. Fill in:
   - `POSTGRES_PASSWORD` (real password, not `root`)
   - `FIREBASE_SERVICE_ACCOUNT_JSON` (paste the full service-account JSON as one line)
   - `FIREBASE_API_KEY` (your Firebase web API key)
   - `CORS_ALLOWED_ORIGINS=https://your-frontend-domain.com`
   - `SOCKET_ALLOWED_ORIGINS=https://your-frontend-domain.com`
2. `cd backend && docker-compose up -d`
3. The app will refuse to start if `FIREBASE_SERVICE_ACCOUNT_JSON` is missing or invalid. This is intentional.

### Flutter (release)
```bash
flutter build apk --release \
  --dart-define=TRENZY_API_BASE_URL=https://api.trenzy.example.com
```
For iOS:
```bash
flutter build ipa --release \
  --dart-define=TRENZY_API_BASE_URL=https://api.trenzy.example.com
```
Without `--dart-define`, the release build will throw `StateError` on first API call. This is intentional.

### Firebase console setup checklist
- [ ] Download `google-services.json` → place at `android/app/google-services.json` (already done in this zip, but verify the package name matches your Firebase Android app)
- [ ] Download `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist` (NOT done in this zip — download from Firebase console)
- [ ] Generate a Firebase Admin service-account JSON → paste as `FIREBASE_SERVICE_ACCOUNT_JSON` in `backend/.env`
- [ ] Enable Google Analytics in Firebase console
- [ ] Enable Crashlytics in Firebase console
- [ ] Verify events flow: App Open, Signup, Login, Search, Product View, Wishlist Add, Blend Created, Blend Joined, Recommendation Click

### Razorpay webhook (deferred)
The `/api/payments/webhook` endpoint is disabled (router commented out). When you re-enable payments post-beta:
1. Implement `X-Razorpay-Signature` HMAC-SHA256 verification against `RAZORPAY_WEBHOOK_SECRET`.
2. Reject any payload that doesn't pass verification.
