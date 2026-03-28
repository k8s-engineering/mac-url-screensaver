# WebViewScreenSaver (Multi-Screen Fork)

A macOS screen saver that displays web pages, with **per-screen URL support** for multi-monitor setups.

Forked from [liquidx/webviewscreensaver](https://github.com/liquidx/webviewscreensaver) and extended to support up to 6 independent screens, each showing different web content.

## What's Different

| Feature | Original | This Fork |
|---------|----------|-----------|
| Multiple screens | Same content on all | Different URLs per screen |
| Screen detection | None | Auto-detects displays |
| Config UI | Single URL list | Screen selector + per-screen lists |
| Max screens | N/A | 6 |

### How It Works

macOS creates one `ScreenSaverView` per connected display. This fork:

1. **Detects** which physical screen each view is running on using `CGDirectDisplayID` matching
2. **Loads** the per-screen URL list for that display (or falls back to the global list)
3. **Provides** a screen selector in the configuration sheet so you can assign different URLs to each screen

### Use Case: Grafana Dashboards on 3 TVs

Configure each screen to show a different Grafana playlist:
- **Screen 1 (TV Left)**: `https://grafana.home/playlists/play/1?kiosk=tv` — Infrastructure
- **Screen 2 (TV Center)**: `https://grafana.home/playlists/play/2?kiosk=tv` — Application metrics
- **Screen 3 (TV Right)**: `https://grafana.home/playlists/play/3?kiosk=tv` — Logs / Alerts

Set duration to `-1` for each to let Grafana handle its own rotation, or set positive values to have the screensaver cycle through a list of URLs per screen.

## Installation

### From Source (requires Xcode)

```bash
cd web-view-screensaver/WebViewScreenSaver
mkdir build
xcodebuild -project WebViewScreenSaver.xcodeproj \
  -scheme WebViewScreenSaver \
  -configuration Release clean archive \
  -archivePath build/build.xcarchive \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES > build/build.log
cp -pr "$(find build -iname '*.saver')" ~/Library/Screen\ Savers/
```

### Quick Install Script

```bash
cd web-view-screensaver
bash install-from-source.sh
```

## Configuration

1. Open **System Settings** → **Screen Saver** → select **WebViewScreenSaver**
2. Click **Options...**
3. Check **Per-screen URLs** to enable independent screen configuration
4. Select a screen from the dropdown (e.g., "Screen 1 (Built-in Retina Display)")
5. Add URLs for that screen
6. Repeat for each screen
7. Click **OK** to save

### Scripted Configuration

```bash
# Show current settings
/usr/libexec/PlistBuddy -c 'Print' ~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/ByHost/WebViewScreenSaver.*.plist
```

### Fetch URLs from JSON

Enable the **Fetch URLs** option and point it at a JSON endpoint:

```json
[
  { "url": "https://grafana.home/d/abc?kiosk=tv", "duration": 300 },
  { "url": "https://grafana.home/d/def?kiosk=tv", "duration": 300 }
]
```

## Files Changed from Upstream

| File | Change |
|------|--------|
| `WVSSScreenIdentifier.h/.m` | **NEW** — Screen detection utility |
| `WVSSConfig.h/.m` | Per-screen address storage + `perScreenMode` flag |
| `WebViewScreenSaverView.h/.m` | Screen detection on `startAnimation`, per-screen URL loading |
| `WVSSConfigController.h/.m` | Screen selector popup + per-screen checkbox in config sheet |
| `project.pbxproj` | Added new source files to build |

## License

Code is licensed under the [Apache License, Version 2.0](LICENSE).
