# Mumutte project instructions

- Keep this a native SwiftUI menu bar app for macOS 13 and later.
- Enforce input gain only when Core Audio reports the volume property as available and settable.
- Do not capture microphone samples or request microphone recording permission; the app monitors the device gain property only.
- Surface unsupported devices and Core Audio failures in the menu UI.
- Keep the gain check interval at ten minutes and reflect interval changes in the menu and README.
- Persist and display the last check time; display the next check time while monitoring.
- Log only successful gain reductions, persist the most recent ten events, and notify through UserNotifications when authorized.
- Use `SMAppService` for login startup, report registration errors, and provide a button to open Login Items settings when approval is required.
- When changing the bundle identifier, migrate stored preferences and document any OS permissions or Login Items that need reapproval.
- Use UTF-8, LF line endings, and a trailing newline in every text file.
- Derive the embedded app version from `APP_VERSION`, the pushed `v*` tag without its `v` prefix, the latest Git tag, or `0.1.0` as fallback; write it to both `CFBundleShortVersionString` and `CFBundleVersion`.
- Store the short Git commit hash in `MumutteCommit`, or `none` when unavailable; show `v<version>+<commit>` at the lower right of the menu.
- Trigger the release workflow only when a `v*` tag is pushed.
- Pin GitHub Actions to full-length commit SHAs and annotate each SHA with its upstream release tag; keep them current.
- After copying all app resources and setting Info.plist values, ad-hoc sign and verify the full `.app` bundle.
- If a `v*` tag already has a GitHub Release, replace its ZIP assets with `gh release upload --clobber`; otherwise create the release with generated notes.
