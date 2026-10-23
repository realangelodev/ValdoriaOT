<?php
/**
 * Valdoria: a custom MyAAC template.
 * Layout: top bar with dropdown menus, a castle-at-sunset hero, then the page in a card beside a sidebar
 * (account, server status, top players). All page content still comes from MyAAC.
 */
defined('MYAAC') or die('Direct access not allowed!');

use MyAAC\Cache\Cache;
use MyAAC\Plugins;

$h = fn($s) => htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8');

// The first time this template is shown, copy its default menus into the database.
$menus = get_template_menus();
if (empty($menus) && isset($config['menus'])) {
	Plugins::installMenus($template_name, $config['menus']);
	$cache = Cache::getInstance();
	if ($cache->enabled()) {
		$cache->delete('template_menus_' . $template_name);
	}
	$menus = get_template_menus();
}

$serverName = $config['lua']['serverName'] ?? 'Valdoria';

// The tab that contains the page being viewed opens by default; otherwise News.
$activeCategory = MENU_CATEGORY_NEWS;
foreach ($menus as $categoryId => $links) {
	foreach ($links as $link) {
		$target = trim($link['link'], '/');
		if ($target !== '' && (PAGE === $target || str_starts_with(PAGE, $target . '/'))) {
			$activeCategory = $categoryId;
			break 2;
		}
	}
}
$isHome = in_array(PAGE, ['', 'news'], true);

// The Discord link in the footer. setup.bat writes DISCORD_URL from .env into discord.url next to this file.
$discordUrl = trim((string)@file_get_contents(__DIR__ . '/discord.url')) ?: 'https://discord.com';

// MyAAC titles a character page "Name - Characters"; show the name as the heading instead.
$heading = $title;
$eyebrow = $serverName;
if (str_starts_with(PAGE, 'characters') && str_contains($title, ' - ')) {
	$heading = substr($title, 0, strrpos($title, ' - '));
	$eyebrow = 'Character';
}
$online = !empty($status['online']);
$players = (int)($status['players'] ?? 0);
$vocations = config('vocations') ?? [];
// Top players for the sidebar. MyAAC's own list skips every character on account 1, which here is the
// owner's account, so characters made there never showed up. Hide only MyAAC's sample characters, players
// hidden in the settings and staff (GM and up) instead.
$topPlayers = [];
try {
	$hiddenIds = setting('core.highscores_ids_hidden');
	$hiddenIds = array_filter(array_map('intval', is_array($hiddenIds) ? $hiddenIds : explode(',', (string)$hiddenIds)));
	$topPlayers = $db->query('SELECT `name`, `level`, `vocation` FROM `players`'
		. ' WHERE `deletion` = 0 AND `group_id` < ' . (int)setting('core.highscores_groups_hidden')
		. " AND `name` NOT IN ('Rook Sample', 'Sorcerer Sample', 'Druid Sample', 'Paladin Sample', 'Knight Sample')"
		. ($hiddenIds ? ' AND `id` NOT IN (' . implode(',', $hiddenIds) . ')' : '')
		. ' ORDER BY `experience` DESC, `name` LIMIT 5')->fetchAll();
} catch (Throwable $e) {
	// The top players box is optional; the page renders without it.
}
$topLevel = max(1, (int)($topPlayers[0]['level'] ?? 1));

// A few small inline icons, drawn with strokes so they take the text colour.
$icon = [
	'sword' => '<path d="M14.5 3.5h6v6L9 21l-2-2-3 1 1-3-2-2z"/><path d="M13 9l2 2"/>',
	'map' => '<path d="M3 6l6-3 6 3 6-3v15l-6 3-6-3-6 3z"/><path d="M9 3v15M15 6v15"/>',
	'keep' => '<path d="M4 21V8l2-1V4h2v2h2V4h4v2h2V4h2v3l2 1v13z"/><path d="M10 21v-5a2 2 0 0 1 4 0v5"/>',
	'scroll' => '<path d="M6 4h11a3 3 0 0 1 0 6H8"/><path d="M6 4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V10"/><path d="M9 14h6M9 17h4"/>',
	'gem' => '<path d="M6 3h12l3 6-9 12L3 9z"/><path d="M3 9h18M9 3l3 18 3-18"/>',
	'door' => '<path d="M5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16"/><path d="M3 21h18M14 12h.01"/>',
];
$svg = fn($name) => '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true">' . $icon[$name] . '</svg>';
?>
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<?= template_place_holder('head_start'); ?>
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Alegreya+Sans:wght@400;500;700;800&family=Cinzel:wght@500;600;700&family=Uncial+Antiqua&family=Spline+Sans+Mono:wght@400;500&display=swap">
	<link rel="stylesheet" href="<?= $template_path; ?>/style.css">
	<?= template_place_holder('head_end'); ?>
