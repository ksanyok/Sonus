<?php

namespace App\Domain\Dto;

class Recommendation
{
    public function __construct(
        public readonly string $when,
        public readonly string $tip,
        public readonly ?string $example = null
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            when: $data['when'] ?? '',
            tip: $data['tip'] ?? '',
            example: $data['example'] ?? null
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'when' => $this->when,
            'tip' => $this->tip,
            'example' => $this->example,
        ], fn($v) => $v !== null && $v !== '');
    }
}
