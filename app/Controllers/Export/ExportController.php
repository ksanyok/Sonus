<?php

declare(strict_types=1);

namespace App\Controllers\Export;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Repositories\ReportRepository;
use App\Services\ExportService;

class ExportController
{
    private ReportRepository $reportRepo;
    private ExportService $exportService;

    public function __construct(
        ReportRepository $reportRepo,
        ExportService $exportService
    ) {
        $this->reportRepo = $reportRepo;
        $this->exportService = $exportService;
    }

    public function json(Request $request, Response $response, array $args): Response
    {
        $reportId = $args['id'];
        $report = $this->reportRepo->find($reportId);

        if (!$report) {
            $response->getBody()->write('Report not found');
            return $response->withStatus(404);
        }

        $json = $this->exportService->toJson($report['json']);

        $response->getBody()->write($json);
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withHeader('Content-Disposition', 'attachment; filename="report_' . $reportId . '.json"');
    }

    public function csv(Request $request, Response $response, array $args): Response
    {
        $reportId = $args['id'];
        $report = $this->reportRepo->find($reportId);

        if (!$report) {
            $response->getBody()->write('Report not found');
            return $response->withStatus(404);
        }

        $csv = $this->exportService->toCsv($report['json']);

        $response->getBody()->write($csv);
        return $response
            ->withHeader('Content-Type', 'text/csv')
            ->withHeader('Content-Disposition', 'attachment; filename="report_' . $reportId . '.csv"');
    }

    public function xlsx(Request $request, Response $response, array $args): Response
    {
        $reportId = $args['id'];
        $report = $this->reportRepo->find($reportId);

        if (!$report) {
            $response->getBody()->write('Report not found');
            return $response->withStatus(404);
        }

        $xlsxContent = $this->exportService->toXlsx($report['json']);

        $response->getBody()->write($xlsxContent);
        return $response
            ->withHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
            ->withHeader('Content-Disposition', 'attachment; filename="report_' . $reportId . '.xlsx"');
    }

    public function pdf(Request $request, Response $response, array $args): Response
    {
        $reportId = $args['id'];
        $report = $this->reportRepo->find($reportId);

        if (!$report) {
            $response->getBody()->write('Report not found');
            return $response->withStatus(404);
        }

        try {
            $pdfContent = $this->exportService->toPdf($report['json']);

            $response->getBody()->write($pdfContent);
            return $response
                ->withHeader('Content-Type', 'application/pdf')
                ->withHeader('Content-Disposition', 'attachment; filename="report_' . $reportId . '.pdf"');
        } catch (\Exception $e) {
            $response->getBody()->write('PDF export not available: ' . $e->getMessage());
            return $response->withStatus(501);
        }
    }
}
