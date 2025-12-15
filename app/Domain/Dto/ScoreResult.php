<?php

namespace App\Domain\Dto;

class ScoreResult
{
    public function __construct(
        public readonly array $callMeta,
        public readonly array $blocks,
        public readonly array $triggers,
        public readonly array $scores,
        public readonly array $recommendations = [],
        public readonly array $diagnostics = []
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            callMeta: $data['call_meta'] ?? [],
            blocks: $data['blocks'] ?? [],
            triggers: $data['triggers'] ?? [],
            scores: $data['scores'] ?? [],
            recommendations: $data['recommendations'] ?? [],
            diagnostics: $data['diagnostics'] ?? []
        );
    }

    public function toArray(): array
    {
        return [
            'call_meta' => $this->callMeta,
            'blocks' => $this->blocks,
            'triggers' => $this->triggers,
            'scores' => $this->scores,
            'recommendations' => $this->recommendations,
            'diagnostics' => $this->diagnostics,
        ];
    }
}
