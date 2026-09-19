# WhatPulse External Packages

Automation hub for updating external package repositories when a new WhatPulse version is released.

One trigger (from the release pipeline or the GitHub UI) fans out to:

| Target | Workflow | How |
|---|---|---|
| **Homebrew** | [`homebrew.yml`](.github/workflows/homebrew.yml) | Sends a `repository_dispatch` (`update-cask`) to [whatpulse/homebrew-whatpulse](https://github.com/whatpulse/homebrew-whatpulse), which downloads the DMGs, updates the cask, and opens a PR. |
| **winget** | [`winget.yml`](.github/workflows/winget.yml) | Runs [wingetcreate](https://github.com/microsoft/winget-create) to update the `WhatPulse.WhatPulse` manifest and submits a PR to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) from your fork. |
| **Chocolatey** | [`chocolatey.yml`](.github/workflows/chocolatey.yml) | Renders the package in [`chocolatey/whatpulse`](chocolatey/whatpulse) with the new version and installer SHA256, runs `choco pack`, test-installs and uninstalls it on the runner, then pushes it to [community.chocolatey.org](https://community.chocolatey.org/packages/whatpulse). |

## Workflow layout

- [`release.yml`](.github/workflows/release.yml) (**Update External Packages**) is the orchestrator. It resolves the version once and calls each target workflow via `workflow_call`, honoring the per-target toggles / skip flags.
- Each target workflow also has its own `workflow_dispatch` trigger, so you can run **Homebrew**, **winget**, or **Chocolatey** individually from the Actions tab without touching the others. Changes to a target only need to be made in its own file.

## Setup

### `PACKAGES_PAT` (Homebrew + winget)

Create a repository secret named **`PACKAGES_PAT`**: a classic GitHub personal access token with the `public_repo` scope, owned by an account that:

- has push access to `whatpulse/homebrew-whatpulse` (to dispatch its workflow), and
- has (or is allowed to create) a fork of `microsoft/winget-pkgs` (wingetcreate submits the PR from that fork).

> Note: use a **classic** PAT. Fine-grained tokens don't work reliably with wingetcreate's fork/PR flow.

### `CHOCOLATEY_API_KEY` (Chocolatey)

1. Register an account at <https://community.chocolatey.org/account/Register> (use a WhatPulse-owned email; this account is the package owner shown on the package page).
2. Copy the API key from <https://community.chocolatey.org/account> and store it as the **`CHOCOLATEY_API_KEY`** repository secret.
3. The `whatpulse` package id is reserved by a third-party account: someone submitted a 5.1 package in Feb 2023, it failed verification, and Chocolatey rejected it as stale in Mar 2023. It was never listed (search doesn't show it; the [package page](https://community.chocolatey.org/packages/whatpulse) does). Pushing under that id is only possible once your account owns it. Use *Contact Site Admins* on that page, say you are the WhatPulse vendor, and ask for the id to be reassigned to your account (see [package maintainer handover](https://docs.chocolatey.org/en-us/community-repository/maintainers/package-maintainer-handover)). There are no approved versions, so no maintainer coordination is needed.
   Until the handover is done, run the Chocolatey workflow with **publish** unticked: it still builds, test-installs, and uploads the `.nupkg` as a workflow artifact.
4. New versions go through Chocolatey moderation (automated validator + verifier, plus a human review until the package is marked *trusted*). Expect the first few versions to take a day or two to be approved; you get emails on the account.

## Triggering

### From the GitHub UI

- All targets: Actions → **Update External Packages** → *Run workflow* → enter the version. Toggle Homebrew / winget / Chocolatey individually.
- One target: Actions → **Homebrew**, **winget**, or **Chocolatey** → *Run workflow* → enter the version. The Chocolatey workflow has an extra **publish** toggle; untick it to only build and test-install.

### From the API (Laravel release pipeline)

Send a `repository_dispatch` event:

```php
use Illuminate\Support\Facades\Http;

Http::withToken(config('services.github.token'))
    ->withHeaders(['Accept' => 'application/vnd.github+json'])
    ->post('https://api.github.com/repos/whatpulse/external-packages/dispatches', [
        'event_type' => 'new-release',
        'client_payload' => [
            'version' => $version, // e.g. '5.8.3'
            // Optional: set to true to skip a target
            // 'skip_homebrew' => true,
            // 'skip_winget' => true,
            // 'skip_chocolatey' => true,
        ],
    ]);
```

The token used from Laravel needs `repo` scope on this repository (or `public_repo` if this repo is public).

Equivalent curl:

```bash
curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/whatpulse/external-packages/dispatches \
  -d '{"event_type":"new-release","client_payload":{"version":"5.8.3"}}'
```

## Chocolatey package

Source lives in [`chocolatey/whatpulse`](chocolatey/whatpulse). The nuspec and install script are templates: `{{VERSION}}` and `{{CHECKSUM}}` are filled in by the workflow, so there is nothing to edit per release.

- Install: runs the Qt Installer Framework installer with `--accept-messages --accept-licenses --confirm-command install InstallForAllUsers=true NoLaunch=true` (same switches as winget and the documented unattended install, plus machine-wide install because Chocolatey runs elevated).
- Uninstall: runs `WhatPulseMaintenanceTool.exe --confirm-command purge`, located via the `WhatPulse` uninstall registry key.
- Icon: `icon.png` is served through jsDelivr from this repo. Replace it with a larger square logo (128×128 or more) when convenient; the current one is the 96px site favicon.

## Notes

- Installers are referenced by **versioned archive URLs** (`releases.whatpulse.org/archives/<version>/...`), so recorded SHA256 hashes stay valid after later releases. The files must already be live before triggering; every target verifies the download and fails otherwise.
- The winget job carries over the existing manifest (installer switches, scope, etc.) and only updates the version, URL, and SHA256.
- Homebrew and winget end in a pull request, so nothing ships without review. Chocolatey pushes go straight to the community repository, where Chocolatey's own moderation queue reviews them before they become public.
