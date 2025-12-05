<?php
declare(strict_types=1);

namespace App\Service;

use App\Service\Core\CoreExecutorInterface;
use App\Exception\GiftValidationException;
use RuntimeException;

readonly class GiftGenerator
{
    public function __construct(
        private CoreExecutorInterface $coreExecutor,
    ) {
    }

    public function generateGifts(string $jsonPayload): string
    {
        $result = $this->coreExecutor->execute($jsonPayload);

        if ($result->isSuccessful()) {
            return trim($result->output);
        }

        if ($result->isValidationError()) {
            throw new GiftValidationException(
                trim($result->errorOutput) ?: 'Validation error',
                $result->exitCode
            );
        }

        // Crash ou erreur inattendue
        throw new RuntimeException(sprintf(
            'Core crashed with exit code %d: %s',
            $result->exitCode,
            trim($result->errorOutput) ?: 'No error output'
        ));
    }
}
