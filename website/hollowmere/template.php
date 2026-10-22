<?php
/**
 * Hollowmere: a custom MyAAC template.
 * Layout: top bar with menus, a moonlit hero, then the page in a card beside a sidebar
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

$serverName = $config['lua']['serverName'] ?? 'Hollowmere';
$isHome = in_array(PAGE, ['', 'news'], true);
$online = !empty($status['online']);
$players = (int)($status['players'] ?? 0);
$serverIp = configLua('ip') ?: '127.0.0.1';
$loginPort = (int)(configLua('loginProtocolPort') ?: 7171);
$vocations = config('vocations') ?? [];
$topPlayers = [];
try {
	$topPlayers = getTopPlayers(5);
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
	<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Alegreya+Sans:wght@400;500;700;800&family=IM+Fell+English+SC&family=Spline+Sans+Mono:wght@400;500&display=swap">
	<link rel="stylesheet" href="<?= $template_path; ?>/style.css">
	<?= template_place_holder('head_end'); ?>
</head>
<body class="<?= $isHome ? 'is-home' : 'is-page'; ?>">
<?= template_place_holder('body_start'); ?>

<header class="topbar" id="topbar">
	<div class="wrap topbar-inner">
		<a class="brand" href="<?= getLink('news'); ?>">
			<svg class="brand-mark" viewBox="0 0 32 32" aria-hidden="true">
				<circle cx="21" cy="10" r="5" />
				<path d="M2 26 L11 14 L16 20 L21 15 L30 26 Z" />
			</svg>
			<span><?= $h($serverName); ?></span>
		</a>

		<button class="nav-toggle" type="button" aria-expanded="false" aria-controls="mainnav"
			onclick="var o=document.getElementById('topbar').classList.toggle('nav-open');this.setAttribute('aria-expanded',o);">
			Menu
		</button>

		<nav class="mainnav" id="mainnav" aria-label="Main">
			<ul>
			<?php foreach ($config['menu_categories'] as $id => $cat): if (empty($menus[$id])) continue; ?>
				<li class="navgroup">
					<button type="button" class="navgroup-label"><?= $h($cat['name']); ?></button>
					<ul class="navgroup-menu">
					<?php foreach ($menus[$id] as $link): ?>
						<li><a href="<?= $link['link_full']; ?>"<?= $link['target_blank']; ?>><?= $link['name']; ?></a></li>
					<?php endforeach; ?>
					</ul>
				</li>
			<?php endforeach; ?>
			</ul>
		</nav>

		<span class="topbar-status <?= $online ? 'is-on' : 'is-off'; ?>" title="Server <?= $online ? 'online' : 'offline'; ?>">
			<span class="dot <?= $online ? 'dot-on' : 'dot-off'; ?>"></span><?= $online ? $players . ' online' : 'Offline'; ?>
		</span>
		<a class="btn btn-gold topbar-cta" href="<?= $logged ? getLink('account/manage') : getLink('account/create'); ?>">
			<?= $logged ? 'My Account' : 'Play Free'; ?>
		</a>
	</div>
</header>

<section class="hero" aria-label="<?= $h($serverName); ?>">
	<svg class="hero-art" viewBox="0 0 1600 560" preserveAspectRatio="xMidYMax slice" aria-hidden="true">
		<defs>
			<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
				<stop offset="0" stop-color="#05070e" />
				<stop offset="0.55" stop-color="#141c2a" />
				<stop offset="1" stop-color="#2a2a33" />
			</linearGradient>
			<radialGradient id="moonglow" cx="0.5" cy="0.5" r="0.5">
				<stop offset="0" stop-color="#f3e3b4" stop-opacity="0.5" />
				<stop offset="1" stop-color="#f3e3b4" stop-opacity="0" />
			</radialGradient>
			<radialGradient id="horizon" cx="0.5" cy="1" r="0.7">
				<stop offset="0" stop-color="#c8743a" stop-opacity="0.22" />
				<stop offset="1" stop-color="#c8743a" stop-opacity="0" />
			</radialGradient>
			<linearGradient id="lake" x1="0" y1="0" x2="0" y2="1">
				<stop offset="0" stop-color="#1a2430" />
				<stop offset="1" stop-color="#080c10" />
			</linearGradient>
			<filter id="soft"><feGaussianBlur stdDeviation="14" /></filter>
		</defs>
		<rect width="1600" height="560" fill="url(#sky)" />
		<rect y="160" width="1600" height="300" fill="url(#horizon)" />
		<g fill="#e8ecf2">
			<?php mt_srand(7713); for ($i = 0; $i < 110; $i++): $tw = $i % 4 === 0; ?>
			<circle<?= $tw ? ' class="tw" style="animation-delay:-' . mt_rand(0, 60) / 10 . 's"' : ''; ?> cx="<?= mt_rand(0, 1600); ?>" cy="<?= mt_rand(0, 320); ?>" r="<?= mt_rand(4, 14) / 10; ?>" opacity="<?= mt_rand(25, 90) / 100; ?>" />
			<?php endfor; mt_srand(); ?>
		</g>
		<circle cx="1180" cy="128" r="150" fill="url(#moonglow)" />
		<circle cx="1180" cy="128" r="40" fill="#f2e6c6" />
		<circle cx="1166" cy="118" r="7" fill="#e2d4ae" opacity="0.6" />
		<circle cx="1192" cy="140" r="5" fill="#e2d4ae" opacity="0.5" />
		<path d="M0 380 L120 300 L210 340 L330 245 L430 320 L520 280 L640 340 L760 255 L880 330 L990 290 L1110 340 L1240 265 L1360 330 L1480 280 L1600 320 L1600 560 L0 560 Z" fill="#1c2430" />
		<g class="mist mist-a"><ellipse cx="500" cy="400" rx="520" ry="34" fill="#9fb0c2" opacity="0.10" filter="url(#soft)" /></g>
		<path d="M0 420 L90 368 L200 400 L300 345 L380 385 L470 355 L590 405 L700 360 L800 400 L900 365 L1010 410 L1120 370 L1230 405 L1350 360 L1460 395 L1600 365 L1600 560 L0 560 Z" fill="#121921" />
		<g class="keep">
			<path d="M612 412 L626 376 L632 376 L632 350 L644 350 L644 364 L654 364 L654 334 L664 318 L674 334 L674 364 L684 364 L684 350 L696 350 L696 376 L702 376 L716 412 Z" fill="#0e141b" />
			<rect class="lit" x="660" y="342" width="7" height="10" rx="3" fill="#f2b85c" />
			<rect class="lit lit-2" x="637" y="383" width="5" height="8" rx="2" fill="#f2b85c" />
			<rect class="lit lit-3" x="687" y="383" width="5" height="8" rx="2" fill="#f2b85c" />
		</g>
		<g class="mist mist-b"><ellipse cx="1100" cy="430" rx="600" ry="26" fill="#9fb0c2" opacity="0.09" filter="url(#soft)" /></g>
		<rect y="436" width="1600" height="124" fill="url(#lake)" />
		<g class="hero-reflection" stroke="#f2e6c6" stroke-linecap="round">
			<line x1="1150" y1="456" x2="1210" y2="456" stroke-width="2" />
			<line x1="1128" y1="474" x2="1232" y2="474" stroke-width="1.5" />
			<line x1="1160" y1="492" x2="1200" y2="492" stroke-width="1.5" />
			<line x1="1118" y1="512" x2="1242" y2="512" stroke-width="1" />
		</g>
		<g class="hero-reflection" stroke="#f2b85c" stroke-linecap="round">
			<line x1="656" y1="452" x2="672" y2="452" stroke-width="2" />
			<line x1="652" y1="466" x2="676" y2="466" stroke-width="1" />
		</g>
	</svg>
	<div class="embers" aria-hidden="true">
		<?php for ($i = 1; $i <= 14; $i++): ?><span style="--x:<?= ($i * 7.3) % 100; ?>%;--d:<?= 6 + ($i * 1.7) % 7; ?>s;--delay:-<?= ($i * 1.3) % 9; ?>s"></span><?php endfor; ?>
	</div>

	<div class="wrap hero-inner">
		<p class="eyebrow">Old-school MMORPG · Client 10.98</p>
		<?php if ($isHome): ?>
			<h1 class="hero-title"><?= $h($serverName); ?></h1>
			<p class="hero-lede">A small island realm of reeds, thorns and ash. Gather a party, take on the wilds, and carve your name into the highscores.</p>
			<div class="hero-actions">
				<a class="btn btn-gold btn-lg" href="<?= getLink('account/create'); ?>">Create a free account</a>
				<a class="btn btn-ghost btn-lg" href="<?= getLink('downloads'); ?>">How to connect</a>
			</div>
		<?php else: ?>
			<h1 class="hero-title hero-title-sm"><?= $h($title); ?></h1>
		<?php endif; ?>
		<ul class="hero-stats" aria-label="Server status">
			<li><span class="dot <?= $online ? 'dot-on' : 'dot-off'; ?>"></span><?= $online ? 'Online' : 'Offline'; ?></li>
			<?php if ($online): ?>
			<li><strong><?= $players; ?></strong> playing now</li>
			<li>Up <?= $h($status['uptimeReadable'] ?? 'just now'); ?></li>
			<?php endif; ?>
			<li class="num"><?= $h($serverIp); ?>:<?= $loginPort; ?></li>
		</ul>
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
			<p>Any 10.98 client works, OTClient included. Point it at our server.</p>
			<a href="<?= getLink('downloads'); ?>">Download &amp; setup</a>
		</li>
		<li class="step">
			<span class="step-no">3</span>
			<?= $svg('door'); ?>
			<h3>Log in and play</h3>
			<p>Connect to <span class="num"><?= $h($serverIp); ?></span>, port <span class="num"><?= $loginPort; ?></span>, and step into the world.</p>
			<a href="<?= getLink('online'); ?>">See who's online</a>
		</li>
	</ol>
</section>
<?php endif; ?>

<div class="wrap layout">
	<main class="main" id="content">
		<article class="card page">
			<header class="page-head">
				<p class="crumbs"><a href="<?= getLink('news'); ?>"><?= $h($serverName); ?></a> <span aria-hidden="true">/</span> <?= $h($title); ?></p>
			</header>
			<div class="Content">
				<?= tickers() . template_place_holder('center_top') . $content; ?>
			</div>
		</article>

		<?php if ($isHome): ?>
		<section class="features" aria-label="What awaits you">
			<div class="feature card">
				<?= $svg('sword'); ?>
				<h3>Classic 10.98 combat</h3>
				<p>Knights, paladins, sorcerers and druids, with the skills, spells and runes you remember.</p>
			</div>
			<div class="feature card">
				<?= $svg('map'); ?>
				<h3>Hunt the wilds</h3>
				<p>Caves, forests and ruins full of creatures, loot and quests waiting past the town gates.</p>
			</div>
			<div class="feature card">
				<?= $svg('keep'); ?>
				<h3>Guilds &amp; houses</h3>
				<p>Found a guild, buy a house in town, and make the island yours.</p>
			</div>
		</section>
		<?php endif; ?>
	</main>

	<aside class="sidebar" aria-label="Account and server">
		<section class="card box">
			<?php if ($logged): ?>
				<h2 class="box-title">Your account</h2>
				<p class="box-welcome">Welcome back, <strong><?= $h(USE_ACCOUNT_NAME ? $account_logged->getName() : $account_logged->getId()); ?></strong>.</p>
				<ul class="box-links">
					<li><a href="<?= getLink('account/manage'); ?>">Manage account</a></li>
					<li><a href="<?= getLink('account/character/create'); ?>">Create a character</a></li>
					<li><a href="<?= getLink('account/logout'); ?>">Log out</a></li>
				</ul>
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
			<h2 class="box-title">Server</h2>
			<div class="players <?= $online ? 'is-on' : 'is-off'; ?>">
				<span class="players-count num"><?= $online ? $players : '–'; ?></span>
				<span class="players-label"><?= $online ? 'adventurers online' : 'The server is offline'; ?></span>
			</div>
			<dl class="facts">
				<div><dt>Address</dt><dd class="num"><?= $h($serverIp); ?></dd></div>
				<div><dt>Port</dt><dd class="num"><?= $loginPort; ?></dd></div>
				<div><dt>Client</dt><dd class="num">10.98</dd></div>
				<div><dt>World</dt><dd><?= $h(ucfirst((string)(configLua('worldType') ?: 'pvp'))); ?></dd></div>
				<?php if ($online && !empty($status['uptimeReadable'])): ?>
				<div><dt>Uptime</dt><dd><?= $h($status['uptimeReadable']); ?></dd></div>
				<?php endif; ?>
			</dl>
			<p class="box-small"><a href="<?= getLink('downloads'); ?>">How to connect</a> · <a href="<?= getLink('exp-stages'); ?>">Rates</a></p>
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
	<svg class="treeline" viewBox="0 0 1600 60" preserveAspectRatio="none" aria-hidden="true">
		<path d="M0 60 L0 40 L30 42 L40 22 L52 40 L80 38 L96 14 L112 38 L150 40 L170 26 L186 40 L240 36 L262 10 L284 36 L330 40 L350 24 L368 40 L420 38 L446 16 L470 38 L520 42 L540 28 L558 42 L610 38 L636 12 L660 38 L720 40 L742 24 L762 40 L820 36 L846 8 L872 36 L930 42 L950 26 L970 42 L1030 38 L1056 16 L1080 38 L1140 40 L1160 22 L1180 40 L1240 36 L1266 10 L1290 36 L1350 42 L1370 26 L1390 42 L1450 38 L1476 14 L1500 38 L1560 40 L1580 24 L1600 40 L1600 60 Z" />
	</svg>
	<div class="wrap footer-inner">
		<div class="footer-brand">
			<p class="footer-name"><?= $h($serverName); ?></p>
			<p class="footer-tag">An old-school 10.98 realm.</p>
		</div>
		<nav class="footer-links" aria-label="Footer">
			<div>
				<h2>Play</h2>
				<a href="<?= getLink('account/create'); ?>">Create account</a>
				<a href="<?= getLink('downloads'); ?>">How to connect</a>
				<a href="<?= getLink('rules'); ?>">Server rules</a>
			</div>
			<div>
				<h2>Community</h2>
				<a href="<?= getLink('highscores'); ?>">Highscores</a>
				<a href="<?= getLink('online'); ?>">Who is online</a>
				<a href="<?= getLink('guilds'); ?>">Guilds</a>
			</div>
		</nav>
	</div>
	<div class="wrap footer-small"><?= template_footer(); ?></div>
</footer>

<?= template_place_holder('body_end'); ?>
</body>
</html>