</head>
<body class="<?= $isHome ? 'is-home' : 'is-page'; ?>">
<?= template_place_holder('body_start'); ?>
<?php
// Carved gold lettering for the name and page titles: worn edges, soft weathering, a chiselled bevel lit
// from the upper left, a hard dark outline and a cast shadow. One filter per text size, scaled by $k;
// small text gets a higher light and a shallower bevel so thin strokes stay bright.
$carve = function ($id, $k, $elevation = 38, $surface = 3.2) {
	$n = fn($v) => round($v * $k, 2);
	return '<filter id="' . $id . '" x="-5%" y="-25%" width="110%" height="160%" color-interpolation-filters="sRGB">'
		. '<feTurbulence type="fractalNoise" baseFrequency="' . round(0.045 / $k, 3) . '" numOctaves="2" seed="9" result="warp"/>'
		. '<feDisplacementMap in="SourceGraphic" in2="warp" scale="' . $n(2.5) . '" xChannelSelector="R" yChannelSelector="G" result="shape"/>'
		. '<feTurbulence type="fractalNoise" baseFrequency="' . round(0.022 / $k, 3) . '" numOctaves="3" seed="21" result="mottle"/>'
		. '<feColorMatrix in="mottle" type="matrix" values="0 0 0 0 0.45  0 0 0 0 0.22  0 0 0 0 0.04  -1.1 0 0 0 0.55" result="mottleA"/>'
		. '<feComposite in="mottleA" in2="shape" operator="in" result="mottleIn"/>'
		. '<feMerge result="face"><feMergeNode in="shape"/><feMergeNode in="mottleIn"/></feMerge>'
		. '<feGaussianBlur in="shape" stdDeviation="' . $n(1.6) . '" result="h"/>'
		. '<feDiffuseLighting in="h" surfaceScale="' . $surface . '" diffuseConstant="1" lighting-color="#fff" result="d"><feDistantLight azimuth="235" elevation="' . $elevation . '"/></feDiffuseLighting>'
		. '<feComposite in="face" in2="d" operator="arithmetic" k1="1.55" k2="0" k3="0" k4="0" result="shaded"/>'
		. '<feComposite in="shaded" in2="shape" operator="in" result="shadedIn"/>'
		. '<feSpecularLighting in="h" surfaceScale="' . $surface . '" specularConstant="0.9" specularExponent="24" lighting-color="#fff3c8" result="s"><feDistantLight azimuth="235" elevation="' . $elevation . '"/></feSpecularLighting>'
		. '<feComposite in="s" in2="shape" operator="in" result="sIn"/>'
		. '<feComposite in="sIn" in2="shadedIn" operator="arithmetic" k1="0" k2="0.6" k3="1" k4="0" result="lit"/>'
		. '<feMorphology in="shape" operator="dilate" radius="' . max(0.8, $n(2.2)) . '" result="fat"/>'
		. '<feFlood flood-color="#0e0806"/><feComposite in2="fat" operator="in" result="outline"/>'
		. '<feGaussianBlur in="fat" stdDeviation="' . $n(5) . '" result="sb"/><feOffset in="sb" dy="' . $n(6) . '" result="so"/>'
		. '<feFlood flood-color="#000" flood-opacity=".75"/><feComposite in2="so" operator="in" result="shadow"/>'
		. '<feMerge><feMergeNode in="shadow"/><feMergeNode in="outline"/><feMergeNode in="lit"/></feMerge>'
		. '</filter>';
};
?>
<svg class="v-defs" width="0" height="0" aria-hidden="true" focusable="false"><?= $carve('carve-lg', 1); ?><?= $carve('carve-md', 0.5); ?><?= $carve('carve-sm', 0.32, 62, 1.6); ?></svg>

