<?php

declare(strict_types=1);

namespace App\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class HealthController
{
    public function __invoke(Request $request, Response $response): Response
    {
        $health = [
            'status' => 'ok',
            'timestamp' => date('c'),
            'service' => 'call-audit-proto',
        ];

        $response->getBody()->write(json_encode($health));
        return $response->withHeader('Content-Type', 'application/json');
    }
}
