<?php

namespace App\Domain\Dto;

class TriggerEvent
{
    public function __construct(
        public readonly string $type,
        public readonly ?string $term,
        public readonly float $tStart,
        public readonly ?float $tEnd,
        public readonly string $speaker,
        public readonly array $extra = []
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            type: $data['type'] ?? 'unknown',
            term: $data['term'] ?? null,
            tStart: $data['t_start'] ?? $data['t'] ?? 0.0,
            tEnd: $data['t_end'] ?? null,
            speaker: $data['speaker'] ?? 'unknown',
            extra: $data['extra'] ?? []
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'type' => $this->type,
            'term' => $this->term,
            't_start' => $this->tStart,
            't_end' => $this->tEnd,
            'speaker' => $this->speaker,
            'extra' => $this->extra,
        ], fn($v) => $v !== null);
    }
}
