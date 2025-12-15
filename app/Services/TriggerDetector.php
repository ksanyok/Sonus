<?php

namespace App\Services;

use App\Domain\Dto\TriggerEvent;
use App\Domain\Dto\Transcription;

class TriggerDetector
{
    private array $config;
    private array $lexicons = [];

    public function __construct()
    {
        $this->loadConfig();
        $this->loadLexicons();
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
     * Detect triggers in transcription
     *
     * @param Transcription $transcription
     * @return array
     */
    public function detect(Transcription $transcription): array
    {
        $triggers = [];

        if (!($this->config['lexicon_triggers']['enable'] ?? true)) {
            return $triggers;
        }

        foreach ($transcription->segments as $segment) {
            $text = $segment['text'] ?? '';
            $normalized = $this->normalizeText($text);
            $timestamp = $segment['start'] ?? 0.0;
            $speaker = $this->detectSpeaker($segment);

            foreach ($this->lexicons as $category => $terms) {
                foreach ($terms as $term) {
                    if ($this->containsTerm($normalized, $term)) {
                        $triggers[] = new TriggerEvent(
                            type: $category,
                            term: $term,
                            tStart: $timestamp,
                            tEnd: $segment['end'] ?? $timestamp,
                            speaker: $speaker
                        );
                    }
                }
            }
        }

        return $triggers;
    }

    private function loadLexicons(): void
    {
        $categories = $this->config['lexicon_triggers']['categories'] ?? [];

        foreach ($categories as $name => $spec) {
            $this->lexicons[$name] = [];

            // Load from files
            if (isset($spec['files'])) {
                foreach ($spec['files'] as $file) {
                    if (file_exists($file)) {
                        $content = file_get_contents($file);
                        $terms = array_filter(array_map('trim', explode("\n", $content)));
                        $this->lexicons[$name] = array_merge($this->lexicons[$name], $terms);
                    }
                }
            }

            // Load inline terms
            if (isset($spec['inline'])) {
                $this->lexicons[$name] = array_merge($this->lexicons[$name], $spec['inline']);
            }
        }
    }

    private function normalizeText(string $text): string
    {
        $normalize = $this->config['lexicon_triggers']['normalize'] ?? [];

        if ($normalize['lower'] ?? true) {
            $text = mb_strtolower($text, 'UTF-8');
        }

        if ($normalize['strip_punct'] ?? true) {
            $text = preg_replace('/[^\p{L}\p{N}\s]/u', ' ', $text);
        }

        if ($normalize['collapse_spaces'] ?? true) {
            $text = preg_replace('/\s+/', ' ', $text);
        }

        if ($normalize['deobfuscate'] ?? true) {
            // Remove asterisks and spaces within words (e.g., "б*ля" -> "бля")
            $text = str_replace(['*', '_'], '', $text);
        }

        return trim($text);
    }

    private function containsTerm(string $text, string $term): bool
    {
        $normalizedTerm = $this->normalizeText($term);
        return mb_strpos($text, $normalizedTerm, 0, 'UTF-8') !== false;
    }

    private function detectSpeaker(array $segment): string
    {
        // Simple heuristic
        static $lastSpeaker = 'client';
        
        if (isset($segment['speaker'])) {
            return $segment['speaker'];
        }

        $lastSpeaker = $lastSpeaker === 'agent' ? 'client' : 'agent';
        return $lastSpeaker;
    }
}
