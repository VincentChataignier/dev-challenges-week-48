<?php
declare(strict_types=1);

namespace App\Tests\Service\Core;

use App\Service\Core\AsmCoreExecutor;
use App\ValueObject\CoreResult;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Symfony\Component\Process\Process;

#[Group('unit')]
class AsmCoreExecutorTest extends TestCase
{
    #[Test]
    public function testExecuteThrowsExceptionWhenBinaryNotFound(): void
    {
        $executor = new AsmCoreExecutor('nonexistent/path/to/binary', '/tmp');

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('ASM binary not found or not executable');

        $executor->execute('{"age":33,"interests":"test"}');
    }

    #[Test]
    public function testExecuteThrowsExceptionWhenBinaryNotExecutable(): void
    {
        // use existing file (relative to empty project dir)
        $executor = new AsmCoreExecutor(__FILE__, '');

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('ASM binary not found or not executable');

        $executor->execute('{"age":33,"interests":"test"}');
    }

    #[Test]
    public function testExecuteReturnsSuccessOnExitCode0(): void
    {
        $executor = $this->createPartialMockExecutor(0, '{"ideas":["Gift"]}', '');

        $result = $executor->execute('{"age":33}');

        $this->assertTrue($result->isSuccessful());
        $this->assertSame('{"ideas":["Gift"]}', $result->output);
    }

    #[Test]
    public function testExecuteReturnsInputErrorOnExitCode1(): void
    {
        $executor = $this->createPartialMockExecutor(1, '', 'Invalid JSON');

        $result = $executor->execute('invalid');

        $this->assertTrue($result->isInputError());
        $this->assertSame('Invalid JSON', $result->errorOutput);
    }

    #[Test]
    public function testExecuteReturnsInputErrorWithDefaultMessageOnExitCode1(): void
    {
        $executor = $this->createPartialMockExecutor(1, '', '');

        $result = $executor->execute('invalid');

        $this->assertTrue($result->isInputError());
        $this->assertSame('Invalid JSON input', $result->errorOutput);
    }

    #[Test]
    public function testExecuteReturnsRuntimeErrorOnExitCode2(): void
    {
        $executor = $this->createPartialMockExecutor(2, '', 'Invalid age');

        $result = $executor->execute('{"age":0}');

        $this->assertTrue($result->isRuntimeError());
        $this->assertSame('Invalid age', $result->errorOutput);
    }

    #[Test]
    public function testExecuteReturnsRuntimeErrorWithDefaultMessageOnExitCode2(): void
    {
        $executor = $this->createPartialMockExecutor(2, '', '');

        $result = $executor->execute('{"age":0}');

        $this->assertTrue($result->isRuntimeError());
        $this->assertSame('Invalid data (age or interests)', $result->errorOutput);
    }

    #[Test]
    public function testExecuteReturnsCrashOnOtherExitCode(): void
    {
        $executor = $this->createPartialMockExecutor(139, '', 'Segfault');

        $result = $executor->execute('test');

        $this->assertFalse($result->isSuccessful());
        $this->assertFalse($result->isValidationError());
        $this->assertSame(139, $result->exitCode);
        $this->assertSame('Segfault', $result->errorOutput);
    }

    private function createPartialMockExecutor(int $exitCode, string $output, string $errorOutput): AsmCoreExecutor
    {
        $processMock = $this->createMock(Process::class);
        $processMock->method('run')->willReturn(0);
        $processMock->method('getExitCode')->willReturn($exitCode);
        $processMock->method('getOutput')->willReturn($output);
        $processMock->method('getErrorOutput')->willReturn($errorOutput);

        $executor = $this->getMockBuilder(AsmCoreExecutor::class)
            ->setConstructorArgs(['fake/binary', '/tmp'])
            ->onlyMethods(['createProcess', 'isBinaryExecutable'])
            ->getMock();

        $executor->method('isBinaryExecutable')->willReturn(true);
        $executor->method('createProcess')->willReturn($processMock);

        return $executor;
    }
}
