<?php
declare(strict_types=1);

namespace App\Service\Core;

use App\ValueObject\CoreResult;

interface CoreExecutorInterface
{
    public function execute(?string $input = null): CoreResult;
}