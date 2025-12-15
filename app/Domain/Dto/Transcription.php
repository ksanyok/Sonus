<?php

namespace App\Domain\Dto;

class Transcription
{
    public function __construct(
        public readonly string $text,
        public readonly string $language,
        public readonly float $duration,
        public readonly array $segments = [],
        public readonly float $confidence = 0.0
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            text: $data['text'] ?? '',
            language: $data['language'] ?? 'unknown',
            duration: $data['duration'] ?? 0.0,
            segments: $data['segments'] ?? [],
            confidence: $data['confidence'] ?? 0.0
        );
    }

    public function toArray(): array
    {
        return [
            'text' => $this->text,
            'language' => $this->language,
            'duration' => $this->duration,
            'segments' => $this->segments,
            'confidence' => $this->confidence,
        ];
    }
}
