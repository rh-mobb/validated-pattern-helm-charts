# Scripts

## release-all-charts.sh

Packages and releases all charts to GitHub. Use when the "Release All Charts" workflow fails (e.g. dependency resolution in CI).

**Prerequisites:**
```bash
brew install helm
brew install helm/tap/chart-releaser
```

**Run:**
```bash
export CR_TOKEN="your-github-pat"   # or GITHUB_TOKEN
./scripts/release-all-charts.sh
```

Requires a GitHub PAT with `repo` scope (and SSO authorization if applicable).
