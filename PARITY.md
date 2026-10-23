# Android ↔ iOS parity

Every Android source file and where its behavior lives on iOS. Copy, colors, sizes, Firestore
paths and Cloud Function payloads are carried over as-is. Ported from Android `main` at
`49db287` (Oct 15, 2026: accessibility pass, feedback, Crashlytics, export, TTS).

## App shell

| Android | iOS | Notes |
| --- | --- | --- |
| `ProjectLanguage.kt` | `App/AppDelegate.swift` | App Check before Firebase, Crashlytics, notifications |
| `MainActivity.kt` (`MainScreen`) | `Navigation/RootView.swift` (`MainScreen`, `MainTabsView`) | Same start-destination rules, splash until the session check finishes, late "needs username" redirect, permission ask once, notification → Friends |
| `navigation/NavGraph.kt` | `Navigation/RootView.swift` | Onboarding → Login → Username → Learning languages → tabs. Log out restarts the whole UI (`AppRestarter`), like relaunching the activity |
| `navigation/Screen.kt`, `BottomNavigationBar.kt` | `Navigation/BottomNavigationBar.swift` | Clay pill, badge with "99+", hairline top border |
| `navigation/StudySelection.kt` | `Navigation/StudySelection.swift` | Session routes; Library selection kept in memory |
| `AppCheckSetup.kt` (debug) | `AppCheckSetup` in `AppDelegate.swift` | Debug provider in debug builds; App Attest/DeviceCheck in release |
| `CrashReporting.kt` | `CrashReporting` in `AppDelegate.swift` | uid + `debug_build` key |
| `AppModule.kt` | `Model/FirebaseHelpers.swift` (`Backend`) | Functions region `us-central1` |

## Data and models

| Android | iOS |
| --- | --- |
| `data/Phrase.kt`, `FriendsModels.kt`, `OnboardingPrefs.kt` | `Data/` |
| `model/AuthManager.kt` | `Model/AuthManager.swift` (same friendly error messages) |
| `model/GoogleSignIn.kt` | `Model/GoogleSignInHelper.swift` (GoogleSignIn-iOS) |
| `model/FcmTokenRegistrar.kt` | `Model/FcmTokenRegistrar.swift` (`users/{uid}/private/account.fcmTokens`, 3 s logout timeout) |
| `model/TranslationRepository.kt` | `Model/TranslationRepository.swift` (warm-up, 200-entry LRU cache, error mapping) |
| `model/PhraseRepository.kt` | `Model/PhraseRepository.swift` (identical `phraseKey` SHA-256, transaction save, restore for Undo) |
| `model/StudyActivityRepository.kt` | `Model/StudyActivityRepository.swift` (`studyDays/{yyyy-MM-dd}`) |
| `model/FriendRepository.kt`, `SuggestionRepository.kt` | same names in `Model/` |
| `model/UserProfileRepository.kt` | `Model/UserProfileRepository.swift` (username claim/change transactions, validation rules) |
| `model/LanguagePrefsRepository.kt` | `Model/LanguagePrefsRepository.swift` (device copy + `users/{uid}/private/languages`) |
| `model/Languages.kt` | `Model/Languages.swift` (generated from the Kotlin table: 192 languages, aliases, romanization sets, search ranking) |
| `model/RomanizationHelper.kt` | `Model/RomanizationHelper.swift` (same Sinhala tables, verified identical; same ICU transforms) |
| `model/SpeechRepository.kt` | `Model/SpeechRepository.swift` (`speak` / `ttsLanguages`, cached MP3s, tap again to stop) |
| `model/PhraseExporter.kt` | `Model/PhraseExporter.swift` (A4 PDF, same layout/fonts/colors, text export, .txt over 50,000 chars) |
| `notifications/*`, `messaging/*` | `Notifications/` |

## View models

All of `viewmodel/` → `ViewModels/` with the same state and logic: Session, Login, UsernameSetup,
LearningLanguages, Translation (300 ms typing pause, cached results, "Saved" state), Library
(filters, optimistic favorite, delete + undo, export), Friends (+ `friendlyError`), Profile
(streak, week, stats, achievements, edit profile, photo, delete account, log out), Badge,
SuggestToFriend, Feedback, Speech (folded into `SpeechRepository`).

## Screens and components

| Android | iOS |
| --- | --- |
| `ui/screens/OnboardingScreen.kt` | `UI/Screens/OnboardingScreen.swift` (5 pages, art on the 390×420 frame) |
| `LoginScreen.kt` | `LoginScreen.swift` |
| `UsernameSetupScreen.kt` | `UsernameSetupScreen.swift` |
| `LearningLanguagesScreen.kt` | `LearningLanguagesScreen.swift` |
| `TranslateScreen.kt` + `components/TranslateBox.kt` | `TranslateScreen.swift` + `Components/TranslateBox.swift` |
| `LibraryScreen.kt` | `LibraryScreen.swift` |
| `StudyScreen.kt`, `StudySessionScreen.kt` | same names |
| `FriendsScreen.kt` | `FriendsScreen.swift` |
| `ProfileScreen.kt` | `ProfileScreen.swift` |
| `components/LanguagePicker.kt` | `Components/LanguagePicker.swift` (badges + legend) |
| `components/SuggestToFriendSheet.kt`, `FeedbackSheet.kt`, `ExportPhrasesSheet.kt` | same names |
| `components/PhraseCard.kt`, `PhraseActionButtons.kt` (`AppButton`) | `PhraseCard.swift`, `AppButton.swift` |
| `components/AuthScaffold.kt` | `AuthScaffold.swift` (+ `OutlinedField`, the Material text field look) |
| `components/AppToast.kt`, `StateViews.kt`, `AppHeader.kt`, `Kato.kt`, `UserPhotos.kt`, `Usernames.kt`, `SpeakButton.kt`, `SheetDragHandle.kt` | same names |
| `ui/theme/Color.kt`, `Type.kt`, `Theme.kt` | `UI/Theme/Colors.swift`, `Typography.swift` (every light/dark token) |
| `res/drawable/kato_*.xml`, `vadan_mark.xml`, `ic_google_logo.xml` | `Assets.xcassets` (converted to SVG, kept as vectors) |
| `res/font/*` | `Resources/Fonts/` (DM Sans files renamed internally so iOS can load all four weights) |
| Splash / launcher icon | Launch screen (`UILaunchScreen`) + `AppIcon` (same crop as the adaptive icon) |

## Where iOS necessarily differs

- **Material controls → iOS equivalents.** Bottom sheets are iOS sheets (same 28 pt corners, handle
  and content). Dialogs are drawn like Material's (title, text, buttons on the right) so the
  delete-account dialog can keep its inline error and spinner. The Library's swipe-to-delete uses
  iOS's list swipe action (full swipe deletes, or swipe and tap Delete), and VoiceOver gets a
  "Delete …" action. The Favorites switch is an iOS toggle.
- **Icons** are SF Symbols picked to match the Material icons.
- **Italic** romanizations and quotes are slanted in code, since DM Sans has no italic file (Android
  fakes it the same way).
- **No system back button.** Every screen that Android lets you leave with Back already has an
  on-screen back or close button.
- **Push notifications** need APNs, which needs a paid Apple Developer account (see README).
- **Status bar.** Light icons on the auth screens' clay header, system default elsewhere (as on Android).
- **Speech errors** show as a short dark toast, like Android's system Toast.
- **Feedback** reports the device as e.g. "Apple iPhone16,2, iOS 18.0".
- **Line heights.** SwiftUI can't tighten line height below a font's natural spacing, so multi-line
  Poppins titles sit a little taller than on Android.
