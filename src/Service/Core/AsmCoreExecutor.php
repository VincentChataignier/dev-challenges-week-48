<?php
declare(strict_types=1);

namespace App\Service\Core;

use App\ValueObject\CoreResult;
use RuntimeException;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\Process\Process;

class AsmCoreExecutor implements CoreExecutorInterface
{
    private readonly string $absoluteBinaryPath;

    public function __construct(
        #[Autowire(env: 'GIFT_ASM_BINARY_PATH')]
        string $binaryPath,
        #[Autowire('%kernel.project_dir%')]
        string $projectDir,
    ) {
        $this->absoluteBinaryPath = $projectDir . '/' . $binaryPath;
    }

    public function execute(?string $input = null): CoreResult
    {
        if (!$this->isBinaryExecutable()) {
            throw new RuntimeException(sprintf('ASM binary not found or not executable: %s', $this->absoluteBinaryPath));
        }

        $process = $this->createProcess();

        if ($input !== null) {
            $process->setInput($input);
        }

        $process->run();

        $exitCode    = $process->getExitCode() ?? -1;
        $output      = $process->getOutput();
        $errorOutput = $process->getErrorOutput();

        return match ($exitCode) {
            CoreResult::EXIT_SUCCESS       => CoreResult::success($output),
            CoreResult::EXIT_INPUT_ERROR   => CoreResult::inputError($errorOutput ?: 'Invalid JSON input'),
            CoreResult::EXIT_RUNTIME_ERROR => CoreResult::runtimeError($errorOutput ?: 'Invalid data (age or interests)'),
            default                        => CoreResult::crash($exitCode, $errorOutput),
        };
    }

    protected function createProcess(): Process
    {
        return new Process([$this->absoluteBinaryPath]);
    }

    protected function isBinaryExecutable(): bool
    {
        return is_executable($this->absoluteBinaryPath);
    }
}
