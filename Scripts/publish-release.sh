#!/bin/bash
# GITHUB_TOKEN is supplied only to this job. Never echo it or enable shell tracing.
set -euo pipefail
[[ "$(gh api "repos/$GITHUB_REPOSITORY" --jq .private)" == true ]]
[[ "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ && "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
gh run download "$GITHUB_RUN_ID" --repo "$GITHUB_REPOSITORY" --name LumaReader-release-approved --dir release-assets
cd release-assets
sha256sum --check SHA256SUMS
python3 -c 'import json,os; p=json.load(open("build-provenance.json")); assert p["sourceCommit"]==os.environ["SOURCE_SHA"] and p["runID"]==os.environ["GITHUB_RUN_ID"]'
tag_sha="$(gh api "repos/$GITHUB_REPOSITORY/git/matching-refs/tags/$RELEASE_TAG" --jq ".[] | select(.ref == \"refs/tags/$RELEASE_TAG\") | .object.sha")"
[[ -z "$tag_sha" || "$tag_sha" == "$SOURCE_SHA" ]] || { echo 'Existing tag has a different target; refusing to overwrite'; exit 1; }
if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  [[ "$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json targetCommitish --jq .targetCommitish)" == "$SOURCE_SHA" ]]
  [[ "$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json isDraft --jq .isDraft)" == true ]] || { echo 'Published release already exists; refusing to overwrite'; exit 1; }
else
  gh release create "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --target "$SOURCE_SHA" --draft --title "LumaReader ${RELEASE_TAG#v}" --notes-file RELEASE_NOTES.md
fi
gh release upload "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --clobber ./*
mkdir ../release-verification
gh release download "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --dir ../release-verification
cmp SHA256SUMS ../release-verification/SHA256SUMS
(cd ../release-verification && sha256sum --check SHA256SUMS)
gh release edit "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --draft=false
[[ "$(gh api "repos/$GITHUB_REPOSITORY/git/ref/tags/$RELEASE_TAG" --jq .object.sha)" == "$SOURCE_SHA" ]]
gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json url,assets,isDraft
