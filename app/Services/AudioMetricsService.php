<?php

namespace App\Services;

use Symfony\Component\Process\Process;
use Symfony\Component\Process\Exception\ProcessFailedException;

class AudioMetricsService
{
    private array $config;
    private string $ffmpegPath;

    public function __construct()
    {
        $this->loadConfig();
        $this->ffmpegPath = $_ENV['FFMPEG_PATH'] ?? 'ffmpeg';
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
     * Calculate audio metrics using FFmpeg
     *
     * @param string $audioPath
     * @return array
     * @throws \Exception
     */
    public function analyze(string $audioPath): array
    {
        if (!file_exists($audioPath)) {
            throw new \Exception("Audio file not found: $audioPath");
        }

        $metrics = [
            'lufs' => $this->calculateLUFS($audioPath),
            'rms' => $this->calculateRMS($audioPath),
            'peaks' => $this->detectPeaks($audioPath),
            'silence' => $this->detectSilence($audioPath),
        ];

        return $metrics;
    }

    private function calculateLUFS(string $audioPath): float
    {
        $process = new Process([
            $this->ffmpegPath,
            '-i', $audioPath,
            '-filter_complex', 'ebur128=framelog=verbose',
            '-f', 'null',
            '-'
        ]);

        $process->run();

        if (!$process->isSuccessful()) {
            return 0.0;
        }

        $output = $process->getErrorOutput();
        
        // Parse LUFS from output
        if (preg_match('/I:\s+(-?\d+\.\d+)\s+LUFS/', $output, $matches)) {
            return (float) $matches[1];
        }

        return 0.0;
    }

    private function calculateRMS(string $audioPath): array
    {
        $process = new Process([
            $this->ffmpegPath,
            '-i', $audioPath,
            '-filter:a', 'astats=metadata=1:reset=1',
            '-f', 'null',
            '-'
        ]);

        $process->run();

        if (!$process->isSuccessful()) {
            return ['avg' => 0.0, 'peak' => 0.0];
        }

        $output = $process->getErrorOutput();
        
        $rmsAvg = 0.0;
        $rmsPeak = 0.0;

        if (preg_match('/RMS level dB:\s+(-?\d+\.\d+)/', $output, $matches)) {
            $rmsAvg = (float) $matches[1];
        }

        if (preg_match('/Peak level dB:\s+(-?\d+\.\d+)/', $output, $matches)) {
            $rmsPeak = (float) $matches[1];
        }

        return ['avg' => $rmsAvg, 'peak' => $rmsPeak];
    }

    private function detectPeaks(string $audioPath): array
    {
        $threshold = $this->config['audio_metrics']['db_spike_threshold_db'] ?? 9.0;
        
        $process = new Process([
            $this->ffmpegPath,
            '-i', $audioPath,
            '-filter:a', "astats=metadata=1:reset=1,ametadata=mode=print:file=-",
            '-f', 'null',
            '-'
        ]);

        $process->run();

        // Simplified: return empty array for prototype
        // In production, parse detailed peak information
        return [];
    }

    private function detectSilence(string $audioPath): array
    {
        $minSilence = ($this->config['audio_metrics']['overlap_window_ms'] ?? 400) / 1000;
        
        $process = new Process([
            $this->ffmpegPath,
            '-i', $audioPath,
            '-af', "silencedetect=noise=-50dB:d=$minSilence",
            '-f', 'null',
            '-'
        ]);

        $process->run();

        $output = $process->getErrorOutput();
        $silences = [];

        // Parse silence periods
        preg_match_all('/silence_start: (\d+\.\d+)/', $output, $starts);
        preg_match_all('/silence_end: (\d+\.\d+)/', $output, $ends);

        for ($i = 0; $i < count($starts[1]); $i++) {
            $silences[] = [
                'start' => (float) $starts[1][$i],
                'end' => (float) ($ends[1][$i] ?? $starts[1][$i]),
            ];
        }

        return $silences;
    }

    /**
     * Calculate derived metrics
     */
    public function calculateDerivedMetrics(array $metrics, array $segments): array
    {
        $totalDuration = end($segments)['end'] ?? 0;
        
        // Agent talk ratio (simplified heuristic)
        $agentDuration = 0;
        foreach ($segments as $seg) {
            if (($seg['speaker'] ?? 'agent') === 'agent') {
                $agentDuration += ($seg['end'] - $seg['start']);
            }
        }
        
        $agentTalkRatio = $totalDuration > 0 ? $agentDuration / $totalDuration : 0;

        // Overlap ratio (simplified)
        $overlapRatio = 0.0;

        // Average response latency
        $latencies = [];
        for ($i = 1; $i < count($segments); $i++) {
            if (($segments[$i-1]['speaker'] ?? '') !== ($segments[$i]['speaker'] ?? '')) {
                $latency = $segments[$i]['start'] - $segments[$i-1]['end'];
                if ($latency > 0) {
                    $latencies[] = $latency;
                }
            }
        }
        
        $avgLatency = !empty($latencies) ? array_sum($latencies) / count($latencies) : 0;

        return [
            'lufs' => $metrics['lufs'] ?? 0.0,
            'agent_talk_ratio' => $agentTalkRatio,
            'overlap_ratio' => $overlapRatio,
            'avg_response_latency_sec' => $avgLatency,
        ];
    }
}
