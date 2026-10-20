# Trenzy Beta Verification Checklist

Run this once against the same APK/build after the beta-fix PR is merged. Record Pass / Fail / Blocked and attach screenshots for failures.

## Build and launch
- [ ] Build APK using `flutter build apk --debug --dart-define=TRENZY_API_BASE_URL=https://trenzy-staging-api.onrender.com`.
- [ ] Confirm the build launches and points to the staging API, not a local or production URL.
- [ ] Fresh install, sign up, verify age/email as required, complete onboarding, force-close, reopen, and confirm session persistence.
- [ ] Existing account login and logout work; invalid credentials show a readable error and do not leave an endless spinner.

## Discover and catalog
- [ ] Discover loads without large blank gaps when campaign, persona, swipe picks, categories, or trending data are empty.
- [ ] Category labels are canonical: Tops, Bottoms, Footwear, Dresses, Outerwear, Accessories.
- [ ] Open at least 10 products across categories and visually compare each image against its name/category; note mismatches rather than guessing categories.
- [ ] Broken/slow image URLs show a fallback and do not break scrolling.
- [ ] Unknown/composite catalog records are not presented as confidently classified individual products.
- [ ] Price-less products never display ₹0 or a fabricated price.
- [ ] Search, category filtering, product detail, wishlist add/remove, and back navigation work.

## Wardrobe and Outfit Builder
- [ ] Add a wardrobe item with a gallery photo; upload succeeds, preview appears, save succeeds, and the same image remains after leaving and reopening the closet.
- [ ] Add an item with a URL and verify its image; try an invalid URL and confirm readable feedback.
- [ ] Try adding the same item twice; no duplicate record is created and the message is understandable.
- [ ] Success/error feedback is readable above the bottom navigation and is not clipped.
- [ ] Edit an item and verify name/category/image persist after refresh.
- [ ] Build an outfit from at least two wardrobe items, save, leave, reopen, edit, and save again; item images and selections persist.
- [ ] Confirm Outfit Builder header and save control fit on a narrow phone without overflow.
- [ ] Remove an item from the canvas and confirm the saved outfit updates.

## AI and social
- [ ] AI Stylist opens with a clean header, sends a prompt, displays a reply or a clear retryable error, and does not stay loading forever.
- [ ] Posts/feed content loads; open a post, view its image, and confirm any supported like/save action persists.
- [ ] Use two separate test accounts to verify follow/friend/Blend/chat actions and confirm each account sees only its own private wardrobe.
- [ ] Confirm public post images are viewable by intended viewers and private wardrobe images are not exposed to other accounts.

## Catalog cleanup and release gates
- [ ] Run the catalog quarantine script in dry-run mode and save the output before applying any changes.
- [ ] Review the proposed records and backup plan; do not apply JSON/database cleanup until the dry-run counts and target environment are confirmed.
- [ ] Verify the known timed-out catalog image again and record its result.
- [ ] Confirm post-merge GitHub Actions checks pass.
- [ ] Record any failure with screen, account type, steps, expected result, actual result, and timestamp.

**Release rule:** Do not mark BETA READY while any release-critical step is Fail or Blocked. A passing CI run alone does not replace device/emulator and staging verification.
