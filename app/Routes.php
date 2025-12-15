<?php

declare(strict_types=1);

namespace App;

use Slim\App;

class Routes
{
    public static function register(App $app): void
    {
        // Health check
        $app->get('/healthz', \App\Controllers\HealthController::class);

        // Web routes
        $app->get('/', [\App\Controllers\Web\UploadController::class, 'index']);
        $app->post('/jobs', [\App\Controllers\Web\UploadController::class, 'create']);
        $app->get('/jobs/{id}', [\App\Controllers\Web\JobsController::class, 'show']);

        // Export routes
        $app->get('/export/{id}.json', [\App\Controllers\Export\ExportController::class, 'json']);
        $app->get('/export/{id}.csv', [\App\Controllers\Export\ExportController::class, 'csv']);
        $app->get('/export/{id}.xlsx', [\App\Controllers\Export\ExportController::class, 'xlsx']);
        $app->get('/export/{id}.pdf', [\App\Controllers\Export\ExportController::class, 'pdf']);

        // API routes
        $app->post('/api/calls', [\App\Controllers\Api\CallsController::class, 'store']);
        $app->get('/api/reports/{id}', [\App\Controllers\Api\ReportController::class, 'show']);
    }
}
