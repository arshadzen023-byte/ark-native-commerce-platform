# GlowHit App Bar Builder validation

- App Bar configuration is saved in the existing Designer JSON contract.
- Voice Search uses the device speech recognition service and supports English (India) or Hindi (India) when available.
- Android microphone permission and Android 11+ recognition-service visibility are added by the release workflow.
- Run `flutter analyze --no-fatal-infos`, `flutter test test/app_bar_builder_test.dart`, `flutter test --reporter expanded`, and `flutter build apk --release`.
- Keep the existing `com.ark.glowhit` application ID and `GlowHit` app label.
