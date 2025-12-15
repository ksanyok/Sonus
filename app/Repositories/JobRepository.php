<?php

declare(strict_types=1);

namespace App\Repositories;

use PDO;
use Ramsey\Uuid\Uuid;

class JobRepository
{
    private PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    public function create(array $data): string
    {
        $id = Uuid::uuid4()->toString();
        $now = date('Y-m-d H:i:s');

        $stmt = $this->db->prepare(
            'INSERT INTO jobs (id, status, created_at, updated_at, audio_path, rubric_path, lang, webhook_url) 
             VALUES (:id, :status, :created_at, :updated_at, :audio_path, :rubric_path, :lang, :webhook_url)'
        );

        $stmt->execute([
            'id' => $id,
            'status' => $data['status'] ?? 'uploaded',
            'created_at' => $now,
            'updated_at' => $now,
            'audio_path' => $data['audio_path'] ?? null,
            'rubric_path' => $data['rubric_path'] ?? null,
            'lang' => $data['lang'] ?? 'auto',
            'webhook_url' => $data['webhook_url'] ?? null,
        ]);

        return $id;
    }

    public function find(string $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM jobs WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        return $result ?: null;
    }

    public function updateStatus(string $id, string $status): void
    {
        $stmt = $this->db->prepare(
            'UPDATE jobs SET status = :status, updated_at = :updated_at WHERE id = :id'
        );

        $stmt->execute([
            'id' => $id,
            'status' => $status,
            'updated_at' => date('Y-m-d H:i:s'),
        ]);
    }

    public function all(int $limit = 100): array
    {
        $stmt = $this->db->prepare('SELECT * FROM jobs ORDER BY created_at DESC LIMIT :limit');
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function delete(string $id): void
    {
        $stmt = $this->db->prepare('DELETE FROM jobs WHERE id = :id');
        $stmt->execute(['id' => $id]);
    }
}
