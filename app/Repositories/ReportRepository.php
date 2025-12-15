<?php

declare(strict_types=1);

namespace App\Repositories;

use PDO;
use Ramsey\Uuid\Uuid;

class ReportRepository
{
    private PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    public function create(string $jobId, array $reportData): string
    {
        $id = Uuid::uuid4()->toString();
        $now = date('Y-m-d H:i:s');

        $stmt = $this->db->prepare(
            'INSERT INTO reports (id, job_id, json, final_score, mandatory_avg, general_avg, ethics_flag, created_at) 
             VALUES (:id, :job_id, :json, :final_score, :mandatory_avg, :general_avg, :ethics_flag, :created_at)'
        );

        $stmt->execute([
            'id' => $id,
            'job_id' => $jobId,
            'json' => json_encode($reportData, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT),
            'final_score' => $reportData['scores']['final_score'] ?? 0.0,
            'mandatory_avg' => $reportData['scores']['mandatory_avg'] ?? 0.0,
            'general_avg' => $reportData['scores']['general_avg'] ?? 0.0,
            'ethics_flag' => ($reportData['scores']['ethics_flag'] ?? false) ? 1 : 0,
            'created_at' => $now,
        ]);

        return $id;
    }

    public function findByJobId(string $jobId): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM reports WHERE job_id = :job_id ORDER BY created_at DESC LIMIT 1');
        $stmt->execute(['job_id' => $jobId]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$result) {
            return null;
        }

        // Decode JSON
        $result['json'] = json_decode($result['json'], true);
        return $result;
    }

    public function find(string $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM reports WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$result) {
            return null;
        }

        $result['json'] = json_decode($result['json'], true);
        return $result;
    }

    public function delete(string $id): void
    {
        $stmt = $this->db->prepare('DELETE FROM reports WHERE id = :id');
        $stmt->execute(['id' => $id]);
    }

    public function deleteByJobId(string $jobId): void
    {
        $stmt = $this->db->prepare('DELETE FROM reports WHERE job_id = :job_id');
        $stmt->execute(['job_id' => $jobId]);
    }
}
