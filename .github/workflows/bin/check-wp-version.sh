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

	if php -r "exit(version_compare('$site_version', '$current_version', '<') ? 0 : 1);"; then
		echo "The site is running an outdated version of WordPress: $site_version (current: $current_version)"
		update_wordpress
	else
		echo "The site is running the current version of WordPress: $site_version"
	fi
}

update_wordpress() {
	cd ${WP_PATH}
	git checkout -b update-wp-version-$(get_current_wp_version)-$(date +%Y%m%d)

	lando wp core update

	local wp_version
	wp_version=$(lando wp core version)
	echo "Updating WordPress to version ${wp_version} in ${WP_PATH}"
	git add .
	git commit -m "Update WordPress to version ${wp_version}"
}

compare_versions