<?php

declare(strict_types=1);

namespace App;

use Dotenv\Dotenv;
use PDO;
use Slim\Factory\AppFactory;
use Slim\Views\Twig;
use Slim\Views\TwigMiddleware;
use DI\Container;
use DI\ContainerBuilder;

class Bootstrap
{
    public static function init(): \Slim\App
    {
        // Load environment variables
        $dotenv = Dotenv::createImmutable(__DIR__ . '/..');
        $dotenv->load();

        // Set timezone
        date_default_timezone_set($_ENV['TZ'] ?? 'Europe/Kyiv');

        // Build DI container
        $container = self::buildContainer();

        // Create Slim app
        AppFactory::setContainer($container);
        $app = AppFactory::create();

        // Add error middleware
        $app->addErrorMiddleware(
            (bool)($_ENV['APP_DEBUG'] ?? true),
            true,
            true
        );

        // Add routing middleware
        $app->addRoutingMiddleware();

        // Add Twig middleware
        $app->add(TwigMiddleware::createFromContainer($app));

        return $app;
    }

    private static function buildContainer(): Container
    {
        $containerBuilder = new ContainerBuilder();

        $containerBuilder->addDefinitions([
            // Database
            PDO::class => function () {
                $dbPath = $_ENV['DB_PATH'] ?? 'storage/app.sqlite';
                
                // Make path absolute if it's relative
                if (!str_starts_with($dbPath, '/')) {
                    $dbPath = __DIR__ . '/../' . $dbPath;
                }
                
                // Log the actual path being used
                error_log("🔍 PDO connecting to: " . $dbPath);
                error_log("🔍 File exists: " . (file_exists($dbPath) ? 'YES' : 'NO'));
                error_log("🔍 File size: " . (file_exists($dbPath) ? filesize($dbPath) : 0) . " bytes");
                
                $dbDir = dirname($dbPath);
                
                if (!is_dir($dbDir)) {
                    mkdir($dbDir, 0755, true);
                }

                $pdo = new PDO('sqlite:' . $dbPath);
                $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
                $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
                
                // Verify tables exist
                $tables = $pdo->query("SELECT name FROM sqlite_master WHERE type='table'")->fetchAll(PDO::FETCH_COLUMN);
                error_log("🔍 Tables in DB: " . implode(', ', $tables));
                
                return $pdo;
            },

            // Twig
            Twig::class => function () {
                return Twig::create(__DIR__ . '/Views', [
                    'cache' => false, // For development
                ]);
            },
            'view' => function () {
                return Twig::create(__DIR__ . '/Views', [
                    'cache' => false, // For development
                ]);
            },

            // Config
            'config' => function () {
                $configPath = __DIR__ . '/../config/analysis.core.yml';
                return \Symfony\Component\Yaml\Yaml::parseFile($configPath);
            },

            // Paths
            'uploads_dir' => $_ENV['UPLOADS_DIR'] ?? __DIR__ . '/../storage/uploads',
            'reports_dir' => $_ENV['REPORTS_DIR'] ?? __DIR__ . '/../storage/reports',

            // Repositories
            \App\Repositories\JobRepository::class => \DI\autowire(),
            \App\Repositories\ReportRepository::class => \DI\autowire(),
            \App\Repositories\RubricRepository::class => \DI\autowire(),
            \App\Repositories\EmbeddingRepository::class => \DI\autowire(),

            // Services
            \App\Services\OpenAITranscriber::class => \DI\autowire(),
            \App\Services\AudioMetricsService::class => \DI\autowire(),
            \App\Services\TriggerDetector::class => \DI\autowire(),
            \App\Services\RubricBuilder::class => \DI\autowire(),
            \App\Services\OpenAIScorer::class => \DI\autowire(),
            \App\Services\ReportAssembler::class => \DI\autowire(),
            \App\Services\ExportService::class => \DI\autowire(),

            // Controllers
            \App\Controllers\HealthController::class => \DI\autowire(),
            \App\Controllers\Web\UploadController::class => \DI\autowire()
                ->constructorParameter('uploadsDir', \DI\get('uploads_dir')),
            \App\Controllers\Web\JobsController::class => \DI\autowire(),
            \App\Controllers\Export\ExportController::class => \DI\autowire(),
            \App\Controllers\Api\CallsController::class => \DI\autowire()
                ->constructorParameter('uploadsDir', \DI\get('uploads_dir')),
            \App\Controllers\Api\ReportController::class => \DI\autowire(),
        ]);

        return $containerBuilder->build();
    }

    public static function ensureDirectories(): void
    {
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
        }
    }
}
