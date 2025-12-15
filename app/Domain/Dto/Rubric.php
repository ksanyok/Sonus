<?php

namespace App\Domain\Dto;

class Rubric
{
    public function __construct(
        public readonly string $id,
        public readonly string $name,
        public readonly array $mandatory = [],
        public readonly array $general = [],
        public readonly array $ethics = []
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            id: $data['id'] ?? '',
            name: $data['name'] ?? 'Default Rubric',
            mandatory: $data['mandatory'] ?? [],
            general: $data['general'] ?? [],
            ethics: $data['ethics'] ?? []
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'mandatory' => $this->mandatory,
            'general' => $this->general,
            'ethics' => $this->ethics,
        ];
    }

    public function toJsonSchema(): array
    {
        return [
            'type' => 'object',
            'properties' => [
                'call_meta' => [
                    'type' => 'object',
                    'properties' => [
                        'call_type' => ['type' => 'string', 'enum' => ['ptp', 'refusal', 'third_party']],
                        'language' => ['type' => 'string'],
                        'duration_sec' => ['type' => 'number'],
                        'agent_name' => ['type' => 'string'],
                        'client_name' => ['type' => 'string']
                    ],
                    'required' => ['call_type', 'language', 'duration_sec', 'agent_name', 'client_name'],
                    'additionalProperties' => false
                ],
                'blocks' => [
                    'type' => 'object',
                    'properties' => [
                        'mandatory' => $this->buildCriteriaSchema($this->mandatory),
                        'general' => $this->buildCriteriaSchema($this->general),
                        'ethics' => $this->buildEthicsSchema($this->ethics)
                    ],
                    'required' => ['mandatory', 'general', 'ethics'],
                    'additionalProperties' => false
                ],
                'triggers' => [
                    'type' => 'object',
                    'properties' => [
                        'lexicon_hits' => [
                            'type' => 'array',
                            'items' => [
                                'type' => 'object',
                                'properties' => [
                                    'type' => ['type' => 'string'],
                                    'term' => ['type' => 'string'],
                                    't' => ['type' => 'number'],
                                    'speaker' => ['type' => 'string', 'enum' => ['agent', 'client']],
                                    'context' => ['type' => 'string'],
                                    'severity' => ['type' => 'string', 'enum' => ['low', 'medium', 'high']]
                                ],
                                'required' => ['type', 'term', 't', 'speaker', 'context', 'severity'],
                                'additionalProperties' => false
                            ]
                        ],
                        'audio_events' => [
                            'type' => 'array',
                            'items' => [
                                'type' => 'object',
                                'properties' => [
                                    'type' => ['type' => 'string'],
                                    'delta_db' => ['type' => 'number'],
                                    't_start' => ['type' => 'number'],
                                    't_end' => ['type' => 'number'],
                                    'speaker' => ['type' => 'string']
                                ],
                                'required' => ['type', 'delta_db', 't_start', 't_end', 'speaker'],
                                'additionalProperties' => false
                            ]
                        ]
                    ],
                    'required' => ['lexicon_hits', 'audio_events'],
                    'additionalProperties' => false
                ],
                'scores' => [
                    'type' => 'object',
                    'properties' => [
                        'mandatory_avg' => ['type' => 'number'],
                        'general_avg' => ['type' => 'number'],
                        'ethics_flag' => ['type' => 'boolean'],
                        'final_score' => ['type' => 'number']
                    ],
                    'required' => ['mandatory_avg', 'general_avg', 'ethics_flag', 'final_score'],
                    'additionalProperties' => false
                ],
                'recommendations' => [
                    'type' => 'array',
                    'items' => [
                        'type' => 'object',
                        'properties' => [
                            'when' => ['type' => 'string'],
                            'tip' => ['type' => 'string'],
                            'example' => ['type' => 'string']
                        ],
                        'required' => ['when', 'tip', 'example'],
                        'additionalProperties' => false
                    ]
                ],
                'diagnostics' => [
                    'type' => 'object',
                    'properties' => [
                        'transcript_confidence' => ['type' => 'number'],
                        'audio_lufs' => ['type' => 'number'],
                        'agent_talk_ratio' => ['type' => 'number'],
                        'overlap_ratio' => ['type' => 'number'],
                        'avg_response_latency_sec' => ['type' => 'number']
                    ],
                    'required' => ['transcript_confidence', 'audio_lufs', 'agent_talk_ratio', 'overlap_ratio', 'avg_response_latency_sec'],
                    'additionalProperties' => false
                ]
            ],
            'required' => ['call_meta', 'blocks', 'triggers', 'scores', 'recommendations', 'diagnostics'],
            'additionalProperties' => false
        ];
    }

    private function buildCriteriaSchema(array $criteria): array
    {
        return [
            'type' => 'array',
            'items' => [
                'type' => 'object',
                'properties' => [
                    'id' => ['type' => 'string'],
                    'title' => ['type' => 'string'],
                    'max' => ['type' => 'number'],
                    'score' => ['type' => 'number'],
                    'evidence' => [
                        'type' => 'array',
                        'items' => [
                            'type' => 'object',
                            'properties' => [
                                't' => ['type' => 'number'],
                                'text' => ['type' => 'string']
                            ],
                            'required' => ['t', 'text'],
                            'additionalProperties' => false
                        ]
                    ],
                    'comment' => ['type' => 'string']
                ],
                'required' => ['id', 'title', 'max', 'score', 'evidence', 'comment'],
                'additionalProperties' => false
            ]
        ];
    }

    private function buildEthicsSchema(array $ethics): array
    {
        return [
            'type' => 'array',
            'items' => [
                'type' => 'object',
                'properties' => [
                    'id' => ['type' => 'string'],
                    'title' => ['type' => 'string'],
                    'violation' => ['type' => 'boolean'],
                    'timestamps' => [
                        'type' => 'array',
                        'items' => ['type' => 'number']
                    ],
                    'comment' => ['type' => 'string']
                ],
                'required' => ['id', 'title', 'violation', 'timestamps', 'comment'],
                'additionalProperties' => false
            ]
        ];
    }
}
