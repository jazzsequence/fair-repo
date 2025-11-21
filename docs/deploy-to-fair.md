# Deploying WordPress Plugins to Mini FAIR

This repository hosts a Mini FAIR instance that allows plugins to be federated on the FAIR protocol. This guide outlines a reproducible “Deploy to FAIR” workflow for plugins stored on GitHub.

## Moving Pieces
- FAIR host: this WordPress site with Mini FAIR + Git Updater and a GitHub token so it can fetch release assets.
- Package repo: your plugin’s GitHub repository with Git Updater headers and a GitHub Action that produces a ZIP release.
- Access tokens: A fine-grained PAT is used for the jazzsequence FAIR repository that is scoped specifically to this repository to be granted to external plugins, enabling them to hook into this workflow and write changes to the FAIR host repo.

## Data Flow (high level)
1. Plugin pushes a release to GitHub. 
2. That release triggers an automated workflow to deploy the plugin to this repository.
3. On each tagged release, the GitHub Action builds and uploads a ZIP release asset.
4. Within the jazzsequence FAIR repository site, the plugins are added and managed by the Mini FAIR plugin (installed as an mu-plugin).

## Onboarding a Plugin
- **Create a DID and store keys**: generate in WP Admin or `wp plc generate`; stash rotation + verification keys in a password manager. The DID is what you embed in the plugin header.
- **Add headers in the plugin repo**: include `Plugin ID: <did>`, and Git Updater headers such as:
  - `GitHub Plugin URI: your-user/your-repo`
  - `Primary Branch: main` (or default)
  - `Release Asset: true` (recommended so FAIR signs the uploaded ZIP)
- **Install/manage via GitHub Actions on the FAIR host**: use the example workflow below to deploy the package to this repo so the site knows to watch it.

## GitHub Action (“Deploy to FAIR”)
At this time there is no actual GitHub Action. The following is a sample workflow that can be used to deploy to the jazzsequence FAIR repository. A GitHub Action would need the following parameters:

- `host_repository`: The (GitHub) repository of the FAIR host (e.g., `jazzsequence/fair-repo`).
- `plugin_slug`: The slug of the plugin being deployed (e.g., `my-plugin`).
- `build_command`: (Optional) Build steps necessary to compile the plugin before packaging (e.g. `composer install && npm ci && npm run build`).
- `git_user`: The Git user name for committing changes (e.g., `🤖 FAIR Robot`).
- `git_email`: The Git user email for committing changes (e.g., `fair-robot@example.com`).
- `base_branch`: (Optional) The base branch on the FAIR host to open the PR against (default: `main`).
- A secret token (deploy key or PAT) with write access to the FAIR host repository (stored in repository secrets).

Add a workflow like `.github/workflows/deploy-to-fair.yml` in the plugin repo:

```yaml
name: Deploy to jazzsequence FAIR

on:
  release:
    types: [published]
  workflow_dispatch:

env:
  PLUGIN_SLUG: your-plugin-slug

jobs:
  build-and-release:
    name: Build and publish plugin release
    runs-on: ubuntu-latest
    permissions:
      attestations: write
      id-token: write
      contents: write
    steps:
      - uses: actions/checkout@v5
        with: 
          fetch-depth: 0
      - name: Get tag
        id: tag
        run: echo "tag=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
      - name: Install PHP deps
        run: composer install --no-dev --prefer-dist --optimize-autoloader
      - name: Install WP-CLI
        uses: godaddy-wordpress/setup-wp-cli@1
      - name: Install dist-archive tool
        run: wp package install wp-cli/dist-archive-command
      - name: Build plugin ZIP
        run: |
          ZIP="${{ env.PLUGIN_SLUG }}-${{ steps.tag.outputs.tag }}.zip"
          TARGET="${GITHUB_WORKSPACE}/$ZIP"
          wp dist-archive . "$TARGET"
      - name: Upload plugin package artifact
        uses: actions/upload-artifact@v4
        with:
          name: plugin-zip
          path: ${{ env.PLUGIN_SLUG }}-${{ steps.tag.outputs.tag }}.zip
      - name: Publish release asset
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release upload ${GITHUB_REF_NAME} ${PLUGIN_SLUG}-${{ steps.tag.outputs.tag }}.zip \
            --clobber \
            --repo ${GITHUB_REPOSITORY}
      - name: Build provenance attestation
        uses: actions/attest-build-provenance@v2
        with:
          subject-path: ${{ env.PLUGIN_SLUG }}-${{ steps.tag.outputs.tag }}.zip

  push-to-fair-repo:
    name: Push built plugin to FAIR host repo
    needs: build-and-release
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Download plugin artifact from build job
        uses: actions/download-artifact@v4
        with:
          name: plugin-zip
          path: artifacts
      - name: Checkout FAIR repo
        uses: actions/checkout@v5
        with:
          repository: jazzsequence/fair-repo
          path: fair
          token: ${{ secrets.FAIR_REPO_TOKEN }}
      - name: Configure Git
        run: |
          git config --global user.name "🤖 FAIR Robot"
          git config --global user.email "fair-robot@users.noreply.github.com"
      - name: Update plugin in FAIR repo
        run: |
          cd fair
          rm -rf wp-content/plugins/${PLUGIN_SLUG}
          unzip ../artifacts/${PLUGIN_SLUG}-${GITHUB_REF_NAME}.zip -d wp-content/plugins/${PLUGIN_SLUG}
          git checkout -B update-${PLUGIN_SLUG}-${GITHUB_REF_NAME}
          git add wp-content/plugins/${PLUGIN_SLUG}
          git commit -m "Update ${PLUGIN_SLUG} to ${GITHUB_REF_NAME}" || echo "No changes to commit"
      - name: Open pull request to FAIR repo via gh
        env:
          GH_TOKEN: ${{ secrets.FAIR_REPO_TOKEN }}   # must allow PR creation
        run: |
          cd fair
          PREFIX="update-${PLUGIN_SLUG}-"
          BRANCH="${PREFIX}${GITHUB_REF_NAME}"
          BASE="main"
          TITLE="Update ${PLUGIN_SLUG} to ${GITHUB_REF_NAME}"
          BODY=$'Automated update of '"${PLUGIN_SLUG}"$' to version '"${GITHUB_REF_NAME}"$' from '"${GITHUB_REPOSITORY}"$'.\n\nIncludes built ZIP placed in wp-content/plugins/'"${PLUGIN_SLUG}"$'.'
          git push -f origin "${BRANCH}"
          # Close any existing PRs for this plugin update before opening a new one.
          gh pr list \
            --repo jazzsequence/fair-repo \
            --state open \
            --json number,headRefName \
            --jq ".[] | select(.headRefName | startswith(\"${PREFIX}\")) | .number" \
            | xargs -r -I{} gh pr close {} --repo jazzsequence/fair-repo -c "Superseded by ${TITLE} ${BRANCH}."
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
- **Auth model**: We would need to grant each third party with a fine-grained PAT that is scoped only to the Pantheon repository that is hosting the FAIR instance. This PAT would be used by the GitHub Action in their plugin repository to open a PR against the Pantheon-hosted FAIR repo. We could manage this because presumably these would be granted individually and ad hoc.
-->
