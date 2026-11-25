# Build Monitor

Native SwiftUI iOS app for monitoring GitHub Actions across repositories.

## Features

- Connect GitHub with a fine-grained personal access token.
- Store the token in the iOS Keychain (not in source files or UserDefaults).
- Discover accessible repositories and read recent Actions workflow runs.
- Dashboard counters for success, in-progress, queued, and failed runs.
- Inspect actual jobs and steps for a workflow run.
- Read uploaded Artifact metadata and download the Artifact ZIP for sharing.
- Open a workflow or job on GitHub for full console output.

The dashboard only shows GitHub data after a token has been connected. Repository workflow summaries are fetched for the 40 most recently updated repositories to keep API usage bounded; all accessible repositories are listed.

## Required token permissions

Use a fine-grained personal access token, select the repositories to monitor, and grant:
- Metadata: Read-only
- Actions: Read-only

Classic tokens may require the appropriate repository access. Never commit a token, .p12 certificate, provisioning profile, or signing secret.

## Build

Requires Xcode 15+ and XcodeGen. Run xcodegen generate --spec project.yml, then build the BuildMonitor scheme.

GitHub Actions builds for simulator and iPhone, packages an unsigned IPA, and uploads it as an Actions artifact.
