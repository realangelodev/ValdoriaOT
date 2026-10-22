<?php
// Default links for each menu category. They are copied into the database the first time the
// template is shown; after that, change them in the admin panel under Menus.
return [
	MENU_CATEGORY_NEWS => [
		'Latest News' => 'news',
		'News Archive' => 'news/archive',
		'Changelog' => 'change-log',
	],
	MENU_CATEGORY_ACCOUNT => [
		'My Account' => 'account/manage',
		'Create Account' => 'account/create',
		'Lost Account' => 'account/lost',
		'Downloads' => 'downloads',
		'Server Rules' => 'rules',
	],
	MENU_CATEGORY_COMMUNITY => [
		'Characters' => 'characters',
		'Who is Online' => 'online',
		'Highscores' => 'highscores',
		'Last Kills' => 'last-kills',
		'Houses' => 'houses',
		'Guilds' => 'guilds',
		'Team' => 'team',
	],
	MENU_CATEGORY_LIBRARY => [
		'Monsters' => 'monsters',
		'Spells' => 'spells',
		'Server Info' => 'ots-info',
		'Commands' => 'commands',
		'Experience Stages' => 'exp-stages',
		'FAQ' => 'faq',
	],
];