<?php
// Icons for the menu: one per tab, and one per link (matched on the link's page).
$navIcon = [
	'news' => '<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M9 9h6M9 13h6M9 17h3"/>',
	'account' => '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
	'community' => '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><circle cx="17" cy="9" r="2.8"/><path d="M16 14.2a5.5 5.5 0 0 1 6 5.8"/>',
	'library' => '<path d="M4 5a2 2 0 0 1 2-2h5v17H6a2 2 0 0 0-2 2z"/><path d="M20 5a2 2 0 0 0-2-2h-5v17h5a2 2 0 0 1 2 2z"/>',
	'news/archive' => '<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v10h14V9M10 13h4"/>',
	'change-log' => '<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1"/><circle cx="4.5" cy="12" r="1"/><circle cx="4.5" cy="18" r="1"/>',
	'account/manage' => '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
	'account/create' => '<circle cx="10" cy="8" r="4"/><path d="M2 21a8 8 0 0 1 13-6.2M19 14v6M16 17h6"/>',
	'account/lost' => '<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M17 6l3 3M15 8l2 2"/>',
	'downloads' => '<path d="M12 3v12M7 10l5 5 5-5"/><path d="M4 17v3h16v-3"/>',
	'rules' => '<path d="M12 3l8 3v6c0 4.5-3.4 8-8 9-4.6-1-8-4.5-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
	'characters' => '<circle cx="10" cy="8" r="4"/><path d="M2 21a8 8 0 0 1 11-7.4"/><circle cx="17.5" cy="17.5" r="2.5"/><path d="M19.5 19.5L22 22"/>',
	'online' => '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18"/>',
	'highscores' => '<path d="M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3M12 14v4M8 21h8M9 18h6"/>',
	'last-kills' => '<path d="M12 3a8 8 0 0 0-8 8c0 2.6 1.3 4.4 3 5.5V20h10v-3.5c1.7-1.1 3-2.9 3-5.5a8 8 0 0 0-8-8z"/><circle cx="9" cy="11" r="1.6"/><circle cx="15" cy="11" r="1.6"/><path d="M10 20v-2M14 20v-2"/>',
	'houses' => '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10M10 20v-6h4v6"/>',
	'guilds' => '<path d="M6 3h12v13l-6 5-6-5z"/><path d="M9 8h6M12 8v6"/>',
	'team' => '<path d="M3 8l4 4 5-7 5 7 4-4-2 11H5z"/><path d="M5 21h14"/>',
	'monsters' => '<path d="M4 10c0-4 3.6-7 8-7s8 3 8 7v9l-3-2-2.5 2-2.5-2-2.5 2L7 17l-3 2z"/><circle cx="9" cy="10" r="1.3"/><circle cx="15" cy="10" r="1.3"/>',
	'spells' => '<path d="M12 2l1.8 5.2L19 9l-5.2 1.8L12 16l-1.8-5.2L5 9l5.2-1.8z"/><path d="M18 15l.8 2.2L21 18l-2.2.8L18 21l-.8-2.2L15 18l2.2-.8z"/>',
	'ots-info' => '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',
	'commands' => '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9l3 3-3 3M12 15h5"/>',
	'exp-stages' => '<path d="M4 20V14M10 20V10M16 20V6M22 20H2"/>',
	'faq' => '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.5V14M12 17.5v.5"/>',
	'_' => '<path d="M12 4l6 8-6 8-6-8z"/>',
];
$navSvg = fn($key) => '<svg class="nav-ico" viewBox="0 0 24 24" aria-hidden="true">' . ($navIcon[$key] ?? $navIcon['_']) . '</svg>';

