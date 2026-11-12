#!/usr/bin/env bash
# Publish the reviewed configuration to the authenticated user's private repository.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
gh auth status --hostname github.com >/dev/null
github_login="$(gh api user --jq .login)"
github_id="$(gh api user --jq .id)"
git config --local user.name "$github_login"
git config --local user.email "${github_id}+${github_login}@users.noreply.github.com"
gh auth setup-git --hostname github.com
# Explicit project paths: do not include runtime state, screenshots or auth files.
git add .gitignore README.md shell.qml components config services tests selftest-*.qml docs scripts assets/applications examples/niri legacy
if ! git diff --cached --quiet; then git commit -m "Stabilize Niri Monochrome and integrate native screenshots with Swappy"; fi
if git remote get-url origin >/dev/null 2>&1; then
    printf 'Existing origin: %s\n' "$(git remote get-url origin)"
    printf 'Refusing automatic push to an existing remote; review it first.\n' >&2
    exit 1
fi
# gh refuses to overwrite an existing repository with the same name.
gh repo create "$github_login/niri-monochrome" --private --source=. --remote=origin --push --description "Monochrome Niri and Quickshell desktop configuration"
gh repo view --json url,visibility
