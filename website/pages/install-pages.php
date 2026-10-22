<?php
// Replaces MyAAC's sample Downloads, Commands and Rules pages with Valdoria's own.
// A page is only replaced while it still holds MyAAC's sample text, so your own edits are kept.
// Usage: php install-pages.php <host> <user> <password> <database>
[, $host, $user, $pass, $name] = $argv + [null, '127.0.0.1', '', '', ''];

$db = new PDO("mysql:host=$host;dbname=$name;charset=utf8mb4", $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$rules = trim(file_get_contents(__DIR__ . '/rules.txt'));

// Turn the plain-text rules into headings and lists for the Rules page.
$html = '';
foreach (preg_split('/\R{2,}/', $rules) as $block) {
	$lines = preg_split('/\R/', $block);
	if (preg_match('/^\d+\.\s*(.+)$/', $lines[0], $m)) {
		$html .= '<h2 class="v-heading">' . htmlspecialchars($m[1]) . "</h2>\n<ul class=\"v-rules\">\n";
		foreach (array_slice($lines, 1) as $line) {
			$html .= '<li>' . htmlspecialchars(preg_replace('/^[a-z]\)\s*/', '', $line)) . "</li>\n";
		}
		$html .= "</ul>\n";
	} else {
		$html .= '<p class="v-note">' . htmlspecialchars($block) . "</p>\n";
	}
}

$pages = [
	// name => [new body, a phrase that only appears in MyAAC's sample]
	'downloads' => [file_get_contents(__DIR__ . '/downloads.html'), 'ipchanger'],
	'commands' => [file_get_contents(__DIR__ . '/commands.html'), '!example'],
	'rules' => [$html, 'CipSoft'],
	'rules_on_the_page' => [$rules, 'CipSoft'],
];
$update = $db->prepare('UPDATE myaac_pages SET body = ? WHERE name = ? AND body LIKE ?');
$changed = 0;
foreach ($pages as $page => [$body, $sample]) {
	$update->execute([$body, $page, '%' . $sample . '%']);
	$changed += $update->rowCount();
}
echo $changed > 0 ? "Updated $changed page(s).\n" : "Pages already up to date.\n";
