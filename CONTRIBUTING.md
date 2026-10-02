# Developing on macOS and Windows

The GitHub repository is the single source of truth for both desktop companions and the download site. Do not maintain separate Mac and Windows copies or exchange source files through ZIP/Drive. Keep work sequential: finish one feature on one computer, merge it, pull the result on the other computer, and verify the same feature there before starting the next one.

## Start on either computer

Clone once, then update the shared checkout before each task:

```sh
git clone https://github.com/delight0517-art/chatgpt-attention-alert.git
cd chatgpt-attention-alert
git switch main
git pull --ff-only origin main
```

For later tasks, run the last three commands from the repository folder. Do not make feature changes directly on `main`. Use a short platform-prefixed branch, for example `macos/monthly-recommendation` or `windows/monthly-recommendation`.

## One feature, both companions

1. Change one feature at a time. Avoid editing the same feature on both computers before the first change is merged.
2. Update both counterparts in the same change: `plugin/companion/macos/` and `plugin/companion/windows/`. Keep the command options, visible labels, privacy behavior, and user actions equivalent. Platform-native implementation details may differ.
3. Update the plugin instructions and README when the feature changes how the assistant or user invokes it.
4. Push the feature branch and open a pull request to `main`. The Mac and Windows jobs in **Validate desktop companions** must both pass.
5. For changes to native window behavior, also run the smoke checklist on a real Mac and Windows PC. CI syntax checks alone do not prove that windows, sound, or clicks work on those desktops.
6. Merge only after the parity checklist in the pull request is complete. Then pull `main` on both computers before continuing.

If a feature cannot be implemented on one platform yet, mark that gap plainly in the PR and do not describe the feature as cross-platform complete or put it in a release.

## Desktop smoke checklist

- Alert appears with the correct chat title and requested action.
- Typing does not dismiss the alert; multiple alerts remain findable in arrival order.
- Close, open-chat, sound, and 24-hour pause actions do the same job on both systems.
- Authentication alerts identify the service and account and never include credentials or one-time codes.
- Recommendation behavior, opt-out, small disclosure, and local-only topic history agree on both systems.

Record the OS version and the result for each computer in the pull request. Record unavailable checks as unverified.

## Release and downloads

Release only from merged `main` after both CI jobs pass and native smoke checks are recorded. The release ZIP must contain the plugin and both companion folders. The website's latest-download link follows the latest GitHub Release, so publish the release asset before announcing the version. Keep GitHub release/source distribution distinct from approval in an official ChatGPT plugin directory.
