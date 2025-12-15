<?php

namespace App\Services;

use App\Domain\Dto\ScoreResult;

class ReportAssembler
{
    private array $config;

    public function __construct()
    {
        $this->loadConfig();
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
     * Assemble final report with calculated scores and penalties
     *
     * @param ScoreResult $scoreResult
     * @return array
     */
    public function assemble(ScoreResult $scoreResult): array
    {
        $data = $scoreResult->toArray();

        // Recalculate and apply ethics penalties
        $scores = $this->applyEthicsPenalties($data);
        $data['scores'] = $scores;

        // Add summary statistics
        $data['summary'] = $this->buildSummary($data);

        return $data;
    }

    private function applyEthicsPenalties(array $data): array
    {
        $scores = $data['scores'] ?? [];
        $ethics = $data['blocks']['ethics'] ?? [];

        $ethicsFlag = false;
        $deduction = 0.0;

        $penaltyConfig = $this->config['scoring']['ethics_penalties'] ?? [];

        foreach ($ethics as $criterion) {
            if ($criterion['violation'] ?? false) {
                // Check if this is a fatal violation
                $isFatal = $this->isFatalEthicsViolation($criterion['id']);
                
                if ($isFatal && ($penaltyConfig['fatal_flag_sets_ethics_flag'] ?? true)) {
                    $ethicsFlag = true;
                }

                if (!$isFatal) {
                    $deduction += $penaltyConfig['non_fatal_deduction'] ?? 1.0;
                }
            }
        }

        // Apply deduction to final score
        $finalScore = ($scores['final_score'] ?? 0) - $deduction;
        $finalScore = max($finalScore, $penaltyConfig['clamp_min'] ?? 0.0);

        return [
            'mandatory_avg' => $scores['mandatory_avg'] ?? 0,
            'general_avg' => $scores['general_avg'] ?? 0,
            'ethics_flag' => $ethicsFlag,
            'final_score' => $finalScore,
            'ethics_deduction' => $deduction,
        ];
    }

    private function isFatalEthicsViolation(string $id): bool
    {
        $ethics = $this->config['scoring']['ethics'] ?? [];
        
        foreach ($ethics as $criterion) {
            if ($criterion['id'] === $id) {
                return $criterion['fatal'] ?? false;
            }
        }

        return false;
    }

    private function buildSummary(array $data): array
    {
        $blocks = $data['blocks'] ?? [];
        $scores = $data['scores'] ?? [];

        $totalCriteria = count($blocks['mandatory'] ?? []) + count($blocks['general'] ?? []);
        $passedCriteria = 0;

        foreach (array_merge($blocks['mandatory'] ?? [], $blocks['general'] ?? []) as $criterion) {
            $score = $criterion['score'] ?? 0;
            $max = $criterion['max'] ?? 1;
            if ($score / $max >= 0.6) {
                $passedCriteria++;
            }
        }

        return [
            'total_criteria' => $totalCriteria,
            'passed_criteria' => $passedCriteria,
            'pass_rate' => $totalCriteria > 0 ? $passedCriteria / $totalCriteria : 0,
            'ethics_violations' => $this->countEthicsViolations($blocks['ethics'] ?? []),
            'trigger_count' => count($data['triggers']['lexicon_hits'] ?? []) + count($data['triggers']['audio_events'] ?? []),
        ];
    }

    private function countEthicsViolations(array $ethics): int
    {
        $count = 0;
        foreach ($ethics as $criterion) {
            if ($criterion['violation'] ?? false) {
                $count++;
            }
        }
        return $count;
    }
}
