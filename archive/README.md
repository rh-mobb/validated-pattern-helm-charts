# Archived Helm Charts

This directory holds archived Helm charts that are not used by the current setup. They are excluded from CI/CD (chart-releaser, linting, and publication).

## Restoring a Chart

To restore an archived chart to active use:

1. Move it back to `charts/`:

   ```bash
   git mv archive/<chart-name> charts/
   ```

2. Bump the chart version in `charts/<chart-name>/Chart.yaml` (required for CI to publish).
