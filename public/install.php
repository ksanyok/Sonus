<?php
/**
 * Call Audit Proto - Web Installer
 * Simple one-page installer for production deployment
 */

// Check if already installed
$envFile = __DIR__ . '/../.env';
$dbFile = __DIR__ . '/../storage/app.sqlite';

if (file_exists($envFile) && file_exists($dbFile) && !isset($_GET['reinstall'])) {
    header('Location: /');
    exit;
}

$step = $_GET['step'] ?? 1;
$errors = [];
$warnings = [];

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if ($step == 1) {
        // Step 1: Validate requirements
        $checks = checkRequirements();
        if ($checks['can_proceed']) {
            header('Location: install.php?step=2');
            exit;
        }
    } elseif ($step == 2) {
        // Step 2: Configure and install
        $apiKey = trim($_POST['openai_api_key'] ?? '');
        $appUrl = trim($_POST['app_url'] ?? '');
        
        if (empty($apiKey)) {
            $errors[] = 'OpenAI API ключ обязателен';
        } else {
            // Create .env file
            $envContent = generateEnvContent($apiKey, $appUrl);
            if (file_put_contents($envFile, $envContent)) {
                // Create storage directories
                $dirs = [
                    __DIR__ . '/../storage',
                    __DIR__ . '/../storage/uploads',
                    __DIR__ . '/../storage/uploads/audio',
                    __DIR__ . '/../storage/uploads/rubrics',
                    __DIR__ . '/../storage/reports',
                    __DIR__ . '/../storage/embeddings',
                ];
                
                foreach ($dirs as $dir) {
                    if (!is_dir($dir)) {
                        mkdir($dir, 0755, true);
                    }
                    chmod($dir, 0755);
                }
                
                // Run migrations
                require __DIR__ . '/../vendor/autoload.php';
                
                try {
                    // Run migration
                    $output = runMigrations();
                    
                    // Success!
                    header('Location: install.php?step=3');
                    exit;
                } catch (Exception $e) {
                    $errors[] = 'Ошибка миграции БД: ' . $e->getMessage();
                }
            } else {
                $errors[] = 'Не удалось создать .env файл. Проверьте права на запись.';
            }
        }
    }
}

function checkRequirements(): array {
    $checks = [
        'php_version' => version_compare(PHP_VERSION, '8.1.0', '>='),
        'pdo' => extension_loaded('pdo'),
        'pdo_sqlite' => extension_loaded('pdo_sqlite'),
        'curl' => extension_loaded('curl'),
        'mbstring' => extension_loaded('mbstring'),
        'json' => extension_loaded('json'),
        'writable_root' => is_writable(__DIR__ . '/..'),
        'writable_storage' => is_writable(__DIR__ . '/../storage') || is_writable(__DIR__ . '/..'),
        'composer' => file_exists(__DIR__ . '/../vendor/autoload.php'),
    ];
    
    $checks['can_proceed'] = !in_array(false, $checks, true);
    
    return $checks;
}

function generateEnvContent(string $apiKey, string $appUrl): string {
    $rootDir = realpath(__DIR__ . '/..');
    $dbPath = $rootDir . '/storage/app.sqlite';
    
    return <<<ENV
# Application
APP_ENV=production
APP_URL={$appUrl}
APP_DEBUG=false
TZ=Europe/Kyiv

# Database (absolute path!)
DB_PATH={$dbPath}

# OpenAI
OPENAI_API_KEY={$apiKey}
OPENAI_ORG_ID=

# Uploads
MAX_UPLOAD_SIZE_MB=50
STORAGE_PATH=storage

# FFmpeg (leave empty to auto-detect)
FFMPEG_PATH=

# Webhooks
WEBHOOK_ENABLED=true
WEBHOOK_RETRY_ATTEMPTS=3
WEBHOOK_RETRY_BACKOFF_SEC=5

# Session
SESSION_SECRET=
ENV;
}

function runMigrations(): string {
    $rootDir = __DIR__ . '/..';
    $dbPath = $rootDir . '/storage/app.sqlite';
    
    // Create database
    $pdo = new PDO('sqlite:' . $dbPath);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Run migration SQL
    $sql = <<<SQL
CREATE TABLE IF NOT EXISTS jobs (
    id TEXT PRIMARY KEY,
    status TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    audio_path TEXT NOT NULL,
    rubric_path TEXT,
    lang TEXT DEFAULT 'auto',
    webhook_url TEXT
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at);

CREATE TABLE IF NOT EXISTS reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id TEXT UNIQUE NOT NULL,
    json TEXT NOT NULL,
    final_score REAL,
    mandatory_avg REAL,
    general_avg REAL,
    ethics_flag INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    FOREIGN KEY(job_id) REFERENCES jobs(id)
);

