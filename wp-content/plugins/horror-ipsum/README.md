# Horror Ipsum
![GitHub Release](https://img.shields.io/github/v/release/jazzsequence/horror-ipsum)

A WordPress plugin that generates horror-themed placeholder text for your site in a Gutenberg block.

## Installation

### Composer
Use Composer to add to your WordPress site. Make sure you have `composer/installers` installed in your `composer.json` so that Composer can install the plugin in the correct directory.

```bash
composer require jazzsequence/horror-ipsum
```

### Manual
Download the latest release from the [releases page](https://github.com/jazzsequence/horror-ipsum/releases) and upload the zip file to your WordPress site.

## Frequently Asked Questions

### What is this?
It's a plugin that I created because I wanted to make a spooky demo site for a livestream right before Halloween.

### How did you create this?
I asked ChatGPT to make me a plugin. I actually recorded a [YouTube short](https://youtube.com/shorts/27bH23ST96U?feature=share) about it. Once I had something I was more or less happy with, I tweaked it so the sources are coming from a JSON file rather than being hard-coded in the plugin file.

### Can I use this?
Yes! Please do! I can't vouch for the safety of your soul, however. It might be cursed.

### Where did the text come from?
I used a variety of horror movie scripts available online for movies like Evil Dead, The Exorcist, House of 1000 Corpses, Scream, etc. I tried to use NotebookLM to compile an array of quotes from across the scripts and it did an okay, if incomplete job of it. I then added HP Lovecraft novels available on Gutenberg.org (heh) and had NotebookLM pull a list of quotes from those, too. Then I combined them all into the [`quotes.json`](https://github.com/jazzsequence/horror-ipsum/blob/main/assets/json/quotes.json) file the plugin now uses.

### How can I contribute?
PRs are welcome!

### Can I add my own quotes?
I've added a filter, `horror_ipsum_text` that you can use to add your own quotes. It hooks directly into the function that pulls the quotes from the JSON file, so you can add your own quotes to the list.

```php
add_filter('horror_ipsum_text', function($quotes) {
	$quotes[] = 'I am your father.';
	return $quotes;
});
```
