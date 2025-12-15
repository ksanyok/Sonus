<?php

namespace App\Services;

use App\Domain\Dto\Rubric;
use App\Domain\Dto\ScoreResult;
use App\Domain\Dto\Transcription;
use GuzzleHttp\Client;

class OpenAIScorer
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
            'timeout' => 120,
            'headers' => [
                'Authorization' => 'Bearer ' . $this->apiKey,
                'Content-Type' => 'application/json',
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
     * Score call using OpenAI with Structured Outputs
     *
     * @param Transcription $transcription
     * @param Rubric $rubric
     * @param array $preliminaryTriggers
     * @param array $audioMetrics
     * @return ScoreResult
     * @throws \Exception
     */
    public function score(
        Transcription $transcription,
        Rubric $rubric,
        array $preliminaryTriggers = [],
        array $audioMetrics = []
    ): ScoreResult {
        $systemPrompt = $this->buildSystemPrompt();
        $userContent = $this->buildUserContent($transcription, $rubric, $preliminaryTriggers, $audioMetrics);
        $jsonSchema = $rubric->toJsonSchema();

        try {
            $response = $this->client->post('/v1/chat/completions', [
                'json' => [
                    'model' => 'gpt-4o-2024-08-06',
                    'messages' => [
                        ['role' => 'system', 'content' => $systemPrompt],
                        ['role' => 'user', 'content' => $userContent],
                    ],
                    'response_format' => [
                        'type' => 'json_schema',
                        'json_schema' => [
                            'name' => 'CallScore',
                            'strict' => true,
                            'schema' => $jsonSchema,
                        ],
                    ],
                    'temperature' => 0.2,
                ],
            ]);

            $data = json_decode($response->getBody()->getContents(), true);
            $scoreData = json_decode($data['choices'][0]['message']['content'] ?? '{}', true);

            return ScoreResult::fromArray($scoreData);
        } catch (\Exception $e) {
            throw new \Exception("Scoring failed: " . $e->getMessage());
        }
    }

    private function buildSystemPrompt(): string
    {
        return <<<PROMPT
Ты — профессиональный аудитор звонков коллекторского агентства.

Твоя задача:
1. Определить имена оператора (agent) и клиента (client) из транскрипта.
   - Имя оператора обычно называется в начале ("Меня зовут...", "Это [имя]...")
   - Имя клиента - к кому обращаются или кто представился
   - Если имя не упоминается, используй "Не указано"

2. Оценить звонок по критериям рубрики (обов'язкові, загальні, етика).
   - Для каждого критерия указать балл (0 до max), цитату из транскрипта с таймкодом
   
3. Выявить ВСЕ случаи грубости, мата, хамства:
   - Для каждого случая указать: тип нарушения, точное слово/фразу, таймкод, спикера
   - Добавить контекст (цитату ~50 символов вокруг нарушения)
   - Оценить серьёзность: low (лёгкая грубость), medium (хамство), high (мат, угрозы)
   
4. Определить тип разговора (PTP/отказ/3-я особа).

5. Сформировать рекомендации для низких баллов.

6. Заполнить диагностику на основе аудио-метрик.

Требования:
- Цитаты должны быть точными выдержками из транскрипта (макс 180 символов).
- Таймкоды в секундах (float).
- Для triggers.lexicon_hits обязательно заполняй context и severity.
- Комментарии краткие, конкретные.
- Строго следуй JSON-схеме.
PROMPT;
    }

    private function buildUserContent(
        Transcription $transcription,
        Rubric $rubric,
        array $triggers,
        array $metrics
    ): string {
        $transcript = $this->formatTranscript($transcription);
        $rubricJson = json_encode($rubric->toArray(), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        $triggersJson = json_encode($triggers, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        $metricsJson = json_encode($metrics, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

        return <<<CONTENT
# ТРАНСКРИПТ
$transcript

# РУБРИКА
$rubricJson

# ПРЕДВАРИТЕЛЬНЫЕ ТРИГГЕРЫ
$triggersJson

# АУДИО-МЕТРИКИ
$metricsJson

Проанализируй звонок и заполни схему оценки.
CONTENT;
    }

    private function formatTranscript(Transcription $transcription): string
    {
        $output = "Язык: {$transcription->language}\n";
        $output .= "Длительность: " . round($transcription->duration, 2) . " сек\n\n";

        foreach ($transcription->segments as $seg) {
            $start = round($seg['start'] ?? 0, 2);
            $end = round($seg['end'] ?? 0, 2);
            $text = $seg['text'] ?? '';
            $speaker = $this->detectSpeaker($seg);
            
            $output .= "[$start-$end] $speaker: $text\n";
        }

        return $output;
    }

    private function detectSpeaker(array $segment): string
    {
        // Simple heuristic: alternate between agent and client
        // In real scenario, use speaker diarization
        static $lastSpeaker = 'client';
        
        if (isset($segment['speaker'])) {
            return $segment['speaker'];
        }

        $lastSpeaker = $lastSpeaker === 'agent' ? 'client' : 'agent';
        return $lastSpeaker;
    }
}
