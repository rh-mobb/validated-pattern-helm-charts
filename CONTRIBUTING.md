# Contributing to Validated Pattern Helm Charts

Thank you for your interest in contributing. This guide explains how to contribute to this Helm chart repository.

## Getting Started

- **Repo**: [rh-mobb/validated-pattern-helm-charts](https://github.com/rh-mobb/validated-pattern-helm-charts)
- **Helm repo**: `https://rh-mobb.github.io/validated-pattern-helm-charts/`
- **Architecture**: See [AGENTS.md](AGENTS.md) for chart structure, conventions, and patterns

## How to Contribute

### 1. Fork and Clone

```bash
git clone https://github.com/<your-username>/validated-pattern-helm-charts.git
cd validated-pattern-helm-charts
```

### 2. Create a Branch

```bash
git checkout -b fix/my-change   # or feature/my-change
```

### 3. Make Your Changes

Follow the conventions in [AGENTS.md](AGENTS.md):

- **Version bump**: Always increment the chart version in `Chart.yaml` (semver: `MAJOR.MINOR.PATCH`)
- **Templates**: Use ArgoCD annotations (`argocd.argoproj.io/sync-wave`, etc.) where applicable
- **Values**: Use empty-string defaults for environment-specific values; document with comments
- **README**: Every chart must have a `README.md` documenting values and usage

### 4. Validate Locally

```bash
# Update dependencies if the chart has them
helm dependency update ./charts/<chart-name>

# Lint
helm lint ./charts/<chart-name>

# Template test
helm template test ./charts/<chart-name>
```

### 5. Commit and Push

```bash
git add .
git commit -m "fix(chart-name): description of change"
git push origin fix/my-change
```

### 6. Open a Pull Request

- Target the `main` branch
- Describe the change and why it’s needed
- CI will run `helm lint` on changed charts

## Chart Version Guidelines

| Change type           | Version bump | Example |
|-----------------------|-------------|---------|
| Bug fixes, docs, tweaks| Patch       | 1.2.3 → 1.2.4 |
| New features (compatible) | Minor   | 1.2.3 → 1.3.0 |
| Breaking changes      | Major       | 1.2.3 → 2.0.0 |

## Creating a New Chart

1. Add `charts/<chart-name>/` with `Chart.yaml`, `values.yaml`, `README.md`, and `templates/`
2. Use `helper-operator` and `helper-status-checker` for operator charts (see AGENTS.md)
3. Run `helm lint` and `helm template` before submitting

## Modifying an Existing Chart

1. Make your changes
2. Bump the version in `Chart.yaml`
3. Update the chart’s `README.md` if values or behavior change
4. Run `helm lint` and `helm template`

## Questions or Issues

- Open an issue for bugs, feature requests, or questions
- For larger changes, discuss in an issue before sending a PR

## Code of Conduct

Be respectful and constructive. This project follows the [Contributor Covenant](https://www.contributor-covenant.org/) in spirit.

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
