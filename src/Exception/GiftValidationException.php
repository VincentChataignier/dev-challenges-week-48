<?php
declare(strict_types=1);

namespace App\Exception;

class GiftValidationException extends \InvalidArgumentException
{
    public function __construct(string $message, int $exitCode = 0)
    {
        parent::__construct($message, $exitCode);
    }
}
