<?php

declare(strict_types=1);

namespace App\Controllers\Web;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\Views\Twig;

class UploadController
{
    private Twig $view;
    private \App\Repositories\JobRepository $jobRepo;
    private \App\Services\OpenAITranscriber $transcriber;
    private \App\Services\AudioMetricsService $audioMetrics;
    private \App\Services\TriggerDetector $triggerDetector;
    private \App\Services\RubricBuilder $rubricBuilder;
    private \App\Services\OpenAIScorer $scorer;
    private \App\Services\ReportAssembler $reportAssembler;
    private \App\Repositories\ReportRepository $reportRepo;
    private string $uploadsDir;

    public function __construct(
        Twig $view,
        \App\Repositories\JobRepository $jobRepo,
        \App\Repositories\ReportRepository $reportRepo,
        \App\Services\OpenAITranscriber $transcriber,
        \App\Services\AudioMetricsService $audioMetrics,
        \App\Services\TriggerDetector $triggerDetector,
        \App\Services\RubricBuilder $rubricBuilder,
        \App\Services\OpenAIScorer $scorer,
        \App\Services\ReportAssembler $reportAssembler,
        string $uploadsDir
    ) {
        $this->view = $view;
        $this->jobRepo = $jobRepo;
        $this->reportRepo = $reportRepo;
        $this->transcriber = $transcriber;
        $this->audioMetrics = $audioMetrics;
        $this->triggerDetector = $triggerDetector;
        $this->rubricBuilder = $rubricBuilder;
        $this->scorer = $scorer;
        $this->reportAssembler = $reportAssembler;
        $this->uploadsDir = $uploadsDir;
    }

    public function index(Request $request, Response $response): Response
    {
        return $this->view->render($response, 'upload/index.twig');
    }

    public function create(Request $request, Response $response): Response
    {
        // Increase timeout for long-running analysis (up to 5 minutes)
        set_time_limit(300);
        
        error_log("\n=== NEW ANALYSIS REQUEST ===");
        error_log("Time: " . date('Y-m-d H:i:s'));

        $uploadedFiles = $request->getUploadedFiles();
        $params = $request->getParsedBody();
        
        // Validate audio file
        if (!isset($uploadedFiles['audio'])) {
            error_log("ERROR: Audio file is required");
            $response->getBody()->write('Audio file is required');
            return $response->withStatus(400);
        }

        $audioFile = $uploadedFiles['audio'];
        if ($audioFile->getError() !== UPLOAD_ERR_OK) {
            error_log("ERROR: Audio upload error - code: " . $audioFile->getError());
            $response->getBody()->write('Audio upload error');
            return $response->withStatus(400);
        }

        // Save audio file
        $audioFilename = uniqid('audio_') . '_' . $audioFile->getClientFilename();
        $audioPath = $this->uploadsDir . '/audio/' . $audioFilename;
        $audioFile->moveTo($audioPath);
        
        $audioSize = filesize($audioPath);
        error_log("Audio file saved: $audioFilename");
        error_log("Audio size: " . round($audioSize / 1024 / 1024, 2) . " MB");

        // Save rubric file (optional)
        $rubricPath = null;
        if (isset($uploadedFiles['rubric']) && $uploadedFiles['rubric']->getError() === UPLOAD_ERR_OK) {
            $rubricFile = $uploadedFiles['rubric'];
            $rubricFilename = uniqid('rubric_') . '_' . $rubricFile->getClientFilename();
            $rubricPath = $this->uploadsDir . '/rubrics/' . $rubricFilename;
            $rubricFile->moveTo($rubricPath);
            error_log("Rubric file saved: $rubricFilename");
        } else {
            error_log("No rubric file - using default");
        }

        // Create job
        $jobId = $this->jobRepo->create([
            'status' => 'uploaded',
            'audio_path' => $audioPath,
            'rubric_path' => $rubricPath,
            'lang' => $params['lang'] ?? 'auto',
            'webhook_url' => $params['webhook_url'] ?? null,
        ]);
        
        error_log("Job created: $jobId");
        error_log("Language: " . ($params['lang'] ?? 'auto'));

        // Run pipeline synchronously (for prototype)
        try {
            error_log("Starting analysis pipeline...");
            $this->runPipeline($jobId);
            error_log("Pipeline completed successfully");
        } catch (\Exception $e) {
            error_log("ERROR: Pipeline failed - " . $e->getMessage());
            error_log("Stack trace: " . $e->getTraceAsString());
            $this->jobRepo->updateStatus($jobId, 'failed');
            throw $e;
        }

        error_log("Redirecting to job page: /jobs/$jobId");
        error_log("=== END REQUEST ===\n");

        // Redirect to job show page
        return $response
            ->withHeader('Location', '/jobs/' . $jobId)
            ->withStatus(302);
    }

