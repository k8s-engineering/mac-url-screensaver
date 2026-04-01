# Contributing

Thanks for contributing to `mac-url-screensaver`.

## Prerequisites

- macOS
- Xcode and command line tools

## Local Build

```bash
cd WebViewScreenSaver
xcodebuild -project WebViewScreenSaver.xcodeproj \
  -scheme WebViewScreenSaver \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

## Install Local Build

```bash
cd WebViewScreenSaver
mkdir -p build
xcodebuild -project WebViewScreenSaver.xcodeproj \
  -scheme WebViewScreenSaver \
  -configuration Release clean archive \
  -archivePath build/build.xcarchive \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES
cp -pr "$(find build -iname '*.saver')" ~/Library/Screen\ Savers/
```

## Development Guidelines

- Keep changes focused and small.
- Update `README.md` when behavior or configuration changes.
- Add or update logs for behavior that is hard to debug at runtime.
- Preserve existing user settings and avoid destructive migrations.

## Pull Requests

Please include:

- What changed
- Why it changed
- How it was tested
- Any screenshots for UI-related updates

