# Build Monitor

A native iOS app for monitoring GitHub Actions builds across repositories.

## Goals

- Track multiple GitHub repositories and their Actions workflow runs.
- Show run status, elapsed time, workflow, branch, commit and actor.
- Inspect jobs and individual steps.
- View build logs and failure details.
- Access workflow artifacts (including IPA files when workflows produce them).
- Notify when builds complete or fail.
- Trigger reruns when GitHub permissions and workflow settings allow.

## Planned stack

- SwiftUI (native iOS)
- GitHub REST API
- Secure token storage in Keychain
- Local refresh while the app is active; push notifications via a later server/webhook phase

## Reuse candidates

- `maguc98/DeepSeek-Monitor`: SwiftUI app structure, project generation/configuration and visual components.
- `maguc98/hex`: examples of real GitHub Actions workflows, jobs, steps and artifact handling.
- `maguc98/text-display-ios`: iOS project organization and asset/configuration patterns.
- `maguc98/ds-monitor`: earlier monitoring/polling project ideas (not intended as direct app code).

Reuse will be selective. Build Monitor will have its own clean architecture and UI; unrelated business logic will not be copied.

## Initial roadmap

1. Repository scaffold and app architecture.
2. GitHub authentication and repository selection.
3. Workflow runs dashboard.
4. Run detail: jobs, steps and live-refresh status.
5. Logs and failure diagnostics.
6. Artifacts and IPA access.
7. Notifications and optional workflow rerun actions.

## Status

Early planning / scaffold.
