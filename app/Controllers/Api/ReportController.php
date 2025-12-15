<?php

declare(strict_types=1);

namespace App\Controllers\Api;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Repositories\ReportRepository;

class ReportController
{
    private ReportRepository $reportRepo;

    public function __construct(ReportRepository $reportRepo)
    {
        $this->reportRepo = $reportRepo;
    }

    public function show(Request $request, Response $response, array $args): Response
    {
        $reportId = $args['id'];
        $report = $this->reportRepo->find($reportId);

        if (!$report) {
            $error = ['error' => 'Report not found'];
            $response->getBody()->write(json_encode($error));
            return $response
                ->withHeader('Content-Type', 'application/json')
                ->withStatus(404);
        }

        $response->getBody()->write(json_encode($report['json'], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
        return $response->withHeader('Content-Type', 'application/json');
    }
}
