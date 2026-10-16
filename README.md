# Vadan for iOS

The iOS version of Vadan, written in SwiftUI. It mirrors the Android app
([Project-Language](https://github.com/Mihilih/Project-Language)) screen for screen and uses the same
Firebase project, Firestore data and Cloud Functions
([project-language-functions](https://github.com/Mihilih/project-language-functions)).

- iOS 17+, iPhone
- Bundle ID `com.mihilih.projectlanguage` (same as Android)
- Firebase iOS SDK (Auth, Firestore, Functions, Messaging, App Check, Crashlytics) and Google Sign-In, via Swift Package Manager
- The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen), so it isn't committed

## First-time setup (on your Mac)

1. **Register the iOS app in Firebase.** Firebase console → Project settings → *Add app* → iOS.
   Use bundle ID `com.mihilih.projectlanguage`. Download **GoogleService-Info.plist** and put it at
   `Vadan/GoogleService-Info.plist`. (Google sign-in is already enabled for the project, so the file
   includes the client IDs Google Sign-In needs.)
2. **Install XcodeGen:** `brew install xcodegen`
3. **Generate the project:** `./scripts/setup.sh`
   This copies Google Sign-In's URL scheme out of the plist into `Config/Google.xcconfig`, then
   generates `Vadan.xcodeproj`.
4. **Open `Vadan.xcodeproj`**. Xcode downloads the Swift packages the first time (this takes a few minutes).
5. **Signing:** select the *Vadan* target → *Signing & Capabilities* → pick your team. A free
   Personal Team works for the Simulator.
6. **Run** on an iPhone simulator (⌘R).
7. **Register the App Check debug token.** On first launch the Xcode console prints
   `Firebase App Check debug token: …`. Add it in Firebase console → App Check → Apps → the iOS app →
   *Manage debug tokens*. Until you do, translating, audio and other Cloud Functions calls are
   rejected ("This device couldn't be verified…"), because App Check is enforced on every callable.

Re-run `./scripts/setup.sh` whenever you add or remove Swift files, or after downloading a new
`GoogleService-Info.plist`.

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
