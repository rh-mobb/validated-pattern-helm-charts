#!/bin/bash

# Script to update all charts that use helper-status-checker dependency
# Usage: ./update-helper-charts.sh [new_helper_version] [bump_type]
# bump_type: patch (default), minor, major

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default values
NEW_HELPER_VERSION="${1:-}"
BUMP_TYPE="${2:-patch}"

# Charts that use helper-status-checker (archived charts excluded)
CHARTS=(
    "compliance-operator"
    "cluster-efs"
    "loki-operator"
    "cluster-logging"
)

# Function to increment version
increment_version() {
    local version=$1
    local bump_type=$2
    
    IFS='.' read -ra VERSION_PARTS <<< "$version"
    local major=${VERSION_PARTS[0]}
    local minor=${VERSION_PARTS[1]}
    local patch=${VERSION_PARTS[2]}
    
    case $bump_type in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch"|*)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

# Function to update helper-status-checker version in Chart.yaml
update_helper_dependency() {
    local chart_dir=$1
    local new_version=$2
    
    if [[ -f "$chart_dir/Chart.yaml" ]]; then
        # Update exact version
        sed -i '' "s/version: [0-9]\+\.[0-9]\+\.[0-9]\+$/version: $new_version/" "$chart_dir/Chart.yaml"
        # Update tilde version
        sed -i '' "s/version: ~[0-9]\+\.[0-9]\+\.[0-9]\+$/version: ~$new_version/" "$chart_dir/Chart.yaml"
        echo "  Updated helper-status-checker dependency to $new_version"
    fi
}

# Function to bump chart version
bump_chart_version() {
    local chart_dir=$1
    local bump_type=$2
    
    if [[ -f "$chart_dir/Chart.yaml" ]]; then
        local current_version=$(grep "^version:" "$chart_dir/Chart.yaml" | head -1 | cut -d' ' -f2)
        local new_version=$(increment_version "$current_version" "$bump_type")
        
        sed -i '' "s/^version: $current_version$/version: $new_version/" "$chart_dir/Chart.yaml"
        echo "  Bumped chart version: $current_version → $new_version"
        return 0
    fi
    return 1
}

# Main execution
echo "🔄 Updating charts with helper-status-checker dependency..."
echo "Helper version: ${NEW_HELPER_VERSION:-"(no change)"}"
echo "Bump type: $BUMP_TYPE"
echo ""

for chart in "${CHARTS[@]}"; do
    if [[ -d "$chart" ]]; then
        echo "📦 Processing $chart..."
        
        # Update helper-status-checker dependency if version provided
        if [[ -n "$NEW_HELPER_VERSION" ]]; then
            update_helper_dependency "$chart" "$NEW_HELPER_VERSION"
        fi
        
        # Bump chart version
        if bump_chart_version "$chart" "$BUMP_TYPE"; then
            echo "  ✅ $chart updated successfully"
        else
            echo "  ❌ Failed to update $chart"
        fi
        echo ""
    else
        echo "  ⚠️  Chart directory $chart not found"
        echo ""
    fi
done

echo "🎉 Update complete!"
echo ""
echo "📊 Summary:"
for chart in "${CHARTS[@]}"; do
    if [[ -f "$chart/Chart.yaml" ]]; then
        local version=$(grep "^version:" "$chart/Chart.yaml" | cut -d' ' -f2)
        local helper_version=$(grep -A 2 "helper-status-checker" "$chart/Chart.yaml" | grep "version:" | cut -d' ' -f6 | head -1)
        echo "$chart: v$version (helper-status-checker: $helper_version)"
    fi
done
