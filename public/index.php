<?php

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

use App\Bootstrap;
use App\Routes;

// Ensure required directories exist
Bootstrap::ensureDirectories();

// Initialize Slim app
$app = Bootstrap::init();

// Register routes
Routes::register($app);

// Run app
$app->run();