// The Valdoria crest: a shield over crossed swords. Used in the bar and in the hero.
$crest = function ($class) {
	return '<svg class="' . $class . '" viewBox="0 0 120 132" aria-hidden="true">
		<defs>
			<linearGradient id="crest-gold-' . $class . '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff1c4"/><stop offset=".5" stop-color="#e9b155"/><stop offset="1" stop-color="#9a5420"/></linearGradient>
			<linearGradient id="crest-field-' . $class . '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8e1f26"/><stop offset="1" stop-color="#3d0c10"/></linearGradient>
		</defs>
		<g stroke="url(#crest-gold-' . $class . ')" stroke-width="6" stroke-linecap="round"><path d="M14 18L106 116M106 18L14 116"/></g>
		<g fill="url(#crest-gold-' . $class . ')"><path d="M8 12l12 2-6 6zM112 12l-12 2 6 6z"/></g>
		<path d="M60 14l38 12v34c0 30-18 50-38 60-20-10-38-30-38-60V26z" fill="url(#crest-gold-' . $class . ')"/>
		<path d="M60 23l30 9.5V60c0 24-14 40.5-30 49-16-8.5-30-25-30-49V32.5z" fill="url(#crest-field-' . $class . ')"/>
		<path d="M44 52l8 7 8-14 8 14 8-7-3 22H47z" fill="url(#crest-gold-' . $class . ')"/>
		<path d="M47 79h26" stroke="url(#crest-gold-' . $class . ')" stroke-width="4"/>
		<path d="M60 86l5 7-5 7-5-7z" fill="#ffd27a"/>
	</svg>';
};
?>
<header class="topbar" id="topbar">
	<div class="wrap topbar-inner">
		<a class="brand" href="<?= getLink('news'); ?>">
			<?= $crest('brand-mark'); ?>
			<span><?= $h($serverName); ?></span>
		</a>

		<nav class="mainnav" aria-label="Main">
			<ul class="mainnav-list">
			<?php foreach ($config['menu_categories'] as $id => $cat): if (empty($menus[$id])) continue; ?>
				<li class="mainnav-item<?= $id === $activeCategory ? ' is-current' : ''; ?>">
					<button type="button" class="mainnav-tab" aria-expanded="false" aria-controls="menu-<?= $cat['id']; ?>">
						<?= $navSvg($cat['id']); ?><span><?= $h($cat['name']); ?></span>
					</button>
					<div class="mainnav-drop" id="menu-<?= $cat['id']; ?>">
						<ul class="dropdown-panel">
						<?php foreach ($menus[$id] as $link): $target = trim($link['link'], '/'); $here = $target === PAGE; ?>
							<li><a href="<?= $link['link_full']; ?>"<?= $link['target_blank']; ?><?= $here ? ' class="is-here" aria-current="page"' : ''; ?>><?= $navSvg($target); ?><span><?= $link['name']; ?></span></a></li>
						<?php endforeach; ?>
						</ul>
					</div>
				</li>
			<?php endforeach; ?>
			</ul>
		</nav>

		<span class="topbar-status state <?= $online ? 'is-on' : 'is-off'; ?>" title="Server <?= $online ? 'online' : 'offline'; ?>">
			<?php if ($online): ?><span class="topbar-count"><?= $players; ?></span> online<?php else: ?>Offline<?php endif; ?>
		</span>
		<a class="btn btn-gold topbar-cta" href="<?= $logged ? getLink('account/manage') : getLink('account/create'); ?>">
			<?= $logged ? 'My Account' : 'Play Free'; ?>
		</a>
	</div>
	<script>
	// Each tab opens its menu on hover (mouse) or click (touch and keyboard). One menu at a time.
	(function () {
		var items = document.querySelectorAll('.mainnav-item');
		var hover = window.matchMedia('(hover: hover) and (pointer: fine)');
		var timer;
		function open(item, on) {
			item.classList.toggle('is-open', on);
			item.querySelector('.mainnav-tab').setAttribute('aria-expanded', on ? 'true' : 'false');
		}
		function closeAll(except) {
			items.forEach(function (it) { if (it !== except) open(it, false); });
		}
		items.forEach(function (item) {
			item.querySelector('.mainnav-tab').addEventListener('click', function () {
				var on = !item.classList.contains('is-open');
				closeAll(item);
				open(item, on);
			});
			item.addEventListener('mouseenter', function () {
				if (!hover.matches) return;
				clearTimeout(timer);
				closeAll(item);
				open(item, true);
			});
			item.addEventListener('mouseleave', function () {
				if (!hover.matches) return;
				timer = setTimeout(function () { open(item, false); }, 160);
			});
		});
		document.addEventListener('click', function (e) {
			if (!e.target.closest('.mainnav-item')) closeAll();
		});
		document.addEventListener('keydown', function (e) {
			if (e.key !== 'Escape') return;
			var current = document.querySelector('.mainnav-item.is-open');
			closeAll();
			if (current) current.querySelector('.mainnav-tab').focus();
		});
	})();
	</script>
</header>

