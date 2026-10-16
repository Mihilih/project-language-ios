# Vadan for iOS

The iOS version of Vadan, written in SwiftUI. It mirrors the Android app
([Project-Language](https://github.com/Mihilih/Project-Language)) screen for screen and uses the same
Firebase project, Firestore data and Cloud Functions
([project-language-functions](https://github.com/Mihilih/project-language-functions)).

- iOS 17+, iPhone
- Bundle ID `com.mihilih.projectlanguage` (same as Android)
- Firebase iOS SDK (Auth, Firestore, Functions, Messaging, App Check, Crashlytics) and Google Sign-In, via Swift Package Manager
- The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen), so it isn't committed

## Running it on a Mac

The Firebase config (`Vadan/GoogleService-Info.plist`) and Google Sign-In's URL scheme
(`Config/Google.xcconfig`) are already in the repo. The only thing not in it is the App Check
debug token (step 6), because it's a credential.

1. Install **Xcode** from the App Store and open it once.
2. Get the code (clone, or download the ZIP of the branch from GitHub) and open Terminal in the folder.
3. Run `./scripts/setup.sh`. It uses XcodeGen if installed, otherwise downloads it into `.tools/`
   (no Homebrew needed), then generates `Vadan.xcodeproj`.
4. `open Vadan.xcodeproj` and wait for Xcode to fetch the Swift packages.
5. *Vadan* target → *Signing & Capabilities* → *Team*: add your Apple ID and pick its Personal Team.
6. *Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables → +*. Name:
   `FIRAAppCheckDebugToken`, value: the debug token from Firebase console → App Check → Vadan (iOS)
   → *Manage debug tokens*. Without it, translation, audio and friends are rejected by App Check.
   (Re-running `setup.sh` regenerates the scheme, so add it again after that.)
7. Choose an iPhone simulator and press ⌘R.

Re-run `./scripts/setup.sh` whenever you add or remove Swift files.

Revoke the debug token in that same Firebase menu when it's no longer needed.

## What needs a paid Apple Developer account

Everything works in the Simulator with a free account except:

- **Push notifications.** These need APNs: add the *Push Notifications* capability in Xcode, upload
  an APNs key in Firebase console → Project settings → Cloud Messaging, and test on a real iPhone.
  The app already registers the FCM token, shows notifications while open, and opens the right
  Friends section when one is tapped. Until then the permission prompt still appears, but nothing
  arrives.
- **App Check in release builds** uses App Attest (add the *App Attest* capability). Debug builds use
  the debug provider above.
- **TestFlight / App Store.**

## How it maps to Android

| Android (Kotlin) | iOS (Swift) |
| --- | --- |
| `model/*Repository.kt`, `AuthManager`, `Languages`, `RomanizationHelper`, `PhraseExporter` | `Vadan/Model/` |
| `data/` | `Vadan/Data/` |
| `viewmodel/` | `Vadan/ViewModels/` |
| `ui/components/` | `Vadan/UI/Components/` |
| `ui/screens/` | `Vadan/UI/Screens/` |
| `ui/theme/` (Vadan palette, Poppins + DM Sans) | `Vadan/UI/Theme/` |
| `navigation/` + `MainActivity` | `Vadan/Navigation/` |
| `ProjectLanguage.kt`, App Check, Crashlytics, FCM service | `Vadan/App/`, `Vadan/Notifications/` |

`PARITY.md` lists every Android feature and where it lives on iOS, plus the few places iOS
necessarily behaves differently.

Things that must stay identical on both platforms:

- Firestore paths and field names (`users/{uid}/phrases`, `isFavorite`, `timestamp` in milliseconds, …).
- `PhraseRepository.phraseKey`: the SHA-256 id that stops the same phrase being saved twice, so a
  phrase saved on one platform is recognised as a duplicate on the other.
- `Languages`: the 192-language table, aliases and romanization lists. Generate it from Android's
  `Languages.kt` rather than editing by hand.
