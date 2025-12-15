<?php

declare(strict_types=1);

namespace App\Repositories;

use PDO;
use Ramsey\Uuid\Uuid;

class EmbeddingRepository
{
    private PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    public function create(string $text, array $vector, array $meta = []): string
    {
        $id = Uuid::uuid4()->toString();
        $now = date('Y-m-d H:i:s');

        // Convert vector array to binary blob
        $vectorBlob = json_encode($vector);

        $stmt = $this->db->prepare(
            'INSERT INTO embeddings (id, text, vector, meta_json, created_at) 
             VALUES (:id, :text, :vector, :meta_json, :created_at)'
        );

        $stmt->execute([
            'id' => $id,
            'text' => $text,
            'vector' => $vectorBlob,
            'meta_json' => json_encode($meta, JSON_UNESCAPED_UNICODE),
            'created_at' => $now,
        ]);

        return $id;
    }

    public function find(string $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM embeddings WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$result) {
            return null;
        }

        $result['vector'] = json_decode($result['vector'], true);
        $result['meta_json'] = json_decode($result['meta_json'], true);
        return $result;
    }

    public function searchSimilar(array $queryVector, int $limit = 3): array
    {
        // Simplified cosine similarity search
        // For production, consider using a vector database or SQLite extension
        $stmt = $this->db->prepare('SELECT * FROM embeddings');
        $stmt->execute();
        $embeddings = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $results = [];
        foreach ($embeddings as $emb) {
            $vector = json_decode($emb['vector'], true);
            $similarity = $this->cosineSimilarity($queryVector, $vector);
            $emb['similarity'] = $similarity;
            $emb['vector'] = $vector;
            $emb['meta_json'] = json_decode($emb['meta_json'], true);
            $results[] = $emb;
        }

        // Sort by similarity descending
        usort($results, fn($a, $b) => $b['similarity'] <=> $a['similarity']);

        return array_slice($results, 0, $limit);
    }

    private function cosineSimilarity(array $a, array $b): float
    {
        if (count($a) !== count($b)) {
            return 0.0;
        }

        $dotProduct = 0.0;
        $magnitudeA = 0.0;
        $magnitudeB = 0.0;

        for ($i = 0; $i < count($a); $i++) {
            $dotProduct += $a[$i] * $b[$i];
            $magnitudeA += $a[$i] * $a[$i];
            $magnitudeB += $b[$i] * $b[$i];
        }

        $magnitudeA = sqrt($magnitudeA);
        $magnitudeB = sqrt($magnitudeB);

        if ($magnitudeA == 0 || $magnitudeB == 0) {
            return 0.0;
        }

        return $dotProduct / ($magnitudeA * $magnitudeB);
    }

    public function all(int $limit = 100): array
    {
        $stmt = $this->db->prepare('SELECT * FROM embeddings ORDER BY created_at DESC LIMIT :limit');
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->execute();

        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($results as &$result) {
            $result['vector'] = json_decode($result['vector'], true);
            $result['meta_json'] = json_decode($result['meta_json'], true);
        }

        return $results;
    }

    public function delete(string $id): void
    {
        $stmt = $this->db->prepare('DELETE FROM embeddings WHERE id = :id');
        $stmt->execute(['id' => $id]);
    }
}
