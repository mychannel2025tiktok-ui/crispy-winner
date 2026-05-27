# PlateLens

PlateLens is a private iPhone calorie tracker starter app. It is built with SwiftUI and is designed for photo-based meal analysis, manual corrections, daily totals, and local history.

This repository is an Xcode project. To create an `.ipa`, open it on macOS with Xcode, add your Apple developer signing team, set your API key in the app settings screen, archive the app, and export it.

## What is included

- Photo picker for meal images.
- Camera capture on real iPhones.
- OpenAI Vision meal analysis service with the API key stored in Keychain.
- Editable model name in Settings.
- JSON-only parsing into calories, protein, carbs, fat, confidence, assumptions, and ingredients.
- Manual editing before saving a meal.
- Manual meal entry when no photo is available.
- Daily log with macro totals.
- Editable daily calorie and macro goals.
- Goal progress bars on Scan and Diary.
- Last-7-days calorie chart.
- Day-grouped history with tap-to-edit saved meals.
- CSV export from Settings.
- Local history deletion with confirmation.
- Local persistence with `UserDefaults`.
- No API key committed to source code.

## Build IPA

1. Open `PlateLens.xcodeproj` in Xcode on macOS.
2. Select the `PlateLens` target.
3. In Signing & Capabilities, choose your Apple Developer Team.
4. Change the Bundle Identifier if needed, for example `com.yourname.platelens`.
5. Run the app on your iPhone once.
6. In the app, open Settings and paste your API key.
7. Optionally edit the model name in Settings.
8. Adjust your daily calorie and macro goals in Settings.
9. In Xcode, choose Product > Archive.
10. In Organizer, choose Distribute App and export an `.ipa`.

Windows note: this workspace can create the Xcode project, but the final signed `.ipa` requires macOS, Xcode, and Apple signing.

## API key

Paste your key in the in-app Settings screen. The app saves it in the iOS Keychain under:

`com.platelens.openai.apiKey`

## Notes

Photo calorie analysis is an estimate. The app intentionally shows confidence, assumptions, and editable fields so you can correct portions before saving.

For App Store-style distribution, use your own backend proxy instead of putting a production API key directly on devices. For personal side-loaded use, the in-app Keychain approach is simple and practical.