<?php
// The hero scene: a castle on a rocky crag against a setting sun, pine forests below.
mt_srand(7713);
$pines = function ($from, $to, $base, $minH, $maxH, $fill) {
	$out = '';
	for ($x = $from; $x < $to; $x += mt_rand(14, 26)) {
		$hgt = mt_rand($minH, $maxH);
		$w = $hgt * 0.36;
		$out .= '<path d="M' . $x . ' ' . ($base - $hgt) . 'L' . round($x + $w) . ' ' . $base . 'H' . round($x - $w) . 'Z"/>';
		$out .= '<path d="M' . $x . ' ' . round($base - $hgt * 1.08) . 'L' . round($x + $w * 0.7) . ' ' . round($base - $hgt * 0.45) . 'H' . round($x - $w * 0.7) . 'Z"/>';
	}
	return '<g fill="' . $fill . '">' . $out . '</g>';
};
// A tower: body, battlements or a pointed roof, a lit window and an optional banner.
$tower = function ($x, $top, $w, $bottom, $roof, $flag = false) {
	$out = '<rect x="' . $x . '" y="' . $top . '" width="' . $w . '" height="' . ($bottom - $top) . '"/>';
	if ($roof) {
		$out .= '<path d="M' . ($x - 4) . ' ' . $top . 'L' . ($x + $w / 2) . ' ' . ($top - $w * 1.3) . 'L' . ($x + $w + 4) . ' ' . $top . 'Z"/>';
		$tip = $top - $w * 1.3;
	} else {
		for ($cx = $x; $cx < $x + $w; $cx += 8) {
			$out .= '<rect x="' . $cx . '" y="' . ($top - 7) . '" width="5" height="7"/>';
		}
		$tip = $top - 7;
	}
	if ($flag) {
		$px = $x + $w / 2;
		$out .= '<path d="M' . $px . ' ' . $tip . 'V' . ($tip - 26) . '" stroke="#120708" stroke-width="2"/>';
		$out .= '<path class="flag" d="M' . $px . ' ' . ($tip - 26) . 'h22l-6 6 6 6h-22z" fill="#a8262f"/>';
	}
	return $out;
};
$windows = [[1236, 300], [1290, 262], [1290, 300], [1347, 318], [1188, 352], [1395, 360], [1314, 205]];
?>
<section class="hero" aria-label="<?= $h($serverName); ?>">
	<svg class="hero-art" viewBox="0 0 1600 640" preserveAspectRatio="<?= $isHome ? 'xMidYMax' : 'xMidYMid'; ?> slice" aria-hidden="true">
		<defs>
			<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
				<stop offset="0" stop-color="#14080a" />
				<stop offset="0.35" stop-color="#3d1218" />
				<stop offset="0.62" stop-color="#93361b" />
				<stop offset="0.8" stop-color="#e2812f" />
				<stop offset="1" stop-color="#f6b45a" />
			</linearGradient>
			<radialGradient id="sunglow" cx="0.5" cy="0.5" r="0.5">
				<stop offset="0" stop-color="#ffd58a" stop-opacity="0.9" />
				<stop offset="0.25" stop-color="#ffa24a" stop-opacity="0.45" />
				<stop offset="1" stop-color="#ff7a2e" stop-opacity="0" />
			</radialGradient>
			<radialGradient id="readable" cx="0.5" cy="0.5" r="0.5">
				<stop offset="0" stop-color="#0e0506" stop-opacity="0.7" />
				<stop offset="1" stop-color="#0e0506" stop-opacity="0" />
			</radialGradient>
			<linearGradient id="fog" x1="0" y1="0" x2="0" y2="1">
				<stop offset="0" stop-color="#ffb37a" stop-opacity="0" />
				<stop offset="1" stop-color="#ffb37a" stop-opacity="0.22" />
			</linearGradient>
			<linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
				<stop offset="0" stop-color="#0d0606" stop-opacity="0" />
				<stop offset="1" stop-color="#0d0606" />
			</linearGradient>
			<filter id="soft"><feGaussianBlur stdDeviation="10" /></filter>
			<filter id="haze" x="-10%" y="-200%" width="120%" height="500%"><feGaussianBlur stdDeviation="4" /></filter>
		</defs>

		<rect width="1600" height="640" fill="url(#sky)" />
		<g fill="#ffe9cc">
			<?php for ($i = 0; $i < 70; $i++): $tw = $i % 3 === 0; ?>
			<circle<?= $tw ? ' class="tw" style="animation-delay:-' . mt_rand(0, 60) / 10 . 's"' : ''; ?> cx="<?= mt_rand(0, 1600); ?>" cy="<?= mt_rand(0, 200); ?>" r="<?= mt_rand(4, 13) / 10; ?>" opacity="<?= mt_rand(30, 90) / 100; ?>" />
			<?php endfor; ?>
		</g>

		<!-- sun and its rays, behind the castle -->
		<g class="rays" fill="#ffd28a" opacity="0.12">
			<?php for ($a = -80; $a <= 80; $a += 16): $r = deg2rad($a - 90); $r2 = deg2rad($a - 90 + 5); ?>
			<path d="M1300 300L<?= round(1300 + cos($r) * 900); ?> <?= round(300 + sin($r) * 900); ?>L<?= round(1300 + cos($r2) * 900); ?> <?= round(300 + sin($r2) * 900); ?>Z" />
			<?php endfor; ?>
		</g>
		<circle cx="1300" cy="300" r="260" fill="url(#sunglow)" />
		<circle cx="1300" cy="300" r="78" fill="#ffe2a6" />

		<!-- clouds -->
		<g class="clouds" fill="#ffb27a" filter="url(#haze)">
			<ellipse cx="300" cy="190" rx="260" ry="10" opacity="0.18" />
			<ellipse cx="420" cy="212" rx="180" ry="6" opacity="0.14" />
			<ellipse cx="980" cy="160" rx="300" ry="9" opacity="0.14" />
			<ellipse cx="1420" cy="230" rx="240" ry="8" opacity="0.22" />
			<ellipse cx="1180" cy="248" rx="200" ry="6" opacity="0.2" />
		</g>


		<!-- far peaks -->
		<path fill="#7a2f22" opacity="0.75" d="M0 400L90 330L170 360L260 280L360 350L450 300L560 360L650 290L760 350L860 300L960 360L1040 330L1600 330V640H0Z" />
		<path fill="#4b1c19" d="M0 440L110 380L220 410L330 350L440 400L540 370L650 420L760 380L860 430L960 400L1060 440L1600 440V640H0Z" />
		<rect y="380" width="1600" height="120" fill="url(#fog)" />

		<!-- the cliff and castle -->
		<g fill="#120708">
			<path d="M1030 640L1062 584L1088 566L1104 530L1128 516L1140 482L1160 462L1158 430L1172 404L1170 392H1430L1440 412L1458 424L1466 452L1492 470L1500 498L1530 514L1546 548L1574 566L1600 574V640Z" />
			<rect x="1170" y="330" width="260" height="62" />
			<?php for ($cx = 1170; $cx < 1430; $cx += 12): ?><rect x="<?= $cx; ?>" y="322" width="7" height="8" /><?php endfor; ?>
			<?= $tower(1176, 280, 30, 392, true, true); ?>
			<?= $tower(1220, 250, 40, 392, false); ?>
			<?= $tower(1270, 214, 44, 392, false, true); ?>
			<?= $tower(1300, 160, 26, 230, true, true); ?>
			<?= $tower(1332, 270, 36, 392, false); ?>
			<?= $tower(1384, 236, 30, 392, true, true); ?>
			<rect x="1278" y="350" width="28" height="42" rx="14" fill="#2b0f0c" />
		</g>
		<!-- sunlit edges on the crag -->
		<g fill="none" stroke="#ff9a4a" stroke-linecap="round" stroke-linejoin="round" opacity="0.35">
			<path d="M1172 404L1158 430L1160 462L1140 482L1128 516L1104 530" stroke-width="2.5" />
			<path d="M1430 392L1440 412L1458 424L1466 452L1492 470" stroke-width="2" />
		</g>
		<g fill="#ffbe63">
			<?php foreach ($windows as $i => [$wx, $wy]): ?>
			<rect class="lit" style="animation-delay:-<?= $i * 0.7; ?>s" x="<?= $wx; ?>" y="<?= $wy; ?>" width="6" height="10" rx="3" />
			<?php endforeach; ?>
		</g>

		<!-- forests -->
		<?= $pines(-10, 1060, 520, 40, 70, '#2a0f10'); ?>
		<path fill="#1b0a0b" d="M0 520Q300 490 600 515T1100 520V640H0Z" />
		<g class="mist"><ellipse cx="600" cy="520" rx="600" ry="26" fill="#ffb07a" opacity="0.14" filter="url(#soft)" /></g>
		<?= $pines(-10, 520, 640, 90, 150, '#0d0606'); ?>
		<?= $pines(1000, 1180, 640, 50, 90, '#0d0606'); ?>
		<?= $pines(1480, 1620, 640, 90, 150, '#0d0606'); ?>
		<rect y="560" width="1600" height="80" fill="url(#ground)" />

		<!-- darker pool behind the text so it stays readable -->
		<ellipse class="readable" cx="560" cy="300" rx="620" ry="260" fill="url(#readable)" />
	</svg>
	<?php mt_srand(); ?>
	<div class="embers" aria-hidden="true">
		<?php for ($i = 1; $i <= 16; $i++): ?><span style="--x:<?= ($i * 7.3) % 100; ?>%;--d:<?= 6 + ($i * 1.7) % 7; ?>s;--delay:-<?= ($i * 1.3) % 9; ?>s"></span><?php endfor; ?>
	</div>

	<div class="wrap hero-inner">
		<?php if ($isHome): ?>
			<?= $crest('hero-crest'); ?>
			<p class="eyebrow">Your adventure awaits</p>
			<h1 class="hero-title"><?= $h($serverName); ?></h1>
			<div class="flourish" aria-hidden="true"><span></span><i></i><span></span></div>
			<p class="hero-lede">Ancient keeps, deep dungeons and untamed wilds. Gather a party, claim your glory, and carve your name into the highscores.</p>
			<div class="hero-actions">
				<a class="btn btn-gold btn-lg" href="<?= getLink('account/create'); ?>">Create a free account</a>
				<a class="btn btn-ghost btn-lg" href="<?= getLink('downloads'); ?>">Download our client</a>
			</div>
			<p class="realm-status">
				<span class="state <?= $online ? 'is-on' : 'is-off'; ?>"><?= $online ? 'Online' : 'Offline'; ?></span>
				<?php if ($online): ?><span><strong><?= $players; ?></strong> <?= $players === 1 ? 'player' : 'players'; ?> online</span>
				<?php else: ?><span>The realm is resting. Check back soon.</span><?php endif; ?>
			</p>
		<?php else: ?>
			<p class="eyebrow"><?= $h($eyebrow); ?></p>
			<h1 class="hero-title hero-title-sm"><?= $h($heading); ?></h1>
			<div class="flourish" aria-hidden="true"><span></span><i></i><span></span></div>
		<?php endif; ?>
	</div>
