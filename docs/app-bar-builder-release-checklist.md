# GlowHit App Bar Builder release checks

- Keep the original ARK Designer UI and JSON contract; add only the new App Bar section and root app_bar field.
- Preserve Margin, Padding, Dimensions, checkout, product layout, navigation, per-page Floating Action Buttons, app name GlowHit and application ID com.ark.glowhit.
- Run Flutter Analyze, App Bar Builder widget tests, the full Flutter test suite and the Android release APK build.
- Verify Voice Search uses RECORD_AUDIO and Android 11+ recognition-service package visibility.
- Verify App Bar actions navigate from main tabs, product detail and nested pages.
