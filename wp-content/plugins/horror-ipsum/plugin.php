<?php

/**
 * Plugin Name: Horror Ipsum Generator
 * Description: A horror-themed Lorem Ipsum generator inside a Gutenberg block for adding spooky filler text.
 * Version: 1.0.6
 * Author: Chris Reynolds
 * Author URI: https://www.chrisreynolds.io
 * License: MIT
 * License URI: https://opensource.org/licenses/MIT
 * GitHub Plugin URI: jazzsequence/horror-ipsum
 * Primary Branch: main
 * Plugin ID: did:plc:ge7m5b2k5ypcavkiblmw5gmz
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit; // Exit if accessed directly.
}

function horror_ipsum_texts() {
	$ipsum = file_get_contents( plugin_dir_path( __FILE__ ) . 'assets/json/quotes.json' );
	return apply_filters( 'horror_ipsum_text', json_decode( $ipsum, true ) );
}

// Register the block script.
function horror_ipsum_register_block() {
	wp_register_script(
		'horror-ipsum-block',
		plugins_url( 'assets/js/block.js', __FILE__ ),
		['wp-blocks', 'wp-element', 'wp-block-editor'],
		filemtime( plugin_dir_path( __FILE__ ) . 'assets/js/block.js' )
	);

	// Localize the script to pass PHP data to JavaScript.
	wp_localize_script(
		'horror-ipsum-block',
		'horrorLipsumData',
		[ 'texts' => horror_ipsum_texts() ]
	);

	register_block_type(
		'horror-ipsum/random-paragraph', 
		['editor_script' => 'horror-ipsum-block']
	);
}
add_action( 'init', 'horror_ipsum_register_block' );