</section>

<?php if ($isHome): ?>
<section class="wrap journey" aria-labelledby="journey-title">
	<h2 class="section-title" id="journey-title"><span>Begin your journey</span></h2>
	<ol class="steps">
		<li class="step">
			<span class="step-no">1</span>
			<?= $svg('scroll'); ?>
			<h3>Create an account</h3>
			<p>Pick an account name and a password, then make your first character.</p>
			<a href="<?= getLink('account/create'); ?>">Create account</a>
		</li>
		<li class="step">
			<span class="step-no">2</span>
			<?= $svg('gem'); ?>
			<h3>Get the client</h3>
			<p>Download our game client, install it, and you're ready to play.</p>
			<a href="<?= getLink('downloads'); ?>">Download our client</a>
		</li>
		<li class="step">
			<span class="step-no">3</span>
			<?= $svg('door'); ?>
			<h3>Log in and play</h3>
			<p>Log in with your account, pick your character, and step into the world.</p>
			<a href="<?= getLink('online'); ?>">See who's online</a>
		</li>
	</ol>
</section>
<?php endif; ?>

<div class="wrap layout">
	<main class="main" id="content">
		<article class="card page">
			<header class="page-head">
				<p class="crumbs"><a href="<?= getLink('news'); ?>"><?= $h($serverName); ?></a> <span aria-hidden="true">/</span> <?= $h($heading); ?></p>
			</header>
			<div class="Content">
				<?= tickers() . template_place_holder('center_top') . $content; ?>
			</div>
		</article>

		<?php if ($isHome): ?>
		<section class="features" aria-label="What awaits you">
			<div class="feature card tint-ember">
				<?= $svg('sword'); ?>
				<h3>Classic 10.98 combat</h3>
				<p>Knights, paladins, sorcerers and druids, with the skills, spells and runes you remember.</p>
			</div>
			<div class="feature card tint-emerald">
				<?= $svg('map'); ?>
				<h3>Hunt the wilds</h3>
				<p>Caves, forests and ruins full of creatures, loot and quests waiting past the town gates.</p>
			</div>
			<div class="feature card tint-royal">
				<?= $svg('keep'); ?>
				<h3>Guilds &amp; houses</h3>
				<p>Found a guild, buy a house in town, and make the island yours.</p>
			</div>
		</section>
		<?php endif; ?>
	</main>

	<aside class="sidebar" aria-label="Account and server">
		<section class="card box">
			<?php if ($logged): $accName = (string)(USE_ACCOUNT_NAME ? $account_logged->getName() : $account_logged->getId()); ?>
				<div class="me">
					<span class="me-initial" aria-hidden="true"><?= $h(strtoupper(substr($accName, 0, 1))); ?></span>
					<span class="me-text"><strong><?= $h($accName); ?></strong><small>Signed in</small></span>
				</div>
				<a class="btn btn-gold btn-block" href="<?= getLink('account/manage'); ?>">My account</a>
				<div class="me-actions">
					<a class="btn" href="<?= getLink('account/character/create'); ?>">New character</a>
					<a class="btn" href="<?= getLink('account/logout'); ?>">Log out</a>
				</div>
			<?php else: ?>
				<h2 class="box-title">Log in</h2>
				<form class="login" action="<?= getLink('account/manage'); ?>" method="post">
					<?= csrf(true); ?>
					<label for="side-account">Account name</label>
					<input id="side-account" type="text" name="account_login" autocomplete="username" required>
					<label for="side-password">Password</label>
					<input id="side-password" type="password" name="password_login" autocomplete="current-password" required>
					<button class="btn btn-gold btn-block" type="submit">Log in</button>
				</form>
				<p class="box-small"><a href="<?= getLink('account/create'); ?>">Create an account</a> · <a href="<?= getLink('account/lost'); ?>">Lost account?</a></p>
			<?php endif; ?>
		</section>

		<section class="card box">
			<div class="box-head">
				<h2 class="box-title">Server</h2>
				<span class="state <?= $online ? 'is-on' : 'is-off'; ?>"><?= $online ? 'Online' : 'Offline'; ?></span>
			</div>
			<a class="players <?= $online ? 'is-on' : 'is-off'; ?>" href="<?= getLink('online'); ?>">
				<span class="players-count"><?= $online ? $players : 0; ?></span>
				<span class="players-label">Players online</span>
			</a>
		</section>

		<section class="card box">
			<h2 class="box-title">Top players</h2>
			<?php if (!empty($topPlayers)): ?>
			<ol class="top">
				<?php foreach ($topPlayers as $i => $p): ?>
				<li class="rank-<?= $i + 1; ?>">
					<span class="top-rank num"><?= $i + 1; ?></span>
					<span class="top-name"><?= getPlayerLink($p['name']); ?><small><?= $h($vocations[$p['vocation']] ?? ''); ?></small></span>
					<span class="top-level num"><?= (int)$p['level']; ?></span>
					<span class="top-bar" style="--w:<?= round(100 * (int)$p['level'] / $topLevel); ?>%"></span>
				</li>
				<?php endforeach; ?>
			</ol>
			<p class="box-small"><a href="<?= getLink('highscores'); ?>">Full highscores</a></p>
			<?php else: ?>
			<p class="box-empty">No heroes yet. The first to level up takes the top spot.</p>
			<?php endif; ?>
		</section>
	</aside>