CREATE INDEX IF NOT EXISTS idx_reports_job_id ON reports(job_id);

CREATE TABLE IF NOT EXISTS rubrics (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    schema_json TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS embeddings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    text TEXT NOT NULL,
    vector BLOB NOT NULL,
    meta_json TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS triggers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id TEXT NOT NULL,
    t_start REAL NOT NULL,
    t_end REAL,
    type TEXT NOT NULL,
    term TEXT,
    speaker TEXT,
    extra_json TEXT,
    FOREIGN KEY(job_id) REFERENCES jobs(id)
);

CREATE INDEX IF NOT EXISTS idx_triggers_job_id ON triggers(job_id);
CREATE INDEX IF NOT EXISTS idx_triggers_type ON triggers(type);
SQL;
    
    $pdo->exec($sql);
    
    return "Database created successfully";
}

$requirements = checkRequirements();
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Установка Call Audit Proto</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100">
    <div class="min-h-screen flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-2xl w-full space-y-8">
            <!-- Header -->
            <div class="text-center">
                <h1 class="text-4xl font-bold text-gray-900 mb-2">📊 Call Audit Proto</h1>
                <p class="text-gray-600">Установка системы анализа звонков</p>
            </div>

            <?php if ($step == 1): ?>
            <!-- Step 1: Requirements Check -->
            <div class="bg-white rounded-lg shadow-lg p-8">
                <h2 class="text-2xl font-bold text-gray-900 mb-6">Шаг 1: Проверка требований</h2>
                
                <div class="space-y-3 mb-6">
                    <?php foreach ([
                        'php_version' => ['PHP >= 8.1', 'PHP версия ' . PHP_VERSION],
                        'pdo' => ['PDO расширение', 'Для работы с БД'],
                        'pdo_sqlite' => ['PDO SQLite драйвер', 'SQLite база данных'],
                        'curl' => ['cURL расширение', 'Для API запросов'],
                        'mbstring' => ['Mbstring расширение', 'Работа с UTF-8'],
                        'json' => ['JSON расширение', 'Обработка JSON'],
                        'composer' => ['Composer зависимости', 'vendor/autoload.php'],
                        'writable_root' => ['Права на запись (root)', 'Для создания .env'],
                        'writable_storage' => ['Права на запись (storage)', 'Для загрузок и БД'],
                    ] as $key => $labels): ?>
                        <div class="flex items-center justify-between p-3 rounded <?= $requirements[$key] ? 'bg-green-50' : 'bg-red-50' ?>">
                            <div>
                                <div class="font-medium <?= $requirements[$key] ? 'text-green-900' : 'text-red-900' ?>">
                                    <?= $labels[0] ?>
                                </div>
                                <div class="text-sm <?= $requirements[$key] ? 'text-green-600' : 'text-red-600' ?>">
                                    <?= $labels[1] ?>
                                </div>
                            </div>
                            <div class="text-2xl">
                                <?= $requirements[$key] ? '✅' : '❌' ?>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>

                <?php if (!$requirements['can_proceed']): ?>
                    <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
                        <strong>Ошибка!</strong> Не все требования выполнены. Установка невозможна.
                        <ul class="list-disc list-inside mt-2">
                            <?php if (!$requirements['composer']): ?>
                                <li>Запустите <code class="bg-red-200 px-1 rounded">composer install</code> в корневой директории</li>
                            <?php endif; ?>
                            <?php if (!$requirements['writable_root'] || !$requirements['writable_storage']): ?>
                                <li>Установите права: <code class="bg-red-200 px-1 rounded">chmod -R 755 .</code></li>
                            <?php endif; ?>
                        </ul>
                    </div>
                <?php endif; ?>

                <form method="POST">
                    <button 
                        type="submit" 
                        <?= !$requirements['can_proceed'] ? 'disabled' : '' ?>
                        class="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white <?= $requirements['can_proceed'] ? 'bg-blue-600 hover:bg-blue-700' : 'bg-gray-400 cursor-not-allowed' ?> focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                    >
                        Продолжить →
                    </button>
                </form>
            </div>

            <?php elseif ($step == 2): ?>
            <!-- Step 2: Configuration -->
            <div class="bg-white rounded-lg shadow-lg p-8">
                <h2 class="text-2xl font-bold text-gray-900 mb-6">Шаг 2: Конфигурация</h2>
                
                <?php if (!empty($errors)): ?>
                    <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
                        <ul class="list-disc list-inside">
                            <?php foreach ($errors as $error): ?>
                                <li><?= htmlspecialchars($error) ?></li>
                            <?php endforeach; ?>
                        </ul>
                    </div>
                <?php endif; ?>

                <form method="POST" class="space-y-6">
                    <!-- OpenAI API Key -->
                    <div>
                        <label for="openai_api_key" class="block text-sm font-medium text-gray-700 mb-2">
                            OpenAI API ключ <span class="text-red-500">*</span>
                        </label>
                        <input 
                            type="text" 
                            name="openai_api_key" 
                            id="openai_api_key" 
                            required
                            placeholder="sk-proj-..."
                            class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
                        >
                        <p class="mt-1 text-sm text-gray-500">
                            Получите ключ на <a href="https://platform.openai.com/api-keys" target="_blank" class="text-blue-600 hover:underline">platform.openai.com</a>
                        </p>
                    </div>

                    <!-- App URL -->
                    <div>
                        <label for="app_url" class="block text-sm font-medium text-gray-700 mb-2">
                            URL приложения
                        </label>
                        <input 
                            type="url" 
                            name="app_url" 
                            id="app_url" 
                            value="<?= htmlspecialchars($_SERVER['REQUEST_SCHEME'] ?? 'http') ?>://<?= htmlspecialchars($_SERVER['HTTP_HOST'] ?? 'localhost') ?>"
                            placeholder="https://yourdomain.com"
                            class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
                        >
                        <p class="mt-1 text-sm text-gray-500">
                            URL вашего сайта (автоматически определён)
                        </p>
                    </div>

                    <div class="flex gap-4">
                        <a href="install.php?step=1" class="flex-1 flex justify-center py-3 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50">
                            ← Назад
                        </a>
                        <button 
                            type="submit" 
                            class="flex-1 flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                            Установить 🚀
                        </button>
                    </div>
                </form>
            </div>

            <?php elseif ($step == 3): ?>
            <!-- Step 3: Success -->
            <div class="bg-white rounded-lg shadow-lg p-8 text-center">
                <div class="text-6xl mb-4">🎉</div>
                <h2 class="text-2xl font-bold text-gray-900 mb-4">Установка завершена!</h2>
                <p class="text-gray-600 mb-6">
                    Call Audit Proto успешно установлен и готов к работе.
                </p>
                
                <div class="bg-blue-50 rounded-lg p-4 mb-6 text-left">
                    <h3 class="font-bold text-blue-900 mb-2">✅ Что было сделано:</h3>
                    <ul class="list-disc list-inside text-blue-800 text-sm space-y-1">
                        <li>Создан файл .env с конфигурацией</li>
                        <li>Инициализирована база данных SQLite</li>
                        <li>Созданы необходимые директории</li>
                        <li>Выполнены миграции БД</li>
                    </ul>
                </div>

                <div class="bg-yellow-50 rounded-lg p-4 mb-6 text-left">
                    <h3 class="font-bold text-yellow-900 mb-2">⚠️ Безопасность:</h3>
                    <ul class="list-disc list-inside text-yellow-800 text-sm space-y-1">
                        <li>Удалите install.php после установки</li>
                        <li>Убедитесь что .env не доступен через веб</li>
                        <li>Используйте HTTPS в production</li>
                    </ul>
                </div>

                <a 
                    href="/" 
                    class="inline-flex justify-center py-3 px-6 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                >
                    Перейти к приложению →
                </a>
                
                <p class="mt-4 text-sm text-gray-500">
                    <a href="?reinstall=1" class="text-blue-600 hover:underline">Переустановить</a>
                </p>
            </div>
            <?php endif; ?>

            <!-- Footer -->
            <div class="text-center text-sm text-gray-500">
                <p>Call Audit Proto v1.0</p>
                <p class="mt-1">Система анализа звонков с использованием OpenAI API</p>
            </div>
        </div>
    </div>
</body>
</html>
