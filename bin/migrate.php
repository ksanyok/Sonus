#!/usr/bin/env php
<?php

/**
 * Database migration script for SQLite
 */

require __DIR__ . '/../vendor/autoload.php';

use Dotenv\Dotenv;

// Load environment
$dotenv = Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->safeLoad();

$dbPath = $_ENV['DB_PATH'] ?? 'storage/app.sqlite';

// Ensure storage directory exists
$storageDir = dirname($dbPath);
if (!is_dir($storageDir)) {
    mkdir($storageDir, 0755, true);
}

try {
    $pdo = new PDO("sqlite:$dbPath");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "Creating database schema...\n";
    
    // Jobs table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS jobs (
            id TEXT PRIMARY KEY,
            status TEXT NOT NULL DEFAULT 'uploaded',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            audio_path TEXT NOT NULL,
            rubric_path TEXT,
            lang TEXT DEFAULT 'auto',
            webhook_url TEXT
        )
    ");
    echo "✓ Created 'jobs' table\n";
    
    // Reports table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS reports (
            id TEXT PRIMARY KEY,
            job_id TEXT NOT NULL,
            json LONGTEXT NOT NULL,
            final_score REAL,
            mandatory_avg REAL,
            general_avg REAL,
            ethics_flag INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
        )
    ");
    echo "✓ Created 'reports' table\n";
    
    // Rubrics table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS rubrics (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            schema_json LONGTEXT NOT NULL,
            created_at TEXT NOT NULL
        )
    ");
    echo "✓ Created 'rubrics' table\n";
    
    // Embeddings table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS embeddings (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            vector BLOB NOT NULL,
            meta_json LONGTEXT,
            created_at TEXT NOT NULL
        )
    ");
    echo "✓ Created 'embeddings' table\n";
    
    // Triggers table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS triggers (
            id TEXT PRIMARY KEY,
            job_id TEXT NOT NULL,
            t_start REAL,
            t_end REAL,
            type TEXT NOT NULL,
            term TEXT,
            speaker TEXT,
            extra_json LONGTEXT,
            FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
        )
    ");
    echo "✓ Created 'triggers' table\n";
    
    // Create indexes
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_reports_job_id ON reports(job_id)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_triggers_job_id ON triggers(job_id)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_triggers_type ON triggers(type)");
    echo "✓ Created indexes\n";
    
    echo "\n✅ Database migration completed successfully!\n";
    
} catch (PDOException $e) {
    echo "❌ Migration failed: " . $e->getMessage() . "\n";
    exit(1);
}
