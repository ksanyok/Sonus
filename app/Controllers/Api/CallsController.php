<?php

declare(strict_types=1);

namespace App\Controllers\Api;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Repositories\JobRepository;

class CallsController
{
    private JobRepository $jobRepo;
    private string $uploadsDir;

    public function __construct(JobRepository $jobRepo, string $uploadsDir)
    {
        $this->jobRepo = $jobRepo;
        $this->uploadsDir = $uploadsDir;
    }

    public function store(Request $request, Response $response): Response
    {
        $uploadedFiles = $request->getUploadedFiles();
        $params = $request->getParsedBody();

        // Validate audio file
        if (!isset($uploadedFiles['audio'])) {
            $error = ['error' => 'Audio file is required'];
            $response->getBody()->write(json_encode($error));
            return $response
                ->withHeader('Content-Type', 'application/json')
                ->withStatus(400);
        }

        $audioFile = $uploadedFiles['audio'];
        if ($audioFile->getError() !== UPLOAD_ERR_OK) {
            $error = ['error' => 'Audio upload error'];
            $response->getBody()->write(json_encode($error));
            return $response
                ->withHeader('Content-Type', 'application/json')
                ->withStatus(400);
        }

        // Save audio file
        $audioFilename = uniqid('audio_') . '_' . $audioFile->getClientFilename();
        $audioPath = $this->uploadsDir . '/audio/' . $audioFilename;
        $audioFile->moveTo($audioPath);

        // Save rubric file (optional)
        $rubricPath = null;
        if (isset($uploadedFiles['rubric']) && $uploadedFiles['rubric']->getError() === UPLOAD_ERR_OK) {
            $rubricFile = $uploadedFiles['rubric'];
            $rubricFilename = uniqid('rubric_') . '_' . $rubricFile->getClientFilename();
            $rubricPath = $this->uploadsDir . '/rubrics/' . $rubricFilename;
            $rubricFile->moveTo($rubricPath);
        }

        // Create job
        $jobId = $this->jobRepo->create([
            'status' => 'uploaded',
            'audio_path' => $audioPath,
            'rubric_path' => $rubricPath,
            'lang' => $params['lang'] ?? 'auto',
            'webhook_url' => $params['webhook_url'] ?? null,
        ]);

        // Return job info
        $result = [
            'job_id' => $jobId,
            'status' => 'uploaded',
            'message' => 'Job created successfully. Processing will begin shortly.',
        ];

        $response->getBody()->write(json_encode($result));
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus(201);
    }
}
