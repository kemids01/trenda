# Building trenda_frontend for iPhone

iOS apps can only be compiled on a Mac with Xcode. Everything that can be
prepared on Windows is already in `ios/` (2026-09-30). This is the Mac part.

## What is already set up

| Item | Value |
|---|---|
| Bundle ID | `com.example.trendaFrontend` (matches the iOS app registered in Firebase `trendalocal`) |
| Firebase iOS app | `1:431491551192:ios:d5a53eb77007389cea6cad` — `ios/Runner/GoogleService-Info.plist` + `lib/firebase_options.dart` |
| Minimum iOS | 15.5 (mobile_scanner's ML Kit needs it) |
| Google Sign-In | `GIDClientID` + the `REVERSED_CLIENT_ID` URL scheme in `Info.plist` |
| Permissions | camera, photos, location (when in use), microphone + speech (voice search) |
| Push | `remote-notification` background mode; Firebase swizzling left ON |

## 1. Mac requirements (once)

- macOS with **Xcode 16+** (App Store), then `sudo xcodebuild -license accept`
- **Flutter 3.38.x** (same as Windows: `flutter --version`)
- **CocoaPods**: `sudo gem install cocoapods` (or `brew install cocoapods`)
- An **Apple ID** added in Xcode ▸ Settings ▸ Accounts. A free Apple ID can
  install on your own iPhone for 7 days; TestFlight/App Store needs the
  paid Apple Developer Program (US$99/year).

## 2. Copy the code to the Mac

The app depends on `../trenda_shared` by path, so copy **both** folders side by
side (USB drive / AirDrop — the repos have no remote by design):

```
TrendaV3/
  trenda_frontend/
  trenda_shared/
```

Also copy `trenda_frontend/.env` (it is gitignored but bundled as an asset).

## 3. Build

```bash
cd TrendaV3/trenda_frontend
flutter clean && flutter pub get
cd ios && pod install --repo-update && cd ..
open ios/Runner.xcworkspace          # the .xcworkspace, NOT .xcodeproj
```

In Xcode ▸ Runner target ▸ **Signing & Capabilities**: tick *Automatically
manage signing* and pick your Team.

Run on a plugged-in iPhone (enable Developer Mode on the phone when asked):

```bash
flutter run --release
```

Release build for TestFlight (paid account):

```bash
flutter build ipa --release
# upload build/ios/ipa/*.ipa with Xcode ▸ Organizer or Transporter
```

## 4. Push notifications (paid account only)

1. Xcode ▸ Signing & Capabilities ▸ **+ Push Notifications** (adds the
   `aps-environment` entitlement — left out on purpose, because a free
   Apple ID cannot sign it and every build would fail).
2. developer.apple.com ▸ Keys ▸ create an **APNs key** (.p8).
3. Firebase console ▸ trendalocal ▸ Project settings ▸ Cloud Messaging ▸
   Apple app `com.example.trendaFrontend` ▸ upload the .p8 with its Key ID and
   Team ID.

## 5. Before the App Store

- **Bundle ID**: Apple will not accept `com.example.*`. Pick a real one
  (e.g. `ph.trenda.customer`), register it as a NEW iOS app in Firebase,
  download its `GoogleService-Info.plist`, and update `PRODUCT_BUNDLE_IDENTIFIER`
  (3 places in `project.pbxproj`), `firebase_options.dart` (appId, apiKey,
  iosClientId, iosBundleId) and the `GIDClientID` + URL scheme in `Info.plist`.
- `NSAllowsArbitraryLoads` is still `true` in `Info.plist`; App Review asks why.
  The backend is HTTPS, so it can be removed once nothing loads plain `http://`.
- App icon: `ios/Runner/Assets.xcassets/AppIcon.appiconset` still holds
  Flutter's default icon.

## Common errors

| Error | Fix |
|---|---|
| `CocoaPods could not find compatible versions` | `cd ios && pod repo update && pod install` |
| `...requires a higher minimum iOS deployment version` | keep Podfile + project at 15.5 |
| Google sign-in: "missing support for the following URL schemes" | the URL scheme in `Info.plist` must equal `REVERSED_CLIENT_ID` |
| "Untrusted Developer" on the phone | iPhone ▸ Settings ▸ General ▸ VPN & Device Management ▸ trust |
