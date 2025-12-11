#!/bin/bash
set -e

authenticate_terminus() {
	if [ -z "$TERMINUS_TOKEN" ]; then
		echo "TERMINUS_TOKEN is not set. Exiting."
		exit 1
	fi
	terminus auth:login --machine-token=$TERMINUS_TOKEN
}

get_current_wp_version() {
	curl -s https://api.wordpress.org/core/version-check/1.7/ | jq -r '.offers[0].current'
}

get_site_wp_version() {
	terminus wp ${SITE_ID}.live -- core version
}

compare_versions() {
	local current_version
	local site_version

	authenticate_terminus

	current_version=$(get_current_wp_version)
	site_version=$(get_site_wp_version)

	# Default output so the workflow always has the key available
	echo "changed_files=" >> $GITHUB_OUTPUT

	if php -r "exit(version_compare('$site_version', '$current_version', '<') ? 0 : 1);"; then
		echo "The site is running an outdated version of WordPress: $site_version (current: $current_version)"
		update_wordpress
		echo "updates_available=true" >> $GITHUB_OUTPUT
	else
		echo "The site is running the current version of WordPress: $site_version"
		echo "updates_available=false" >> $GITHUB_OUTPUT
	fi

	echo "current_wp_version=$current_version" >> $GITHUB_OUTPUT
}

update_wordpress() {
	local WP_VERSION=$(get_current_wp_version)
	cd ${WP_PATH}
	git checkout -b update-wp-version-${WP_VERSION}-$(date +%Y%m%d)

	wp core download --version=${WP_VERSION} --skip-content --force

	# Capture the list of files changed by the update for later use in the workflow
	local changed_files
	changed_files=$(git status --porcelain=1 --untracked-files=all | cut -c4-)
	printf "changed_files<<EOF\n%s\nEOF\n" "${changed_files}" >> "$GITHUB_OUTPUT"

	echo "Updating WordPress to version ${WP_VERSION} in ${WP_PATH}"
	git add .
	git commit -m "Update WordPress to version ${WP_VERSION}"
}

compare_versions
