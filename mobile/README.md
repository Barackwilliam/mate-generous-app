# Mate Generous: Android app (Flutter)

```bash
flutter pub get
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # emulator → local backend
```

`API_BASE_URL` points the app at the backend. Codemagic sets it for test builds (see `../codemagic.yaml`).

Screens: Home (Tonight's Message + admin-configured sections), Categories & series, Search, Reader (Scripture, text, application, prayer, next/previous, bookmark, favourite, share excerpt, font size, dark mode), My Library (history, bookmarks, favourites, owned), Account (sign in with email or phone, register, reading settings).

Payment screens wait for the Google Play billing decision (see `../docs/PAYMENTS.md`).
