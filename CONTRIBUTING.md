# Developing on macOS and Windows

The GitHub repository is the single source of truth for both desktop companions and the download site. Do not maintain separate Mac and Windows copies or exchange source files through ZIP/Drive. Keep work sequential: implement one feature on its first computer, merge it, pull that change on the other computer, and complete the matching implementation there before starting the next feature or releasing.

## Start on either computer

Clone once, then update the shared checkout before each task:

```sh
git clone https://github.com/delight0517-art/chatgpt-attention-alert.git
cd chatgpt-attention-alert
git switch main
git pull --ff-only origin main
```

For later tasks, run the last three commands from the repository folder. Do not make feature changes directly on `main`. Use a short platform-prefixed branch, for example `macos/monthly-recommendation` or `windows/monthly-recommendation`.

## One feature, two platform steps

1. Change one feature at a time. Do not start another feature until this one has matching behavior on both systems.
2. On the first computer, work only on its platform code (`plugin/companion/macos/` or `plugin/companion/windows/`). Include the intended behavior and a concise parity note in the PR. The other platform may be marked **pending** in this implementation PR.
3. Merge the first step, then pull `main` on the other computer and create a second platform-prefixed branch for the matching implementation. Preserve the same user action, labels, command options, and privacy behavior; native UI details may differ.
4. Push the matching implementation and open its PR to `main`. The Mac and Windows jobs in **Validate desktop companions** must both pass.
5. Update plugin instructions and the README when invocation, behavior, or privacy details change. Complete the parity fields in the PR template.
6. For changes to native window behavior, run the smoke checklist on a real Mac and Windows PC. CI syntax checks alone do not prove that windows, sound, or clicks work on those desktops.
7. Only after the second step is merged and both runtime checks are recorded is the feature complete. Then pull `main` on both computers before moving to the next feature.

If a feature cannot yet be implemented on the other platform, mark it **pending** plainly. Do not call it cross-platform complete or include it in a release.

## Desktop smoke checklist

- Alert appears with the correct chat title and requested action.
- Typing does not dismiss the alert; multiple alerts remain findable in arrival order.
- Close, open-chat, sound, and 24-hour pause actions do the same job on both systems.
- Authentication alerts identify the service and account and never include credentials or one-time codes.
- Recommendation behavior, opt-out, small disclosure, and local-only topic history agree on both systems.

Record the OS version and the result for each computer in the pull request. Record unavailable checks as unverified.

## Release and downloads

Release only from merged `main` after both platform steps are complete, both CI jobs pass, and native smoke checks are recorded. The release ZIP must contain the plugin and both companion folders. The website's latest-download link follows the latest GitHub Release, so publish the release asset before announcing the version. Keep GitHub release/source distribution distinct from approval in an official ChatGPT plugin directory.
