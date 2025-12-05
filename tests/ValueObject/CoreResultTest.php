<?php
declare(strict_types=1);

namespace App\Tests\ValueObject;

use App\ValueObject\CoreResult;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

#[Group('unit')]
class CoreResultTest extends TestCase
{
    #[Test]
    public function testSuccessFactoryMethod(): void
    {
        $result = CoreResult::success('output content');

        $this->assertSame(CoreResult::EXIT_SUCCESS, $result->exitCode);
        $this->assertSame('output content', $result->output);
        $this->assertSame('', $result->errorOutput);

        $this->assertTrue($result->isSuccessful());
        $this->assertFalse($result->isInputError());
        $this->assertFalse($result->isRuntimeError());
        $this->assertFalse($result->isValidationError());
    }

    #[Test]
    public function testInputErrorFactoryMethod(): void
    {
        $result = CoreResult::inputError('Custom error message');

        $this->assertSame(CoreResult::EXIT_INPUT_ERROR, $result->exitCode);
        $this->assertSame('', $result->output);
        $this->assertSame('Custom error message', $result->errorOutput);

        $this->assertFalse($result->isSuccessful());
        $this->assertTrue($result->isInputError());
        $this->assertFalse($result->isRuntimeError());
        $this->assertTrue($result->isValidationError());
    }

    #[Test]
    public function testInputErrorFactoryMethodWithDefaultMessage(): void
    {
        $result = CoreResult::inputError();

        $this->assertSame(CoreResult::EXIT_INPUT_ERROR, $result->exitCode);
        $this->assertSame('Invalid JSON input', $result->errorOutput);
    }

    #[Test]
    public function testRuntimeErrorFactoryMethod(): void
    {
        $result = CoreResult::runtimeError('Custom runtime error');

        $this->assertSame(CoreResult::EXIT_RUNTIME_ERROR, $result->exitCode);
        $this->assertSame('', $result->output);
        $this->assertSame('Custom runtime error', $result->errorOutput);
    }

    #[Test]
    public function testRuntimeErrorFactoryMethodWithDefaultMessage(): void
    {
        $result = CoreResult::runtimeError();

        $this->assertSame(CoreResult::EXIT_RUNTIME_ERROR, $result->exitCode);
        $this->assertSame('Invalid data (age or interests)', $result->errorOutput);

        $this->assertFalse($result->isSuccessful());
        $this->assertFalse($result->isInputError());
        $this->assertTrue($result->isRuntimeError());
        $this->assertTrue($result->isValidationError());
    }

    #[Test]
    public function testCrashFactoryMethod(): void
    {
        $result = CoreResult::crash(139, 'Error');

        $this->assertSame(139, $result->exitCode);
        $this->assertSame('', $result->output);
        $this->assertSame('Error', $result->errorOutput);

        $this->assertFalse($result->isSuccessful());
        $this->assertFalse($result->isInputError());
        $this->assertFalse($result->isRuntimeError());
        $this->assertFalse($result->isValidationError());
    }
}
