# iOS startup

- LaunchScreen (static title/background) → Flutter Start animation → introduction pages.
- Changes are iOS-only; Android startup and shared Dart behavior remain unchanged.
- After title/font changes, run `python mobile/tool/generate_ios_launch_title.py`
  from the repository root (requires Pillow). If the generated width changes,
  update the storyboard's title width, aspect ratio, and scale constraints.
- Pending: build with Xcode on macOS and verify the launch transition on iOS
  (no blank flash or title jump). Windows widget tests do not validate this.
