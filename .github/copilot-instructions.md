## Quick orientation for AI coding agents

This Flutter app (Android-focused) implements a biometric/authentication prototype using Firebase (Auth, Firestore). Below are the concrete, discoverable facts and patterns to make productive edits quickly.

### Big picture
- Flutter mobile app (lib/) with Firebase backend. Main entry: `lib/main.dart` — it initializes Firebase and checks `FirebaseAuth.instance.currentUser` to decide app start (see email verification gating).
- Auth + user persistence: `lib/auth/auth_service.dart` handles Firebase Auth and writes/reads a user document in Firestore `users` collection. The canonical user shape is `lib/models/user_model.dart`.
- UI is directory-organized: `lib/screens/` (pages), `lib/widgets/` (reusable UI), `lib/constants/` (colors), `lib/utils/` (validators), and `lib/auth/` (auth logic + screens).
- Firebase configuration artifacts: `lib/firebase_options.dart` (generated), and Android `app/google-services.json` exist — modify these only when you know the Firebase project changes.

### Important files to check before editing behavior
- `lib/main.dart` — Firebase initialization and the initial auth/email-verified check. Keep `WidgetsFlutterBinding.ensureInitialized()` and `await Firebase.initializeApp()` before any Firebase calls.
- `lib/auth/auth_service.dart` — single source for signup/login/logout, and Firestore user doc creation. When adding user fields, update `UserModel` and the Firestore mapping here.
- `lib/models/user_model.dart` — canonical schema for app users. Used across UI routing and membership checks.
- `lib/screens/*` — UI entry points. Look for routing and where `AuthService` methods are called (e.g., signup/login flows).

### Patterns & conventions observed (do not change lightly)
- File naming: snake_case filenames, Flutter/Dart idioms. Classes use UpperCamelCase (standard Dart style).
- Auth flow: async methods in `AuthService` return `UserModel?` or `null` on failure. UI reacts to nulls as failure states. Error handling is basic (prints errors); follow existing pattern when adding small changes. If you improve error handling, do it consistently across `lib/auth/*`.
- Firestore collection: users are stored under `users` collection keyed by Auth UID. Keep this consistent when integrating services that reference user docs.
- Theme constants: colors and text styles are centralized in `lib/constants/colors.dart` and used by `lib/main.dart` to build themes.

### Build / run / test (what actually works here)
- Install deps: `flutter pub get` (project uses Flutter SDK and Dart >= 3.9.2 per `pubspec.yaml`).
- Run on device/emulator: `flutter run` (Android-specific config exists under `android/` and `app/google-services.json`).
- Tests: `flutter test` — there is a `test/widget_test.dart` present.

### Integration points and external dependencies
- Firebase services: `firebase_core`, `firebase_auth`, `cloud_firestore` (see `pubspec.yaml`). Changes that touch authentication must respect the combination of `lib/firebase_options.dart` and `app/google-services.json`.
- No dependency injection/framework is used (no Provider/Bloc visible). Code directly calls `AuthService` from UI screens — search for direct `AuthService()` or method calls.

### Quick editing examples (concrete snippets to reference)
- To follow the email verification flow, prefer the pattern used in `lib/main.dart`:
  - Call `await user.reload()` before checking `user.emailVerified`.
- To add a new field to user documents:
  1. Update `lib/models/user_model.dart` with the new field and toMap/fromMap.
  2. Update `lib/auth/auth_service.dart` where `UserModel` is created/saved and where `UserModel.fromMap` is used.

### What NOT to change without broader review
- Project-level Firebase config files (`lib/firebase_options.dart`, `app/google-services.json`). These are tied to a Firebase project.
- Theme token names in `lib/constants/colors.dart` without coordinating UI tests — the app relies on these tokens across many screens.

### Where to look first when debugging
- Auth/login issues: `lib/auth/auth_service.dart` → then `lib/screens/login_screen.dart` / `signup_screen.dart`.
- Routing or startup problems: `lib/main.dart` and `lib/screens/loading_screen.dart`.
- Firestore data shape issues: `lib/models/user_model.dart` and any code that calls `.toMap()` / `.fromMap()`.

If anything above is unclear or you want me to include more examples (e.g., common UI call sites for AuthService, or a small checklist for adding new Firestore fields), tell me which area to expand and I will update this file.
