<?php
declare(strict_types=1);

namespace App\ValueObject;

readonly class CoreResult
{
    public const int EXIT_SUCCESS       = 0;
    public const int EXIT_INPUT_ERROR   = 1;
    public const int EXIT_RUNTIME_ERROR = 2;

    private function __construct(
        public int    $exitCode,
        public string $output,
        public string $errorOutput,
    ) {
    }

    public static function success(string $output): self
    {
        return new self(self::EXIT_SUCCESS, $output, '');
    }

    public static function inputError(string $errorMessage = 'Invalid JSON input'): self
    {
        return new self(self::EXIT_INPUT_ERROR, '', $errorMessage);
    }

    public static function runtimeError(string $errorMessage = 'Invalid data (age or interests)'): self
    {
        return new self(self::EXIT_RUNTIME_ERROR, '', $errorMessage);
    }

    public static function crash(int $exitCode, string $errorOutput = ''): self
    {
        return new self($exitCode, '', $errorOutput);
    }

    public function isSuccessful(): bool
    {
        return $this->exitCode === self::EXIT_SUCCESS;
    }

    public function isInputError(): bool
    {
        return $this->exitCode === self::EXIT_INPUT_ERROR;
    }

    public function isRuntimeError(): bool
    {
        return $this->exitCode === self::EXIT_RUNTIME_ERROR;
    }

    public function isValidationError(): bool
    {
        return $this->isInputError() || $this->isRuntimeError();
    }
}
