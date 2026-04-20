# iOS OAuth Setup

Thesa's Flutter project does not currently ship a materialized
`ui/ios/Runner/` Xcode project — desktop (Linux/macOS/Windows) and
Android are the only active targets. When iOS support is materialized
via `flutter create --platforms=ios .`, the `Info.plist` emitted into
`ui/ios/Runner/Info.plist` must carry the OAuth redirect scheme below
so `flutter_appauth` can deliver authorization-code callbacks back to
the app.

The scheme must match `redirectScheme` in
`lib/core/auth/runtime_provider.dart` (`com.antinvestor.thesa`) and the
Hydra client's registered redirect URI.

## Required `Info.plist` additions

Insert inside the top-level `<dict>` alongside the existing
`CFBundleIdentifier`, `CFBundleName`, etc.:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.antinvestor.thesa</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.antinvestor.thesa</string>
        </array>
    </dict>
</array>
```

## Why this is not checked in today

`flutter create` generates boilerplate differently across Flutter
versions (asset catalogues, Xcode settings, Podfile pinning). Rather
than freeze a version-coupled `ios/` directory that drifts from the
Flutter toolchain the developer has installed locally, we keep iOS
setup declarative — materialize the platform, then apply the snippet
above.

## Post-setup verification

After `flutter create --platforms=ios .`:

1. Add the `CFBundleURLTypes` entry above.
2. `cd ios && pod install`.
3. `flutter run -d ios`.
4. Trigger sign-in; `ASWebAuthenticationSession` should open, complete,
   and return control to the app with the authenticated state flipping
   visible in the UI.

See `ui/macos/Runner/Info.plist` for the equivalent macOS wiring,
already in place.