</div>

<footer class="footer">
	<div class="wrap footer-top">
		<a class="footer-brand" href="<?= getLink('news'); ?>"><?= $crest('footer-crest'); ?><span><?= $h($serverName); ?></span></a>
		<nav class="footer-nav" aria-label="Footer">
			<a href="<?= getLink('account/create'); ?>">Create account</a>
			<a href="<?= getLink('downloads'); ?>">Download</a>
			<a href="<?= getLink('highscores'); ?>">Highscores</a>
			<a href="<?= getLink('online'); ?>">Who is online</a>
			<a href="<?= getLink('guilds'); ?>">Guilds</a>
			<a href="<?= getLink('rules'); ?>">Rules</a>
		</nav>
		<a class="btn btn-discord" href="<?= $h($discordUrl); ?>" target="_blank" rel="noopener">
			<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20.3 4.4A19.8 19.8 0 0 0 15.4 3l-.6 1.3a18.4 18.4 0 0 0-5.6 0L8.6 3a19.7 19.7 0 0 0-4.9 1.4C.6 9 -.3 13.5.1 18a19.9 19.9 0 0 0 6 3l1.3-2.1a12.9 12.9 0 0 1-2-1l.5-.4a14.2 14.2 0 0 0 12.2 0l.5.4c-.7.4-1.3.7-2 1l1.3 2.1a19.8 19.8 0 0 0 6-3c.5-5.2-.8-9.7-3.6-13.6zM8.3 15.3c-1.2 0-2.2-1.1-2.2-2.4s1-2.4 2.2-2.4 2.2 1.1 2.2 2.4-1 2.4-2.2 2.4zm7.4 0c-1.2 0-2.2-1.1-2.2-2.4s1-2.4 2.2-2.4 2.2 1.1 2.2 2.4-1 2.4-2.2 2.4z"/></svg>
			Join our Discord
		</a>
	</div>
	<div class="wrap footer-bottom">
		<span>&copy; <?= date('Y'); ?> <?= $h($serverName); ?></span>
		<span><?php if (admin()): ?><a href="<?= ADMIN_URL; ?>">Admin panel</a> · <?php endif; ?>Powered by <a href="https://my-aac.org" target="_blank" rel="noopener">MyAAC</a></span>
	</div>
</footer>

<?= template_place_holder('body_end'); ?>
</body>
</html>
