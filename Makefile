# Run helm template and helm lint across all charts
CHARTS := $(sort $(dir $(wildcard charts/*/Chart.yaml)))
CHARTS := $(patsubst charts/%/,charts/%,$(CHARTS))

.PHONY: test lint template repo-setup

test: repo-setup lint template

repo-setup:
	@helm repo add openshift-charts https://charts.openshift.io 2>/dev/null || true
	@helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
	@helm repo add backstage https://backstage.github.io/charts 2>/dev/null || true
	@helm repo add helm-repository https://rh-mobb.github.io/validated-pattern-helm-charts/ 2>/dev/null || true
	@helm repo update 2>/dev/null || true

lint:
	@for chart in $(CHARTS); do \
		echo "==> Linting $$chart"; \
		helm lint "$$chart" || exit 1; \
	done

template:
	@for chart in $(CHARTS); do \
		echo "==> Template $$chart"; \
		helm dependency update "$$chart" 2>/dev/null || true; \
		helm template test "$$chart" > /dev/null || exit 1; \
	done
