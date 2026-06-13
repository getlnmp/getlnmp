<?php
    header("Content-Type:text/html;charset=utf-8");

    // Run the Memcache checks first, collecting results so we can render them
    // inside the GetLNMP dashboard UI afterwards.
    $checks = array();

    if (!class_exists('Memcache')) {
        $checks[] = array(
            'tag'    => 'Extension',
            'title'  => 'PHP Memcache extension',
            'ok'     => false,
            'detail' => 'The PHP Memcache extension was not installed.',
        );
    } else {
        $checks[] = array(
            'tag'    => 'Extension',
            'title'  => 'PHP Memcache extension',
            'ok'     => true,
            'detail' => 'The PHP Memcache extension is loaded.',
        );

        $mem = new Memcache;
        if (!@$mem->connect("127.0.0.1", 11211)) {
            $checks[] = array(
                'tag'    => 'Connection',
                'title'  => 'Connect to 127.0.0.1:11211',
                'ok'     => false,
                'detail' => 'Could not connect to the Memcached server.',
            );
        } else {
            $version = $mem->getVersion();
            $checks[] = array(
                'tag'    => 'Connection',
                'title'  => 'Connect to 127.0.0.1:11211',
                'ok'     => true,
                'detail' => 'Connected. Memcached server version: ' . htmlspecialchars($version) . '.',
            );

            // Write data
            $mem->set('key1', 'This is first value', 0, 60);
            $val = $mem->get('key1');
            $checks[] = array(
                'tag'    => 'Write',
                'title'  => 'SET key1',
                'ok'     => ($val === 'This is first value'),
                'detail' => 'Stored value: ' . htmlspecialchars($val) . '.',
            );

            // Replace data
            $mem->replace('key1', 'This is replace value', 0, 60);
            $val = $mem->get('key1');
            $checks[] = array(
                'tag'    => 'Replace',
                'title'  => 'REPLACE key1',
                'ok'     => ($val === 'This is replace value'),
                'detail' => 'Replaced value: ' . htmlspecialchars($val) . '.',
            );

            // Store an array
            $arr = array('aaa', 'bbb', 'ccc', 'ddd');
            $mem->set('key2', $arr, 0, 60);
            $val2 = $mem->get('key2');
            $checks[] = array(
                'tag'    => 'Array',
                'title'  => 'SET key2 (array)',
                'ok'     => ($val2 === $arr),
                'detail' => 'Stored array: ' . htmlspecialchars(print_r($val2, true)) . '.',
            );

            // Delete data
            $mem->delete('key1');
            $val = $mem->get('key1');
            $checks[] = array(
                'tag'    => 'Delete',
                'title'  => 'DELETE key1',
                'ok'     => ($val === false),
                'detail' => ($val === false)
                    ? 'Key removed. Reading key1 now returns an empty result.'
                    : 'Key still present after delete: ' . htmlspecialchars($val) . '.',
            );

            // Flush all data
            $mem->flush();
            $val2 = $mem->get('key2');
            $checks[] = array(
                'tag'    => 'Flush',
                'title'  => 'FLUSH all keys',
                'ok'     => ($val2 === false),
                'detail' => ($val2 === false)
                    ? 'All keys flushed. Reading key2 now returns an empty result.'
                    : 'Key2 still present after flush.',
            );

            $mem->close();
        }
    }

    // Overall result drives the header status pill.
    $allOk = !empty($checks);
    foreach ($checks as $check) {
        if (!$check['ok']) {
            $allOk = false;
            break;
        }
    }
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>GetLNMP Memcache Test</title>
  <meta name="author" content="GetLNMP">
  <meta name="keywords" content="GetLNMP,LNMP,LNMPA,LAMP,Nginx,MySQL,MariaDB,PHP,Memcache">
  <meta name="description" content="GetLNMP Memcache connection test tool.">
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
      --ok-soft: #e7f5ef;
      --err: #d14343;
      --err-soft: #fdecec;
      --shadow: 0 1px 2px rgba(16, 24, 40, 0.04), 0 12px 32px rgba(16, 24, 40, 0.06);
      --radius: 14px;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
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
      width: min(960px, 100%);
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

    .status {
      margin-left: auto;
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

    .status.fail { background: var(--err-soft); color: var(--err); }

    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--ok);
      box-shadow: 0 0 0 0 rgba(31, 157, 107, 0.5);
      animation: pulse 2s infinite;
    }

    .status.fail .dot {
      background: var(--err);
      animation: none;
    }

    @keyframes pulse {
      0% { box-shadow: 0 0 0 0 rgba(31, 157, 107, 0.45); }
      70% { box-shadow: 0 0 0 7px rgba(31, 157, 107, 0); }
      100% { box-shadow: 0 0 0 0 rgba(31, 157, 107, 0); }
    }

    /* Hero panel */
    .hero {
      padding: 30px 24px;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
    }

    .hero h1 {
      margin: 0;
      font-size: clamp(24px, 3.4vw, 34px);
      line-height: 1.15;
      letter-spacing: -0.01em;
    }

    .hero p {
      margin: 12px 0 0;
      max-width: 640px;
      color: var(--muted-solid);
      font-size: 15.5px;
    }

    /* Cards grid */
    .grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 16px;
    }

    .card {
      padding: 20px;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
    }

    .card .tag {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      margin-bottom: 12px;
      padding: 4px 10px;
      border-radius: 8px;
      background: var(--ok-soft);
      color: var(--ok);
      font-size: 12px;
      font-weight: 600;
    }

    .card .tag.fail { background: var(--err-soft); color: var(--err); }

    .card .tag .mark { font-size: 13px; line-height: 1; }

    .card h2 { margin: 0 0 6px; font-size: 16px; }
    .card p { margin: 0; color: var(--muted-solid); font-size: 14px; word-break: break-word; }

    .footer { color: var(--muted-solid); font-size: 13px; text-align: center; padding: 4px 0 0; }

    @media (max-width: 720px) {
      .grid { grid-template-columns: 1fr; }
      .status { margin-left: 0; }
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
          <span class="brand-sub">Memcache Test</span>
        </span>
      </span>
      <span class="status<?php echo $allOk ? '' : ' fail'; ?>">
        <span class="dot"></span> <?php echo $allOk ? 'Connected' : 'Failed'; ?>
      </span>
    </header>

    <section class="hero" aria-labelledby="memcache-title">
      <h1 id="memcache-title">Memcache connection test</h1>
      <p>
        <?php if ($allOk): ?>
          The PHP Memcache extension is installed and the Memcached server at
          127.0.0.1:11211 responded correctly to write, replace, read, delete, and flush operations.
        <?php else: ?>
          One or more checks failed. Review the results below to diagnose the
          Memcache extension or server connection.
        <?php endif; ?>
      </p>
    </section>

    <section class="grid" aria-label="Memcache test results">
      <?php foreach ($checks as $check): ?>
      <article class="card">
        <span class="tag<?php echo $check['ok'] ? '' : ' fail'; ?>">
          <span class="mark"><?php echo $check['ok'] ? '&#10003;' : '&#10007;'; ?></span>
          <?php echo htmlspecialchars($check['tag']); ?>
        </span>
        <h2><?php echo htmlspecialchars($check['title']); ?></h2>
        <p><?php echo $check['detail']; ?></p>
      </article>
      <?php endforeach; ?>
    </section>

    <p class="footer">
      Memcached Test tool for
      <a href="https://getlnmp.com" target="_blank">GetLNMP</a>
    </p>
  </main>
</body>
</html>
