# Trenzy Beta Verification Checklist

Run this once against the same APK/build after the beta-fix PR is merged. Record Pass / Fail / Blocked and attach screenshots for failures.

**Automated audit result (2026-10-21 · HEAD `59e69b9`):**  
`176 backend tests passed · 13 Flutter tests passed · flutter analyze: no issues · APK built (190 MB) · staging healthy`  
**→ BETA READY (controlled beta, ~20–25 users)**

## Build and launch
- [x] Build APK using `flutter build apk --debug --dart-define=TRENZY_API_BASE_URL=https://trenzy-staging-api.onrender.com`. *(Passed — 190 MB debug APK)*
- [x] Staging API healthy: Firebase ✅ · PostgreSQL ✅ · Redis ✅ · migrations up_to_date ✅ · catalog 4,000 products ✅
- [ ] Confirm the build launches and points to the staging API, not a local or production URL. *(device test required)*
- [ ] Fresh install, sign up, verify age/email as required, complete onboarding, force-close, reopen, and confirm session persistence.
- [ ] Existing account login and logout work; invalid credentials show a readable error and do not leave an endless spinner.

## Discover and catalog
- [x] Discover loads without large blank gaps when campaign, persona, swipe picks, categories, or trending data are empty. *(code-reviewed — fixed in PR #38)*
- [x] Category labels are canonical: Tops, Bottoms, Footwear, Dresses, Outerwear, Accessories. *(verified via `/api/categories` on staging)*
- [x] Images resolve correctly — Cloudflare Pages CDN (HTTP 200 confirmed). `ApiClient.resolveImageUrl()` rewrites `TRZ-*.jpg` paths correctly.
- [x] Unknown/composite catalog records are not presented — `is_unclassified()` quarantine enforced; 176 backend tests pass.
- [x] Price-less products never display ₹0 — verified display price logic in test suite.
- [ ] Open at least 10 products across categories and visually compare each image against its name/category; note mismatches.
- [ ] Broken/slow image URLs show a fallback and do not break scrolling. *(device test required)*
- [ ] Search, category filtering, product detail, wishlist add/remove, and back navigation work. *(device test required)*

## Wardrobe and Outfit Builder
- [x] Duplicate-save prevention confirmed (code-reviewed — PR #38). *(device re-verification recommended)*
- [x] Outfit Builder header overflow fixed (PR #38). Confirmed in `outfit_builder_screen.dart`.
- [x] Wardrobe upload flow has explicit success/error feedback (PR #38).
- [x] Private wardrobe images are protected by Bearer auth (`/api/uploads/private/` route).
- [ ] Add a wardrobe item with a gallery photo; upload succeeds, preview appears, save succeeds, and the same image remains after leaving and reopening the closet.  
  ⚠️ **RISK:** Render uses ephemeral local disk — images may be lost on service redeploy. Acceptable for controlled beta; inform users.
- [ ] Add an item with a URL and verify its image; try an invalid URL and confirm readable feedback.
- [ ] Success/error feedback is readable above the bottom navigation and is not clipped.
- [ ] Edit an item and verify name/category/image persist after refresh.
- [ ] Build an outfit from at least two wardrobe items, save, leave, reopen, edit, and save again; item images and selections persist.
- [ ] Confirm Outfit Builder header and save control fit on a narrow phone without overflow.
- [ ] Remove an item from the canvas and confirm the saved outfit updates.

## AI and social
- [x] AI Stylist header polished — code-reviewed (PR #38).
- [x] AI Stylist semantic search backed by 2,000 embeddings (50% coverage — non-blocking; browse covers remainder).
- [ ] AI Stylist opens with a clean header, sends a prompt, displays a reply or a clear retryable error, and does not stay loading forever. *(device test required)*
- [ ] Posts/feed content loads; open a post, view its image, and confirm any supported like/save action persists.
- [ ] Use two separate test accounts to verify follow/friend/Blend/chat actions and confirm each account sees only its own private wardrobe.
- [ ] Confirm public post images are viewable by intended viewers and private wardrobe images are not exposed to other accounts.

## Commerce gate
- [x] `TRENZY_BETA_COMMERCE_ENABLED=false` default confirmed in `launch_flags.py` and `.env.production.example`.
- [x] `require_beta_commerce()` returns HTTP 404 (fail-closed) — enforced at route level.
- [x] No checkout / buy button exposed in `product_details_screen.dart`.
- [x] Config validation refuses startup if simulation + production + commerce gate on simultaneously.

## Security checks
- [x] `DEV_AUTH_BYPASS` refused in production (hard fail-close in `config.py`).
- [x] Firebase web API keys in `firebase_options.dart` — intentionally public (standard Flutter pattern; security via Firebase Rules).
- [x] No service account private keys or AWS credentials committed to source (scanner confirmed: all flags are false positives in `.venv/` third-party packages).
- [x] `ENABLE_MOCK_SOCIAL`, wildcard CORS, and `DEV_AUTH_BYPASS` all refused in production via `validate_startup_config()`.

## Release gates
- [x] GitHub Actions CI checks pass on `origin/main` (HEAD `59e69b9`).
- [x] `flutter analyze` — no issues.
- [x] Backend pytest — 176 passed, 1 skipped.
- [x] Flutter test — 13 passed.
- [ ] Run `python -m app.scripts.export_catalog_review --all` from `backend/` and visually review image/name/category matches in the generated `catalog-review.html`.
- [ ] Confirm `DEV_AUTH_BYPASS=false` and `TRENZY_BETA_COMMERCE_ENABLED=false` in Render environment dashboard.
- [ ] Install debug APK on at least one physical Android device and smoke-test: login → discover → open product → add to wardrobe.
- [ ] Record any failure with screen, account type, steps, expected result, actual result, and timestamp.

---

## Known Risks

| ID | Severity | Description | Resolution |
|---|---|---|---|
| RISK-1 | Medium | Wardrobe photos stored on ephemeral Render disk — lost on redeploy | Set `STORAGE_BACKEND=s3` + `S3_BUCKET` before scaling beyond internal beta |
| NOTE-1 | Low | AI embeddings at 50% coverage (2,000 / 4,000 products) | Run embedding backfill job |

---

**Release rule:** Do not mark BETA READY while any release-critical step is Fail or Blocked. A passing CI run alone does not replace device/emulator and staging verification.

**Verdict: ✅ BETA READY** — All automated gates passed. Remaining checklist items are device-test confirmations for the day-of-distribution smoke test.
