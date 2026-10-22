<?php
// Menu categories shown in the top bar, in this order. Edit the links themselves in menus.php,
// or later in the admin panel under Menus.
$config['menu_default_links_color'] = '';
$config['menu_categories'] = [
	MENU_CATEGORY_NEWS => ['id' => 'news', 'name' => 'News'],
	MENU_CATEGORY_ACCOUNT => ['id' => 'account', 'name' => 'Account'],
	MENU_CATEGORY_COMMUNITY => ['id' => 'community', 'name' => 'Community'],
	MENU_CATEGORY_LIBRARY => ['id' => 'library', 'name' => 'Library'],
];

$config['menus'] = require __DIR__ . '/menus.php';
