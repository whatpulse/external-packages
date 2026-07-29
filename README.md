# WhatPulse External Packages

Automation hub for updating external package repositories when a new WhatPulse version is released.

One trigger (from the release pipeline or the GitHub UI) fans out to:

| Target | How |
|---|---|
| **Homebrew** | Sends a `repository_dispatch` (`update-cask`) to [whatpulse/homebrew-whatpulse](https://github.com/whatpulse/homebrew-whatpulse), which downloads the DMGs, updates the cask, and opens a PR. |
| **winget** | Runs [wingetcreate](https://github.com/microsoft/winget-create) to update the `WhatPulse.WhatPulse` manifest and submits a PR to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) from your fork. |

## Setup

Create a repository secret named **`PACKAGES_PAT`**: a classic GitHub personal access token with the `public_repo` scope, owned by an account that:

- has push access to `whatpulse/homebrew-whatpulse` (to dispatch its workflow), and
- has (or is allowed to create) a fork of `microsoft/winget-pkgs` (wingetcreate submits the PR from that fork).

> Note: use a **classic** PAT. Fine-grained tokens don't work reliably with wingetcreate's fork/PR flow.

## Triggering

### From the GitHub UI

Actions → **Update External Packages** → *Run workflow* → enter the version. You can toggle Homebrew/winget individually.

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
            // Optional: set to false to skip a target
            // 'homebrew' => false,
            // 'winget' => false,
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

## Notes

- The installer/DMG files must already be live on `releases.whatpulse.org` before triggering; both jobs verify the downloads and fail otherwise.
- The winget job carries over the existing manifest (installer switches, scope, etc.) and only updates the version, URL, and SHA256.
- Both targets end in a pull request, so nothing ships without review: the Homebrew PR in the tap repo, the winget PR in microsoft/winget-pkgs.
