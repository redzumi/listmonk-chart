#!/usr/bin/env bash
# Build the Helm repository for publishing (e.g. GitHub Pages).
# Run from the chart repo root. Requires: helm
#
# Usage:
#   REPO_URL=https://YOUR_USER.github.io/listmonk-chart ./scripts/build-repo.sh
#
# Then commit docs/index.yaml, docs/*.tgz, and docs/artifacthub-repo.yml,
# enable GitHub Pages (branch main, folder /docs), and add REPO_URL to Artifact Hub.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS="$CHART_ROOT/docs"

if [ -z "$REPO_URL" ]; then
  echo "Error: REPO_URL is required (e.g. https://YOUR_USER.github.io/listmonk-chart)" >&2
  echo "Usage: REPO_URL=https://... ./scripts/build-repo.sh" >&2
  exit 1
fi

# Remove trailing slash so index.yaml chart URLs are correct
REPO_URL="${REPO_URL%/}"
mkdir -p "$DOCS"

echo "Packaging chart..."
helm package "$CHART_ROOT" --destination "$DOCS"

echo "Building index..."
if [ -f "$DOCS/index.yaml" ]; then
  helm repo index "$DOCS" --url "$REPO_URL" --merge "$DOCS/index.yaml"
else
  helm repo index "$DOCS" --url "$REPO_URL"
fi

cp "$CHART_ROOT/artifacthub-repo.yml" "$DOCS/"

echo "Done. Contents of docs/:"
ls -la "$DOCS"
echo ""
echo "Next: commit docs/, enable GitHub Pages (branch main, folder /docs), then add this URL in Artifact Hub:"
echo "  $REPO_URL"
