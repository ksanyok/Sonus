<?php

namespace App\Services;

use App\Domain\Dto\Transcription;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

class OpenAITranscriber
{
    private Client $client;
    private string $apiKey;
    private array $config;

    public function __construct()
    {
        $this->loadConfig();
        $this->apiKey = $_ENV['OPENAI_API_KEY'] ?? '';
        
        $this->client = new Client([
            'base_uri' => 'https://api.openai.com',
            'timeout' => 300,
            'headers' => [
                'Authorization' => 'Bearer ' . $this->apiKey,
            ],
        ]);
    }

    private function loadConfig(): void
    {
        $configPath = __DIR__ . '/../../config/analysis.core.yml';
        if (file_exists($configPath)) {
            $this->config = \Symfony\Component\Yaml\Yaml::parseFile($configPath);
        } else {
            $this->config = [];
        }
    }

    /**
     * Transcribe audio file using OpenAI Whisper API
     *
     * @param string $audioPath Path to audio file
     * @param string $language Language hint (ru|uk|auto)
     * @return Transcription
     * @throws \Exception
     */
    public function transcribe(string $audioPath, string $language = 'auto'): Transcription
    {
        if (!file_exists($audioPath)) {
            throw new \Exception("Audio file not found: $audioPath");
        }

        $model = $this->config['transcription']['model'] ?? 'gpt-4o-mini-transcribe';
        $responseFormat = $this->config['transcription']['response_format'] ?? 'verbose_json';

        $multipart = [
            [
                'name' => 'file',
                'contents' => fopen($audioPath, 'r'),
                'filename' => basename($audioPath),
            ],
            [
                'name' => 'model',
                'contents' => $model,
            ],
            [
                'name' => 'response_format',
                'contents' => $responseFormat,
            ],
        ];

        if ($language !== 'auto') {
            $multipart[] = [
                'name' => 'language',
                'contents' => $language,
            ];
        }

        try {
            $response = $this->client->post('/v1/audio/transcriptions', [
                'multipart' => $multipart,
            ]);

            $data = json_decode($response->getBody()->getContents(), true);

            return $this->parseResponse($data, $language);
        } catch (GuzzleException $e) {
            // Fallback to alternative model if available
            if ($model === 'gpt-4o-mini-transcribe') {
                $this->config['transcription']['model'] = 'whisper-1';
                return $this->transcribe($audioPath, $language);
            }
            
            throw new \Exception("Transcription failed: " . $e->getMessage());
        }
    }

    private function parseResponse(array $data, string $languageHint): Transcription
    {
        $text = $data['text'] ?? '';
        $language = $data['language'] ?? $languageHint;
        $duration = $data['duration'] ?? 0.0;
        $segments = $data['segments'] ?? [];
        
        // Calculate average confidence from segments
        $confidence = 0.0;
        if (!empty($segments)) {
            $totalConfidence = array_reduce($segments, function ($carry, $seg) {
                return $carry + ($seg['avg_logprob'] ?? 0.0);
            }, 0.0);
            $confidence = exp($totalConfidence / count($segments));
        }

        return new Transcription(
            text: $text,
            language: $language,
            duration: $duration,
            segments: $segments,
            confidence: $confidence
        );
    }
}
