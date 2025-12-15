<?php

namespace App\Services;

use App\Domain\Dto\Rubric;
use PhpOffice\PhpSpreadsheet\IOFactory;
use Ramsey\Uuid\Uuid;
use Symfony\Component\Yaml\Yaml;

class RubricBuilder
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
     * Build rubric from Excel file or use default from config
     *
     * @param string|null $excelPath
     * @return Rubric
     * @throws \Exception
     */
    public function build(?string $excelPath = null): Rubric
    {
        if ($excelPath && file_exists($excelPath)) {
            return $this->buildFromExcel($excelPath);
        }

        return $this->buildFromConfig();
    }

    private function buildFromExcel(string $excelPath): Rubric
    {
        try {
            $spreadsheet = IOFactory::load($excelPath);
            
            // Expected sheets: "Компанія" and "Пояснення"
            $companySheet = $spreadsheet->getSheetByName('Компанія');
            $explanationSheet = $spreadsheet->getSheetByName('Пояснення');

            if (!$companySheet) {
                throw new \Exception("Sheet 'Компанія' not found");
            }

            $criteria = $this->parseSheet($companySheet, $explanationSheet);

            return new Rubric(
                id: Uuid::uuid4()->toString(),
                name: 'Custom Rubric from Excel',
                mandatory: $criteria['mandatory'] ?? [],
                general: $criteria['general'] ?? [],
                ethics: $criteria['ethics'] ?? []
            );
        } catch (\Exception $e) {
            throw new \Exception("Failed to parse Excel rubric: " . $e->getMessage());
        }
    }

    private function parseSheet($companySheet, $explanationSheet): array
    {
        // Simplified parsing for prototype
        // In production, implement full Excel parsing logic based on your format
        
        $criteria = [
            'mandatory' => [],
            'general' => [],
            'ethics' => [],
        ];

        // For now, return default criteria
        return $this->getDefaultCriteria();
    }

    private function buildFromConfig(): Rubric
    {
        $criteria = $this->getDefaultCriteria();

        return new Rubric(
            id: Uuid::uuid4()->toString(),
            name: 'Default Rubric',
            mandatory: $criteria['mandatory'],
            general: $criteria['general'],
            ethics: $criteria['ethics']
        );
    }

    private function getDefaultCriteria(): array
    {
        return [
            'mandatory' => $this->config['scoring']['mandatory'] ?? [],
            'general' => $this->config['scoring']['general'] ?? [],
            'ethics' => $this->config['scoring']['ethics'] ?? [],
        ];
    }
}
