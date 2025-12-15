<?php

declare(strict_types=1);

namespace App\Repositories;

use PDO;
use Ramsey\Uuid\Uuid;

class RubricRepository
{
    private PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    public function create(string $name, array $schema): string
    {
        $id = Uuid::uuid4()->toString();
        $now = date('Y-m-d H:i:s');

        $stmt = $this->db->prepare(
            'INSERT INTO rubrics (id, name, schema_json, created_at) 
             VALUES (:id, :name, :schema_json, :created_at)'
        );

        $stmt->execute([
            'id' => $id,
            'name' => $name,
            'schema_json' => json_encode($schema, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT),
            'created_at' => $now,
        ]);

        return $id;
    }

    public function find(string $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM rubrics WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$result) {
            return null;
        }

        $result['schema_json'] = json_decode($result['schema_json'], true);
        return $result;
    }

    public function findByName(string $name): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM rubrics WHERE name = :name ORDER BY created_at DESC LIMIT 1');
        $stmt->execute(['name' => $name]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$result) {
            return null;
        }

        $result['schema_json'] = json_decode($result['schema_json'], true);
        return $result;
    }

    public function all(int $limit = 100): array
    {
        $stmt = $this->db->prepare('SELECT * FROM rubrics ORDER BY created_at DESC LIMIT :limit');
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->execute();

        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($results as &$result) {
            $result['schema_json'] = json_decode($result['schema_json'], true);
        }

        return $results;
    }

    public function delete(string $id): void
    {
        $stmt = $this->db->prepare('DELETE FROM rubrics WHERE id = :id');
        $stmt->execute(['id' => $id]);
    }
}
