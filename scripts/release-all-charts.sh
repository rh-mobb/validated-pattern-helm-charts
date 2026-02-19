#!/bin/bash
# Release all charts to GitHub. Run from repo root.
# Requires: helm, cr (chart-releaser), GITHUB_TOKEN or CR_TOKEN env var
#   brew install helm
#   brew install helm/tap/chart-releaser

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

PACKAGE_DIR=".cr-release-packages"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Add helm repos for dependencies
helm repo add openshift-charts https://charts.openshift.io 2>/dev/null || true
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add backstage https://backstage.github.io/charts 2>/dev/null || true
helm repo add helm-repository https://rh-mobb.github.io/validated-pattern-helm-charts/ 2>/dev/null || true
helm repo update 2>/dev/null || true

# Phase 1: Package and release base charts (no internal deps)
BASE_CHARTS="helper-installplan-approver helper-operator helper-status-checker application-gitops app-of-apps-application app-of-apps-infrastructure app-of-apps-namespaces namespaces overprovisioning"
echo "=== Phase 1: Package base charts ==="
for chart in $BASE_CHARTS; do
  if [[ -d "charts/$chart" ]]; then
    echo "Packaging $chart..."
    helm dependency update "charts/$chart" 2>/dev/null || true
    helm package "charts/$chart" -d "$PACKAGE_DIR"
  fi
done

echo "=== Phase 1: Upload to GitHub (releases + gh-pages) ==="
cr upload \
  --owner rh-mobb \
  --git-repo validated-pattern-helm-charts \
  --package-path "$PACKAGE_DIR" \
  --skip-existing

cr index \
  --owner rh-mobb \
  --git-repo validated-pattern-helm-charts \
  --package-path "$PACKAGE_DIR" \
  --index-path . \
  --push

echo "=== Refreshing helm repo (base charts now live) ==="
helm repo update

# Phase 2a: Package charts that only depend on Phase 1 (no cross-Phase-2 deps)
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

DEPS_CHARTS_A="aws-privateca-issuer cluster-bootstrap cluster-bootstrap-acm-hub-registration cluster-bootstrap-acm-spoke cluster-efs compliance-operator loki-operator"
echo "=== Phase 2a: Package dependent charts (excluding cluster-logging) ==="
for chart in $DEPS_CHARTS_A; do
  if [[ -d "charts/$chart" ]]; then
    echo "Packaging $chart..."
    helm dependency update "charts/$chart" 2>/dev/null || true
    helm package "charts/$chart" -d "$PACKAGE_DIR"
  fi
done

echo "=== Phase 2a: Upload to GitHub ==="
cr upload \
  --owner rh-mobb \
  --git-repo validated-pattern-helm-charts \
  --package-path "$PACKAGE_DIR" \
  --skip-existing

cr index \
  --owner rh-mobb \
  --git-repo validated-pattern-helm-charts \
  --package-path "$PACKAGE_DIR" \
  --index-path . \
  --push

echo "=== Refreshing helm repo (loki-operator now live) ==="
helm repo update

# Phase 2b: Package cluster-logging (depends on loki-operator from Phase 2a)
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

echo "=== Phase 2b: Package cluster-logging ==="
if [[ -d "charts/cluster-logging" ]]; then
  echo "Packaging cluster-logging..."
  helm dependency update "charts/cluster-logging" 2>/dev/null || true
  helm package "charts/cluster-logging" -d "$PACKAGE_DIR"
fi

if [[ -n "$(ls -A $PACKAGE_DIR 2>/dev/null)" ]]; then
echo "=== Phase 2b: Upload to GitHub ==="
cr upload \
  --owner rh-mobb \
  --git-repo validated-pattern-helm-charts \
  --package-path "$PACKAGE_DIR" \
  --skip-existing

cr index \
  --owner rh-mobb \
  --git-repo validated-pattern-helm-charts \
  --package-path "$PACKAGE_DIR" \
  --index-path . \
  --push
fi

echo ""
echo "Done! Charts released to https://rh-mobb.github.io/validated-pattern-helm-charts/"
