<?php
/**
 * GetLNMP Server Probe
 * A lightweight, single-file LNMP server probe styled after the GetLNMP
 * welcome dashboard (index2.html). Static facts are rendered server-side;
 * dynamic metrics are streamed to the browser via the ?action=stats endpoint.
 */

// ---------------------------------------------------------------------------
// Data collectors
// ---------------------------------------------------------------------------

function probe_is_linux()
{
    return \DIRECTORY_SEPARATOR === '/';
}

/**
 * Pick the first usable command-execution function that is not blocked by
 * disable_functions. Used as a fallback when open_basedir forbids reading
 * /proc directly — a child process is not subject to open_basedir.
 */
function probe_exec_fn()
{
    static $fn = false;
    if ($fn !== false) {
        return $fn;
    }
    $disabled = \array_map('trim', \explode(',', (string) \ini_get('disable_functions')));
    foreach (['shell_exec', 'exec', 'popen', 'proc_open'] as $candidate) {
        if (\function_exists($candidate) && !\in_array($candidate, $disabled, true)) {
            return $fn = $candidate;
        }
    }
    return $fn = null;
}

function probe_shell($cmd)
{
    $fn = probe_exec_fn();
    if ($fn === null) {
        return null;
    }
    try {
        switch ($fn) {
            case 'shell_exec':
                $out = @\shell_exec($cmd);
                return $out === null ? null : $out;
            case 'exec':
                $lines = [];
                @\exec($cmd, $lines);
                return \implode("\n", $lines);
            case 'popen':
                $h = @\popen($cmd, 'r');
                if (!$h) {
                    return null;
                }
                $out = '';
                while (!\feof($h)) {
                    $out .= \fread($h, 8192);
                }
                \pclose($h);
                return $out;
            case 'proc_open':
                $desc = [1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
                $p = @\proc_open($cmd, $desc, $pipes);
                if (!\is_resource($p)) {
                    return null;
                }
                $out = \stream_get_contents($pipes[1]);
                \fclose($pipes[1]);
                \fclose($pipes[2]);
                \proc_close($p);
                return $out;
        }
    } catch (\Throwable $e) {
        return null;
    }
    return null;
}

/**
 * Read a file with a shell fallback. Direct file_get_contents is the fast
 * path; if it is blocked (open_basedir) we `cat` it from a child process.
 * Returns the file contents string, or false if unreadable by any method.
 */
function probe_read($path)
{
    $data = @\file_get_contents($path);
    if ($data !== false && $data !== '') {
        return $data;
    }
    $data = probe_shell('cat ' . \escapeshellarg($path) . ' 2>/dev/null');
    return ($data !== null && $data !== '') ? $data : false;
}

function probe_lines($path)
{
    $raw = probe_read($path);
    return $raw === false ? [] : \explode("\n", $raw);
}

function probe_cpu_sample()
{
    foreach (probe_lines('/proc/stat') as $line) {
        if (\strpos($line, 'cpu ') === 0) {
            $parts = \preg_split('/\s+/', \trim($line));
            \array_shift($parts); // drop the "cpu" label
            $vals = \array_map('intval', $parts);
            $total = \array_sum($vals);
            $idle = ($vals[3] ?? 0) + ($vals[4] ?? 0); // idle + iowait
            return ['total' => $total, 'idle' => $idle];
        }
    }
    return null;
}

function probe_cpu_info()
{
    $model = 'Unknown CPU';
    $cores = 0;
    foreach (probe_lines('/proc/cpuinfo') as $line) {
        if (\stripos($line, 'model name') === 0) {
            $model = \trim(\explode(':', $line, 2)[1]);
            $cores++;
        }
    }
    if ($cores === 0) {
        // Some arches (e.g. ARM) omit "model name"; fall back to nproc/online.
        $cores = (int) \trim((string) probe_shell('nproc 2>/dev/null'));
        if ($cores < 1) {
            $cores = 1;
        }
    }
    return ['model' => $model, 'cores' => $cores];
}

function probe_meminfo()
{
    $data = [];
    foreach (probe_lines('/proc/meminfo') as $line) {
        if (\preg_match('/^(\w+):\s+(\d+)\s*kB/', $line, $m)) {
            $data[$m[1]] = (int) $m[2] * 1024;
        }
    }
    return $data;
}

function probe_net_sample()
{
    $rx = 0;
    $tx = 0;
    foreach (probe_lines('/proc/net/dev') as $line) {
        if (\strpos($line, ':') === false) {
            continue;
        }
        list($iface, $rest) = \explode(':', $line, 2);
        $iface = \trim($iface);
        if ($iface === 'lo') {
            continue;
        }
        $cols = \preg_split('/\s+/', \trim($rest));
        $rx += (int) ($cols[0] ?? 0);  // received bytes
        $tx += (int) ($cols[8] ?? 0);  // transmitted bytes
    }
    return ['rx' => $rx, 'tx' => $tx];
}

function probe_uptime()
{
    $raw = probe_read('/proc/uptime');
    if ($raw !== false) {
        $parts = \explode(' ', \trim($raw));
        return (float) $parts[0];
    }
    return null;
}

function probe_load()
{
    if (\function_exists('sys_getloadavg')) {
        $l = @\sys_getloadavg();
        if (\is_array($l) && isset($l[0])) {
            return [(float) $l[0], (float) $l[1], (float) $l[2]];
        }
    }
    $raw = probe_read('/proc/loadavg');
    if ($raw !== false) {
        $p = \preg_split('/\s+/', \trim($raw));
        return [(float) ($p[0] ?? 0), (float) ($p[1] ?? 0), (float) ($p[2] ?? 0)];
    }
    return [null, null, null];
}

function probe_disk()
{
    $total = (float) (@\disk_total_space('/') ?: 0);
    $free = (float) (@\disk_free_space('/') ?: 0);
    if ($total <= 0) {
        // disk_*_space blocked by open_basedir/disable_functions — use df.
        $raw = probe_shell('df -P -B1 / 2>/dev/null');
        if ($raw) {
            $rows = \array_values(\array_filter(\explode("\n", \trim($raw))));
            $cols = \preg_split('/\s+/', \trim((string) \end($rows)));
            // Filesystem  1B-blocks  Used  Available  Use%  Mounted-on
            if (isset($cols[1], $cols[3]) && \is_numeric($cols[1])) {
                $total = (float) $cols[1];
                $free = (float) $cols[3];
            }
        }
    }
    return ['total' => $total, 'free' => $free];
}

/**
 * Snapshot of all live-updating metrics, returned as JSON to the browser.
 * Counters (cpu, net) are returned raw; the client computes rates from the
 * delta between successive polls, so no blocking sleep is needed here.
 */
function probe_dynamic_stats()
{
    $mem = probe_meminfo();
    $memTotal = $mem['MemTotal'] ?? 0;
    $memAvail = $mem['MemAvailable']
        ?? (($mem['MemFree'] ?? 0) + ($mem['Buffers'] ?? 0) + ($mem['Cached'] ?? 0));
    $swapTotal = $mem['SwapTotal'] ?? 0;
    $swapFree = $mem['SwapFree'] ?? 0;

    $disk = probe_disk();

    return [
        't'      => \microtime(true),
        'cpu'    => probe_cpu_sample(),
        'net'    => probe_net_sample(),
        'mem'    => ['total' => $memTotal, 'used' => \max(0, $memTotal - $memAvail)],
        'swap'   => ['total' => $swapTotal, 'used' => \max(0, $swapTotal - $swapFree)],
        'disk'   => ['total' => $disk['total'], 'used' => \max(0.0, $disk['total'] - $disk['free'])],
        'load'   => probe_load(),
        'uptime' => probe_uptime(),
        'phpmem' => \memory_get_usage(true),
    ];
}

/**
 * Diagnostics for ?action=stats&debug=1 — explains *why* a metric is empty
 * (open_basedir, disabled exec functions, hardened /proc, …).
 */
function probe_diagnostics()
{
    $paths = ['/proc/stat', '/proc/meminfo', '/proc/net/dev', '/proc/uptime', '/proc/loadavg'];
    $files = [];
    foreach ($paths as $p) {
        $direct = @\file_get_contents($p);
        $shell = probe_shell('cat ' . \escapeshellarg($p) . ' 2>/dev/null');
        $files[$p] = [
            'direct_read' => ($direct !== false && $direct !== ''),
            'shell_read'  => ($shell !== null && $shell !== ''),
        ];
    }
    return [
        'open_basedir'      => \ini_get('open_basedir') ?: '(none)',
        'disable_functions' => \ini_get('disable_functions') ?: '(none)',
        'exec_fn'           => probe_exec_fn() ?: '(none available)',
        'disk_func'         => \function_exists('disk_total_space') && (float) @\disk_total_space('/') > 0,
        'loadavg_func'      => \function_exists('sys_getloadavg'),
        'files'             => $files,
    ];
}

// ---------------------------------------------------------------------------
// Action endpoints
// ---------------------------------------------------------------------------

$action = isset($_GET['action']) ? (string) $_GET['action'] : '';

if ($action === 'stats') {
    \header('Content-Type: application/json; charset=utf-8');
    \header('Cache-Control: no-store, max-age=0');
    $payload = probe_dynamic_stats();
    if (isset($_GET['debug'])) {
        $payload['_diag'] = probe_diagnostics();
    }
    echo \json_encode($payload);
    exit;
}

if ($action === 'phpinfo') {
    \phpinfo();
    exit;
}

// ---------------------------------------------------------------------------
// Static facts for the initial page render
// ---------------------------------------------------------------------------

$cpu = probe_cpu_info();
$hostname = \gethostname() ?: \php_uname('n');
$osName = \php_uname('s') . ' ' . \php_uname('r');
$arch = \php_uname('m');

$serverSoftware = $_SERVER['SERVER_SOFTWARE'] ?? 'N/A';
$serverAddr = $_SERVER['SERVER_ADDR'] ?? 'N/A';
$serverPort = $_SERVER['SERVER_PORT'] ?? '';
$serverName = $_SERVER['SERVER_NAME'] ?? ($_SERVER['HTTP_HOST'] ?? 'N/A');
$docRoot = $_SERVER['DOCUMENT_ROOT'] ?? 'N/A';

$phpVersion = \PHP_VERSION;
$phpSapi = \PHP_SAPI;
$serverTime = \date('Y-m-d H:i:s');
$tz = \date_default_timezone_get();

// Extensions relevant to an LNMP stack. Order is display order.
$extList = [
    'Zend OPcache', 'curl', 'gd', 'mbstring', 'mysqli', 'pdo_mysql',
    'redis', 'memcached', 'openssl', 'zip', 'bcmath', 'imagick',
    'sodium', 'exif', 'fileinfo', 'intl', 'igbinary', 'swoole',
];
$extStatus = [];
foreach ($extList as $ext) {
    $extStatus[$ext] = \extension_loaded($ext);
}

$e = static function ($s) {
    return \htmlspecialchars((string) $s, \ENT_QUOTES, 'UTF-8');
};
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>GetLNMP Server Probe</title>
  <meta name="author" content="GetLNMP">
  <meta name="description" content="GetLNMP server probe — live LNMP server stats.">
  <style>
    :root {
      color-scheme: light;
      --bg: #f5f7f8;
      --panel: #ffffff;
      --text: #16202c;
      --muted: #66728199;
      --muted-solid: #667281;
      --line: #e6eaef;
      --brand: #126b5d;
      --brand-dark: #0c4f45;
      --brand-soft: #e7f2ef;
      --ok: #1f9d6b;
      --warn: #d98a1f;
      --crit: #d65745;
      --shadow: 0 1px 2px rgba(16, 24, 40, 0.04), 0 12px 32px rgba(16, 24, 40, 0.06);
      --radius: 14px;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      min-height: 100vh;
      padding: 32px 16px;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC",
        "Hiragino Sans GB", "Microsoft YaHei", Arial, sans-serif;
      line-height: 1.6;
      -webkit-font-smoothing: antialiased;
    }

    a { color: var(--brand); text-decoration: none; }
    a:hover { color: var(--brand-dark); }

    .dashboard {
      width: min(1040px, 100%);
      margin: 0 auto;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    /* Header panel */
    .topbar {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 16px 20px;
      padding: 22px 24px;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
    }

    .brand {
      display: inline-flex;
      align-items: center;
      gap: 12px;
      font-weight: 700;
      letter-spacing: 0.01em;
    }

    .brand-icon {
      display: grid;
      width: 40px;
      height: 40px;
      place-items: center;
      border-radius: 11px;
      background: linear-gradient(160deg, var(--brand), var(--brand-dark));
      color: #fff;
      font-size: 20px;
      font-weight: 800;
      box-shadow: 0 6px 14px rgba(18, 107, 93, 0.28);
    }

    .brand-name { font-size: 17px; }
    .brand-sub { display: block; font-size: 12px; font-weight: 500; color: var(--muted-solid); letter-spacing: 0.04em; text-transform: uppercase; }

    .topbar-meta {
      margin-left: auto;
      display: inline-flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 10px 16px;
    }

    .uptime-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 13px;
      color: var(--muted-solid);
    }
    .uptime-pill b { color: var(--text); font-weight: 600; }

    .status {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 7px 14px;
      border-radius: 999px;
      background: var(--brand-soft);
      color: var(--brand-dark);
      font-size: 13px;
      font-weight: 600;
    }

    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--ok);
      box-shadow: 0 0 0 0 rgba(31, 157, 107, 0.5);
      animation: pulse 2s infinite;
    }
    .dot.paused { background: var(--muted-solid); animation: none; }

    @keyframes pulse {
      0% { box-shadow: 0 0 0 0 rgba(31, 157, 107, 0.45); }
      70% { box-shadow: 0 0 0 7px rgba(31, 157, 107, 0); }
      100% { box-shadow: 0 0 0 0 rgba(31, 157, 107, 0); }
    }

    /* Generic panel + section heading */
    .panel {
      padding: 20px 22px;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
    }

    .section-title {
      display: flex;
      align-items: center;
      gap: 10px;
      margin: 4px 2px -2px;
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      color: var(--muted-solid);
    }

    /* Metric gauge grid */
    .gauges {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 16px;
    }

    .gauge .gauge-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 8px;
    }
    .gauge .tag {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 8px;
      background: var(--brand-soft);
      color: var(--brand-dark);
      font-size: 12px;
      font-weight: 600;
    }
    .gauge .pct { font-size: 22px; font-weight: 700; font-variant-numeric: tabular-nums; }
    .gauge .bar {
      margin: 14px 0 10px;
      height: 8px;
      border-radius: 999px;
      background: var(--line);
      overflow: hidden;
    }
    .gauge .bar > span {
      display: block;
      height: 100%;
      width: 0%;
      border-radius: 999px;
      background: var(--ok);
      transition: width .5s ease, background .3s ease;
    }
    .gauge .sub { font-size: 13px; color: var(--muted-solid); font-variant-numeric: tabular-nums; }

    /* Two-column info row */
    .cols {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
    }

    .kv { display: grid; gap: 0; }
    .kv .row {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      padding: 9px 0;
      border-bottom: 1px dashed var(--line);
      font-size: 14px;
    }
    .kv .row:last-child { border-bottom: 0; }
    .kv .k { color: var(--muted-solid); white-space: nowrap; }
    .kv .v { font-weight: 600; text-align: right; word-break: break-word; font-variant-numeric: tabular-nums; }

    .panel h2 {
      margin: 0 0 14px;
      font-size: 16px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    /* Network panel */
    .net-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
    .net-stat .net-label { font-size: 13px; color: var(--muted-solid); display: flex; align-items: center; gap: 7px; }
    .net-stat .net-rate { font-size: 20px; font-weight: 700; font-variant-numeric: tabular-nums; }
    .net-stat .net-total { font-size: 12.5px; color: var(--muted-solid); font-variant-numeric: tabular-nums; }
    .spark { display: block; width: 100%; height: 48px; margin-top: 8px; }
    .arrow { font-size: 12px; }
    .arrow.down { color: var(--ok); }
    .arrow.up { color: var(--brand); }

    /* Extension chips */
    .chips { display: flex; flex-wrap: wrap; gap: 8px; }
    .chips .chip {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      min-height: 30px;
      padding: 0 11px;
      border: 1px solid var(--line);
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
    }
    .chip .chip-dot { width: 7px; height: 7px; border-radius: 50%; }
    .chip.on { color: var(--brand-dark); border-color: var(--brand-soft); background: var(--brand-soft); }
    .chip.on .chip-dot { background: var(--ok); }
    .chip.off { color: var(--muted-solid); }
    .chip.off .chip-dot { background: #c4ccd6; }

    /* Buttons / actions */
    .actions { display: flex; flex-wrap: wrap; gap: 10px; }
    .button {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-height: 38px;
      padding: 0 16px;
      border: 1px solid var(--brand);
      border-radius: 10px;
      background: var(--brand);
      color: #fff;
      font-weight: 600;
      font-size: 14px;
      cursor: pointer;
      transition: transform .08s ease, background .15s ease;
    }
    .button:hover { background: var(--brand-dark); color: #fff; }
    .button:active { transform: translateY(1px); }
    .button.secondary { background: #fff; color: var(--brand-dark); border-color: var(--line); }
    .button.secondary:hover { background: var(--brand-soft); border-color: var(--brand); }

    .notice {
      padding: 14px 18px;
      border: 1px solid var(--line);
      border-left: 3px solid var(--brand);
      border-radius: 10px;
      background: #fbfdfc;
      color: var(--muted-solid);
      font-size: 13px;
    }
    .footer { color: var(--muted-solid); font-size: 13px; text-align: center; padding: 4px 0 0; }

    @media (max-width: 880px) {
      .gauges { grid-template-columns: repeat(2, 1fr); }
      .cols { grid-template-columns: 1fr; }
    }
    @media (max-width: 520px) {
      .gauges { grid-template-columns: 1fr; }
      .net-grid { grid-template-columns: 1fr; }
      .topbar-meta { margin-left: 0; }
    }
  </style>
</head>
<body>
  <main class="dashboard">
    <header class="topbar">
      <span class="brand">
        <span class="brand-icon">G</span>
        <span>
          <span class="brand-name">GetLNMP</span>
          <span class="brand-sub">Server Probe</span>
        </span>
      </span>
      <span class="topbar-meta">
        <span class="uptime-pill">Uptime <b id="uptime">—</b></span>
        <span class="status" id="status"><span class="dot" id="statusDot"></span> <span id="statusText">Live</span></span>
      </span>
    </header>

    <!-- Live metric gauges -->
    <section class="gauges" aria-label="Live resource usage">
      <article class="panel gauge">
        <div class="gauge-head"><span class="tag">CPU</span><span class="pct" id="cpuPct">—</span></div>
        <div class="bar"><span id="cpuBar"></span></div>
        <div class="sub" id="cpuSub"><?= $e($cpu['cores']) ?> core<?= $cpu['cores'] > 1 ? 's' : '' ?> · load —</div>
      </article>
      <article class="panel gauge">
        <div class="gauge-head"><span class="tag">Memory</span><span class="pct" id="memPct">—</span></div>
        <div class="bar"><span id="memBar"></span></div>
        <div class="sub" id="memSub">—</div>
      </article>
      <article class="panel gauge">
        <div class="gauge-head"><span class="tag">Swap</span><span class="pct" id="swapPct">—</span></div>
        <div class="bar"><span id="swapBar"></span></div>
        <div class="sub" id="swapSub">—</div>
      </article>
      <article class="panel gauge">
        <div class="gauge-head"><span class="tag">Disk /</span><span class="pct" id="diskPct">—</span></div>
        <div class="bar"><span id="diskBar"></span></div>
        <div class="sub" id="diskSub">—</div>
      </article>
    </section>

    <!-- CPU history + Network -->
    <section class="cols">
      <article class="panel">
        <h2>CPU Usage</h2>
        <canvas class="spark" id="cpuSpark" height="120"></canvas>
        <div class="sub" style="font-size:13px;color:var(--muted-solid);margin-top:6px;">
          Live utilization over the last ~2 minutes.
        </div>
      </article>
      <article class="panel">
        <h2>Network</h2>
        <div class="net-grid">
          <div class="net-stat">
            <div class="net-label"><span class="arrow down">▼</span> Inbound</div>
            <div class="net-rate" id="rxRate">—</div>
            <div class="net-total">Total <span id="rxTotal">—</span></div>
            <canvas class="spark" id="rxSpark" height="96"></canvas>
          </div>
          <div class="net-stat">
            <div class="net-label"><span class="arrow up">▲</span> Outbound</div>
            <div class="net-rate" id="txRate">—</div>
            <div class="net-total">Total <span id="txTotal">—</span></div>
            <canvas class="spark" id="txSpark" height="96"></canvas>
          </div>
        </div>
      </article>
    </section>

    <!-- System + PHP environment -->
    <section class="cols">
      <article class="panel">
        <h2>System</h2>
        <div class="kv">
          <div class="row"><span class="k">Hostname</span><span class="v"><?= $e($hostname) ?></span></div>
          <div class="row"><span class="k">Operating System</span><span class="v"><?= $e($osName) ?></span></div>
          <div class="row"><span class="k">Architecture</span><span class="v"><?= $e($arch) ?></span></div>
          <div class="row"><span class="k">CPU Model</span><span class="v"><?= $e($cpu['model']) ?></span></div>
          <div class="row"><span class="k">CPU Cores</span><span class="v"><?= $e($cpu['cores']) ?></span></div>
          <div class="row"><span class="k">Load Average</span><span class="v" id="loadAvg">—</span></div>
          <div class="row"><span class="k">Server Time</span><span class="v"><?= $e($serverTime) ?> (<?= $e($tz) ?>)</span></div>
        </div>
      </article>
      <article class="panel">
        <h2>PHP &amp; Web</h2>
        <div class="kv">
          <div class="row"><span class="k">PHP Version</span><span class="v"><?= $e($phpVersion) ?></span></div>
          <div class="row"><span class="k">PHP SAPI</span><span class="v"><?= $e($phpSapi) ?></span></div>
          <div class="row"><span class="k">PHP Memory</span><span class="v" id="phpMem">—</span></div>
          <div class="row"><span class="k">Web Server</span><span class="v"><?= $e($serverSoftware) ?></span></div>
          <div class="row"><span class="k">Server Address</span><span class="v"><?= $e($serverAddr) ?><?= $serverPort ? ':' . $e($serverPort) : '' ?></span></div>
          <div class="row"><span class="k">Server Name</span><span class="v"><?= $e($serverName) ?></span></div>
          <div class="row"><span class="k">Document Root</span><span class="v"><?= $e($docRoot) ?></span></div>
        </div>
      </article>
    </section>

    <!-- Extensions -->
    <article class="panel">
      <h2>PHP Extensions</h2>
      <div class="chips">
        <?php foreach ($extStatus as $name => $loaded): ?>
          <span class="chip <?= $loaded ? 'on' : 'off' ?>"><span class="chip-dot"></span><?= $e($name === 'Zend OPcache' ? 'OPcache' : $name) ?></span>
        <?php endforeach; ?>
      </div>
    </article>

    <!-- Tools -->
    <article class="panel">
      <h2>Tools</h2>
      <div class="actions">
        <a class="button" href="?action=phpinfo" target="_blank" rel="noopener">phpinfo</a>
        <button class="button secondary" type="button" id="toggleBtn">Pause updates</button>
      </div>
    </article>

    <p class="notice">
      This probe reports basic stats for a GetLNMP-managed environment. Remove or
      restrict public diagnostic files like this one before going to production.
    </p>

    <footer class="footer">Powered by GetLNMP</footer>
  </main>

  <script>
  (function () {
    "use strict";

    var POLL_MS = 2000;
    var MAX_POINTS = 60;
    var paused = false;
    var prev = null; // previous {t, cpu:{total,idle}, net:{rx,tx}}
    var history = { cpu: [], rx: [], tx: [] };

    var $ = function (id) { return document.getElementById(id); };

    function fmtBytes(b) {
      if (b === null || b === undefined || isNaN(b)) return '—';
      var u = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
      var i = 0;
      b = Number(b);
      while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
      return (i === 0 ? b : b.toFixed(b < 10 ? 2 : 1)) + ' ' + u[i];
    }

    function fmtRate(bps) {
      if (bps === null || bps === undefined || isNaN(bps)) return '—';
      return fmtBytes(bps) + '/s';
    }

    function fmtUptime(sec) {
      if (sec === null || sec === undefined || isNaN(sec)) return '—';
      sec = Math.floor(sec);
      var d = Math.floor(sec / 86400); sec -= d * 86400;
      var h = Math.floor(sec / 3600); sec -= h * 3600;
      var m = Math.floor(sec / 60);
      var out = [];
      if (d) out.push(d + 'd');
      if (h || d) out.push(h + 'h');
      out.push(m + 'm');
      return out.join(' ');
    }

    function colorFor(pct) {
      if (pct >= 90) return getCss('--crit');
      if (pct >= 75) return getCss('--warn');
      return getCss('--ok');
    }
    function getCss(name) {
      return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
    }

    function setGauge(prefix, used, total) {
      var pct = total > 0 ? (used / total) * 100 : 0;
      var bar = $(prefix + 'Bar');
      $(prefix + 'Pct').textContent = (total > 0 ? pct.toFixed(1) : '0') + '%';
      bar.style.width = Math.min(100, pct) + '%';
      bar.style.background = colorFor(pct);
      $(prefix + 'Sub').textContent = fmtBytes(used) + ' / ' + fmtBytes(total);
    }

    function pushHistory(arr, v) {
      arr.push(v);
      if (arr.length > MAX_POINTS) arr.shift();
    }

    function drawSpark(canvas, data, color, opts) {
      opts = opts || {};
      var ratio = window.devicePixelRatio || 1;
      var w = canvas.clientWidth || canvas.parentNode.clientWidth;
      var h = canvas.clientHeight || parseInt(canvas.getAttribute('height'), 10) || 48;
      if (canvas.width !== w * ratio || canvas.height !== h * ratio) {
        canvas.width = w * ratio;
        canvas.height = h * ratio;
      }
      var ctx = canvas.getContext('2d');
      ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      ctx.clearRect(0, 0, w, h);
      if (data.length < 2) return;

      var max = opts.max;
      if (max === undefined) {
        max = 1;
        for (var i = 0; i < data.length; i++) { if (data[i] > max) max = data[i]; }
        max *= 1.15;
      }
      var pad = 3;
      var stepX = (w) / (MAX_POINTS - 1);
      var y = function (v) { return h - pad - (v / max) * (h - pad * 2); };
      var startIdx = MAX_POINTS - data.length;

      // area fill
      ctx.beginPath();
      ctx.moveTo(startIdx * stepX, h);
      for (var j = 0; j < data.length; j++) {
        ctx.lineTo((startIdx + j) * stepX, y(data[j]));
      }
      ctx.lineTo((startIdx + data.length - 1) * stepX, h);
      ctx.closePath();
      ctx.fillStyle = hexToRgba(color, 0.12);
      ctx.fill();

      // line
      ctx.beginPath();
      for (var k = 0; k < data.length; k++) {
        var px = (startIdx + k) * stepX;
        var py = y(data[k]);
        if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
      }
      ctx.lineWidth = 2;
      ctx.strokeStyle = color;
      ctx.lineJoin = 'round';
      ctx.stroke();
    }

    function hexToRgba(hex, a) {
      hex = hex.replace('#', '');
      if (hex.length === 3) hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
      var n = parseInt(hex, 16);
      return 'rgba(' + ((n >> 16) & 255) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + a + ')';
    }

    function redrawSparks() {
      drawSpark($('cpuSpark'), history.cpu, getCss('--brand'), { max: 100 });
      drawSpark($('rxSpark'), history.rx, getCss('--ok'));
      drawSpark($('txSpark'), history.tx, getCss('--brand'));
    }

    function apply(d) {
      // Uptime
      $('uptime').textContent = fmtUptime(d.uptime);

      // Memory / swap / disk
      setGauge('mem', d.mem.used, d.mem.total);
      setGauge('swap', d.swap.used, d.swap.total);
      setGauge('disk', d.disk.used, d.disk.total);
      if (d.swap.total === 0) {
        $('swapPct').textContent = 'n/a';
        $('swapSub').textContent = 'no swap';
      }

      // Load average
      if (d.load && d.load[0] !== null) {
        var l = d.load.map(function (x) { return Number(x).toFixed(2); }).join('  ');
        $('loadAvg').textContent = l;
      }

      // PHP memory
      $('phpMem').textContent = fmtBytes(d.phpmem);

      // CPU + network deltas
      if (prev && d.cpu && prev.cpu) {
        var dt = d.t - prev.t;
        var totalD = d.cpu.total - prev.cpu.total;
        var idleD = d.cpu.idle - prev.cpu.idle;
        var cpuPct = totalD > 0 ? Math.max(0, Math.min(100, (1 - idleD / totalD) * 100)) : 0;
        $('cpuPct').textContent = cpuPct.toFixed(1) + '%';
        var cpuBar = $('cpuBar');
        cpuBar.style.width = cpuPct + '%';
        cpuBar.style.background = colorFor(cpuPct);
        var loadTxt = (d.load && d.load[0] !== null) ? Number(d.load[0]).toFixed(2) : '—';
        $('cpuSub').innerHTML = $('cpuSub').dataset.cores + ' · load ' + loadTxt;
        pushHistory(history.cpu, cpuPct);

        if (prev.net && d.net && dt > 0) {
          var rx = Math.max(0, (d.net.rx - prev.net.rx) / dt);
          var tx = Math.max(0, (d.net.tx - prev.net.tx) / dt);
          $('rxRate').textContent = fmtRate(rx);
          $('txRate').textContent = fmtRate(tx);
          pushHistory(history.rx, rx);
          pushHistory(history.tx, tx);
        }
      }
      if (d.net) {
        $('rxTotal').textContent = fmtBytes(d.net.rx);
        $('txTotal').textContent = fmtBytes(d.net.tx);
      }

      redrawSparks();
      prev = d;
    }

    function poll() {
      if (paused) return;
      fetch('?action=stats', { cache: 'no-store' })
        .then(function (r) { return r.json(); })
        .then(apply)
        .catch(function () { /* transient; keep last values */ });
    }

    // Preserve the static "N cores" prefix for the CPU sub line.
    var cpuSubEl = $('cpuSub');
    cpuSubEl.dataset.cores = cpuSubEl.textContent.split('·')[0].trim();

    $('toggleBtn').addEventListener('click', function () {
      paused = !paused;
      this.textContent = paused ? 'Resume updates' : 'Pause updates';
      $('statusDot').classList.toggle('paused', paused);
      $('statusText').textContent = paused ? 'Paused' : 'Live';
      if (!paused) poll();
    });

    window.addEventListener('resize', redrawSparks);

    poll();
    setInterval(poll, POLL_MS);
  })();
  </script>
</body>
</html>
