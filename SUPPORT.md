# Support

## Getting Help

Use GitHub Issues for:

- Bug reports
- Feature requests
- Questions about setup and usage

## Before Opening an Issue

- Confirm you are using the latest commit on `main`.
- Include your macOS version.
- Include monitor/display setup details.
- Include relevant configuration values.

## Collecting Logs

The screen saver writes logs to:

`~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Logs/com.apple.ScreenSaver.Engine.legacyScreenSaver/wvss.log`

Quick command:

```bash
tail -n 200 ~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Logs/com.apple.ScreenSaver.Engine.legacyScreenSaver/wvss.log
```

