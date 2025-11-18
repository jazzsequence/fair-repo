# Deploying WordPress Plugins to Mini FAIR

This repository hosts a Mini FAIR instance that allows plugins to be federated on the FAIR protocol. This guide describes a reproducible “Deploy to FAIR” workflow for plugins stored on GitHub, how you’d adapt it for externally maintained plugins.

## Moving Pieces
- FAIR host: this WordPress site with Mini FAIR + Git Updater and a GitHub token so it can fetch release assets.
- Package repo: your plugin’s GitHub repository with Git Updater headers and a GitHub Action that produces a ZIP release.
- Identity: each plugin has a PLC DID stored on the FAIR host (rotation + verification keys) and referenced in the plugin header (`Plugin ID:`).

## Data Flow (high level)
1. Deploy a plugin to this repository via automated workflow.
2. Create or import a DID on the FAIR host (WP Admin or `wp plc generate`).
3. Add `Plugin ID: <did:plc:...>` and Git Updater headers (e.g., `GitHub Plugin URI: owner/repo`, `Release Asset: true`) to the plugin’s main file and push to GitHub.
4. On each tagged release, the GitHub Action builds and uploads a ZIP release asset.
5. Mini FAIR pulls the artifact (using the host’s GitHub token if needed), signs it, and exposes metadata at `/wp-json/minifair/v1/packages/<did>`.

## Onboarding a Plugin (personal use)
- **Create a DID and store keys**: generate in WP Admin or `wp plc generate`; stash rotation + verification keys in a password manager. The DID is what you embed in the plugin header.
- **Add headers in the plugin repo**: include `Plugin ID: <did>`, and Git Updater headers such as:
  - `GitHub Plugin URI: your-user/your-repo`
  - `Primary Branch: main` (or default)
  - `Release Asset: true` (recommended so FAIR signs the uploaded ZIP)
- **Install/manage via GitHub Actions on the FAIR host**: use the example workflow below to deploy the package to this repo so the site knows to watch it.

## GitHub Action Skeleton (“Deploy to FAIR”)
Add a workflow like `.github/workflows/deploy-to-fair.yml` in the plugin repo:

```yaml
name: Deploy to jazzsequence FAIR

on:
  push:
    tags: ['v*']   # or release: { types: [published] }
  workflow_dispatch:

env:
  PLUGIN_SLUG: your-plugin-slug

jobs:
  build-and-release:
    runs-on: ubuntu-latest
    permissions:
      attestations: write
      id-token: write
      contents: write
    steps:
      - uses: actions/checkout@v5
        with: { fetch-depth: 0 }
      - name: Get tag
        id: tag
        run: echo "tag=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
      - name: Install PHP deps
        run: composer install --no-dev --prefer-dist
      - name: Build plugin ZIP
        run: |
          zip -r "${PLUGIN_SLUG}.zip" . \
            -x '*.git*' 'tests/*' 'node_modules/*' '.github/*'
      - name: Publish release asset
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.ref_name }}
          files: ${{ env.PLUGIN_SLUG }}.zip
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Build provenance attestation
        uses: actions/attest-build-provenance@v2
        with:
          subject-path: ${{ env.PLUGIN_SLUG }}.zip

  # Push built code into the FAIR repo (jazzsequence/fair-repo) via PR so the host can serve it.
  push-to-fair-repo:
    needs: build-and-release
    runs-on: ubuntu-latest
    permissions:
      contents: write   # create branch and commit
      pull-requests: write
    steps:
      - name: Checkout plugin source
        uses: actions/checkout@v5
      - name: Build plugin ZIP
        run: |
          zip -r "${PLUGIN_SLUG}.zip" . \
            -x '*.git*' 'tests/*' 'node_modules/*' '.github/*'
      - name: Checkout FAIR repo
        uses: actions/checkout@v5
        with:
          repository: jazzsequence/fair-repo   # this repository
          path: fair
          token: ${{ secrets.FAIR_REPO_TOKEN }}   # deploy key or PAT with repo write access
      - name: Update plugin in FAIR repo
        run: |
          cd fair
          rm -rf wp-content/plugins/${PLUGIN_SLUG}
          unzip ../${PLUGIN_SLUG}.zip -d wp-content/plugins/${PLUGIN_SLUG}
          git config user.name "fair-bot"
          git config user.email "fair-bot@example.com"
          git checkout -B update-${PLUGIN_SLUG}-${GITHUB_REF_NAME}
          git add wp-content/plugins/${PLUGIN_SLUG}
          git commit -m "Update ${PLUGIN_SLUG} to ${GITHUB_REF_NAME}" || echo "No changes"
      - name: Open pull request to FAIR repo via gh
        env:
          GH_TOKEN: ${{ secrets.FAIR_REPO_TOKEN }}   # must allow PR creation
        run: |
          cd fair
          BRANCH="update-${PLUGIN_SLUG}-${GITHUB_REF_NAME}"
          BASE="main"
          TITLE="Update ${PLUGIN_SLUG} to ${GITHUB_REF_NAME}"
          BODY="Automated update of ${PLUGIN_SLUG} to ${GITHUB_REF_NAME} from ${GITHUB_REPOSITORY}.\nIncludes built ZIP placed in wp-content/plugins/${PLUGIN_SLUG}."
          git push -f origin "${BRANCH}"
          gh pr create \
            --repo jazzsequence/fair-repo \
            --base "${BASE}" \
            --head "${BRANCH}" \
            --title "${TITLE}" \
            --body "${BODY}"
```

Pushing the built code into `jazzsequence/fair-repo` via PR is required so the FAIR host can serve the plugin. Use a deploy key or fine-scoped PAT in `FAIR_REPO_TOKEN`; the workflow opens a pull request instead of pushing to `main` directly.

<!--
## Adjustments for External Submissions (Pantheon-hosted FAIR)
- **Auth model**: instead of a personal PAT, use a GitHub App or per-repo deploy key that only grants release download access. Require external maintainers to publish release assets publicly or supply an access token securely (e.g., Vault) for their repo.
- **DID ownership**: choose whether the FAIR host issues DIDs for external plugins or imports theirs (via `wp plc import` once that flow is finalized). Import keeps authors in control of keys; issuance centralizes management.
- **Refresh hook**: for third parties, expose a narrowly scoped endpoint or queue job that calls `MiniFAIR\update_metadata` for a specific DID; do not rely on broad PAT access.
- **Review before trust**: gate new external plugins behind a manual approval (e.g., require a PR adding the repo to a allowlist consumed by Git Updater) before the FAIR host fetches artifacts.

With the above pieces in place, tagging a release in any connected plugin repo produces a FAIR-ready artifact that Mini FAIR will sign and serve without manual steps.
-->
