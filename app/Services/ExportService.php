<?php

declare(strict_types=1);

namespace App\Services;

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class ExportService
{
    public function __construct()
    {
    }

    public function toJson(array $reportData): string
    {
        return json_encode($reportData, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    }

    public function toCsv(array $reportData): string
    {
        $output = fopen('php://temp', 'r+');
        
        // Header
        fputcsv($output, ['Блок', 'Критерий', 'Макс', 'Факт', 'Цитата', 'Таймкод', 'Комментарий']);
        
        // Mandatory
        foreach ($reportData['blocks']['mandatory'] ?? [] as $item) {
            $evidence = $item['evidence'][0] ?? null;
            fputcsv($output, [
                'Обов\'язкові',
                $item['title'] ?? '',
                $item['max'] ?? '',
                $item['score'] ?? '',
                $evidence['text'] ?? '',
                $evidence ? $evidence['t'] : '',
                $item['comment'] ?? ''
            ]);
        }
        
        // General
        foreach ($reportData['blocks']['general'] ?? [] as $item) {
            $evidence = $item['evidence'][0] ?? null;
            fputcsv($output, [
                'Загальні',
                $item['title'] ?? '',
                $item['max'] ?? '',
                $item['score'] ?? '',
                $evidence['text'] ?? '',
                $evidence ? $evidence['t'] : '',
                $item['comment'] ?? ''
            ]);
        }
        
        // Ethics
        foreach ($reportData['blocks']['ethics'] ?? [] as $item) {
            fputcsv($output, [
                'Етика',
                $item['title'] ?? '',
                '',
                $item['violation'] ? 'Порушення' : 'OK',
                '',
                implode(', ', $item['timestamps'] ?? []),
                $item['comment'] ?? ''
            ]);
        }
        
        rewind($output);
        $csv = stream_get_contents($output);
        fclose($output);
        
        return $csv;
    }

    public function toXlsx(array $reportData): string
    {
        $spreadsheet = new Spreadsheet();
        
        // Scores sheet
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Оценка');
        
        // Header
        $sheet->fromArray(['Блок', 'Критерий', 'Макс', 'Факт', 'Цитата', 'Таймкод', 'Комментарий'], null, 'A1');
        
        $row = 2;
        
        // Mandatory
        foreach ($reportData['blocks']['mandatory'] ?? [] as $item) {
            $evidence = $item['evidence'][0] ?? null;
            $sheet->fromArray([
                'Обов\'язкові',
                $item['title'] ?? '',
                $item['max'] ?? '',
                $item['score'] ?? '',
                $evidence['text'] ?? '',
                $evidence ? $evidence['t'] : '',
                $item['comment'] ?? ''
            ], null, 'A' . $row++);
        }
        
        // General
        foreach ($reportData['blocks']['general'] ?? [] as $item) {
            $evidence = $item['evidence'][0] ?? null;
            $sheet->fromArray([
                'Загальні',
                $item['title'] ?? '',
                $item['max'] ?? '',
                $item['score'] ?? '',
                $evidence['text'] ?? '',
                $evidence ? $evidence['t'] : '',
                $item['comment'] ?? ''
            ], null, 'A' . $row++);
        }
        
        // Ethics
        foreach ($reportData['blocks']['ethics'] ?? [] as $item) {
            $sheet->fromArray([
                'Етика',
                $item['title'] ?? '',
                '',
                $item['violation'] ? 'Порушення' : 'OK',
                '',
                implode(', ', $item['timestamps'] ?? []),
                $item['comment'] ?? ''
            ], null, 'A' . $row++);
        }
        
        // Auto-size columns
        foreach (range('A', 'G') as $col) {
            $sheet->getColumnDimension($col)->setAutoSize(true);
        }
        
        // Write to string
        $writer = new Xlsx($spreadsheet);
        ob_start();
        $writer->save('php://output');
        $xlsxContent = ob_get_clean();
        
        return $xlsxContent;
    }

    public function toPdf(array $reportData): string
    {
        // PDF export is optional - requires dompdf
        if (!class_exists(\Dompdf\Dompdf::class)) {
            throw new \RuntimeException('PDF export requires dompdf. Install with: composer require dompdf/dompdf');
        }
        
        // Simple HTML report
        $html = '<h1>Call Audit Report</h1>';
        $html .= '<h2>Scores</h2>';
        $html .= '<p>Final Score: ' . ($reportData['scores']['final_score'] ?? 0) . '</p>';
        $html .= '<p>Mandatory Avg: ' . ($reportData['scores']['mandatory_avg'] ?? 0) . '</p>';
        $html .= '<p>General Avg: ' . ($reportData['scores']['general_avg'] ?? 0) . '</p>';
        $html .= '<p>Ethics Flag: ' . ($reportData['scores']['ethics_flag'] ? 'YES' : 'NO') . '</p>';
        
        $dompdf = new \Dompdf\Dompdf();
        $dompdf->loadHtml($html);
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();
        
        return $dompdf->output();
    }
}
