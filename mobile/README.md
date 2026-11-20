# Mate Generous: Android app (Flutter)

Design: **"Nuru ya Msalaba"**, night blue with the warm gold of dawn and the cross as the mark. The reader uses cream "paper" in light mode. See `../docs/screenshots/`.

```bash
flutter pub get
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # emulator → local backend
```

| Screen | File |
| --- | --- |
| Home: Tonight's Message, continue reading, departments, admin rows | `lib/screens/home_screen.dart` |
| Explore and category/series pages | `explore_screen.dart`, `category_screen.dart` |
| Search (title, Scripture, keyword, series, topic, author; filter by type) | `search_screen.dart` |
| Reader (Scripture, text, application, prayer, next/previous, save, favourite, share excerpt, text size, dark/light) | `reader_screen.dart` |
| Audio player (background playback, lock-screen controls, ±15s, speed, next episode) and Listen tab | `listen_screen.dart`, `lib/audio/` |
| My Library (streak, history, saved, favourites, owned) | `library_screen.dart` |
| Plans (from the subscription engine; payment comes in the next step) | `plans_screen.dart` |
| Account (profile, plan, language, appearance, text size) and sign in / register | `account_screen.dart`, `auth_screen.dart` |

**Languages:** every label is in `lib/i18n/strings.dart` (Swahili and English). The SW | EN switch is on every main screen; in the reader it is under **Aa**. The choice is remembered. Devotionals stay in the language they were written in; category names switch when the admin fills in the English name.

**Fonts:** Lora and Plus Jakarta Sans are bundled (`assets/fonts`, SIL Open Font License), so they work offline.
