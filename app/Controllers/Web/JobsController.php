<?php

declare(strict_types=1);

namespace App\Controllers\Web;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\Views\Twig;
use App\Repositories\JobRepository;
use App\Repositories\ReportRepository;

class JobsController
{
    private Twig $view;
    private JobRepository $jobRepo;
    private ReportRepository $reportRepo;

    public function __construct(
        Twig $view,
        JobRepository $jobRepo,
        ReportRepository $reportRepo
    ) {
        $this->view = $view;
        $this->jobRepo = $jobRepo;
        $this->reportRepo = $reportRepo;
    }

    public function show(Request $request, Response $response, array $args): Response
    {
        $jobId = $args['id'];
        $job = $this->jobRepo->find($jobId);

        if (!$job) {
            $response->getBody()->write('Job not found');
            return $response->withStatus(404);
        }

        $report = $this->reportRepo->findByJobId($jobId);

        return $this->view->render($response, 'jobs/show.twig', [
            'job' => $job,
            'report' => $report,
        ]);
    }
}
