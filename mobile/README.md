# TwoSpoon mobile

See the [project README](../README.md) for backend setup, emulator/device networking, protocol, tests and debug controls.

```sh
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000
flutter analyze
flutter test
flutter build apk --release
```