    private function runPipeline(string $jobId): void
    {
        $job = $this->jobRepo->find($jobId);
        if (!$job) {
            throw new \RuntimeException('Job not found');
        }

        $startTime = microtime(true);
        error_log("--- PIPELINE START ---");

        // Step 1: Transcription
        error_log("[1/6] Starting transcription...");
        $stepStart = microtime(true);
        $this->jobRepo->updateStatus($jobId, 'transcribing');
        $transcription = $this->transcriber->transcribe($job['audio_path'], $job['lang']);
        error_log("[1/6] Transcription completed in " . round(microtime(true) - $stepStart, 2) . "s");
        error_log("Segments detected: " . count($transcription->segments));

        // Step 2: Audio Metrics
        error_log("[2/6] Analyzing audio metrics...");
        $stepStart = microtime(true);
        $this->jobRepo->updateStatus($jobId, 'analyzing_metrics');
        $audioMetrics = $this->audioMetrics->analyze($job['audio_path'], $transcription);
        error_log("[2/6] Audio metrics completed in " . round(microtime(true) - $stepStart, 2) . "s");

        // Step 3: Trigger Detection
        error_log("[3/6] Detecting triggers...");
        $stepStart = microtime(true);
        $this->jobRepo->updateStatus($jobId, 'detecting_triggers');
        $triggers = $this->triggerDetector->detect($transcription);
        error_log("[3/6] Trigger detection completed in " . round(microtime(true) - $stepStart, 2) . "s");
        error_log("Triggers found: " . count($triggers));

        // Step 4: Build Rubric
        error_log("[4/6] Building rubric...");
        $stepStart = microtime(true);
        $this->jobRepo->updateStatus($jobId, 'building_rubric');
        $rubric = $this->rubricBuilder->build($job['rubric_path']);
        error_log("[4/6] Rubric built in " . round(microtime(true) - $stepStart, 2) . "s");

        // Step 5: Scoring
        error_log("[5/6] Scoring with AI...");
        $stepStart = microtime(true);
        $this->jobRepo->updateStatus($jobId, 'scoring');
        $scoreResult = $this->scorer->score($transcription, $rubric, $triggers, $audioMetrics);
        error_log("[5/6] Scoring completed in " . round(microtime(true) - $stepStart, 2) . "s");

        // Step 6: Assemble Report
        error_log("[6/6] Assembling report...");
        $stepStart = microtime(true);
        $this->jobRepo->updateStatus($jobId, 'assembling');
        $report = $this->reportAssembler->assemble(
            $scoreResult,
            $transcription,
            $rubric,
            $triggers,
            $audioMetrics
        );
        error_log("[6/6] Report assembled in " . round(microtime(true) - $stepStart, 2) . "s");

        // Save report
        $reportId = $this->reportRepo->create($jobId, $report);
        error_log("Report saved: $reportId");

        // Mark as done
        $this->jobRepo->updateStatus($jobId, 'done');

        $totalTime = microtime(true) - $startTime;
        error_log("--- PIPELINE COMPLETED in " . round($totalTime, 2) . "s ---");
        error_log("Final score: " . ($report['scores']['final_score'] ?? 'N/A'));
        error_log("Ethics flag: " . ($report['scores']['ethics_flag'] ? 'YES' : 'NO'));

        // TODO: Send webhook if configured
        if (!empty($job['webhook_url'])) {
            // Send async webhook notification
        }
    }
}
