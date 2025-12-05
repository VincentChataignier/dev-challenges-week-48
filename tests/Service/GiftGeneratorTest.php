<?php
declare(strict_types=1);

namespace App\Tests\Service;

use App\Exception\GiftValidationException;
use App\Service\Core\CoreExecutorInterface;
use App\Service\GiftGenerator;
use App\ValueObject\CoreResult;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;
use RuntimeException;

#[Group('unit')]
class GiftGeneratorTest extends TestCase
{
    #[Test]
    public function testGenerateGiftsReturnsJsonWithFiveIdeas(): void
    {
        $expectedOutput = '{"ideas":["Cadeau 1","Cadeau 2","Cadeau 3","Cadeau 4","Cadeau 5"]}';

        $mockExecutor = $this->createMock(CoreExecutorInterface::class);
        $mockExecutor->method('execute')->willReturn(CoreResult::success($expectedOutput));

        $generator = new GiftGenerator($mockExecutor);
        $result = $generator->generateGifts('{"age":33,"interests":"jeux video"}');

        $this->assertJson($result);

        $data = json_decode($result, true);
        $this->assertArrayHasKey('ideas', $data);
        $this->assertIsArray($data['ideas']);
        $this->assertCount(5, $data['ideas']);
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnInvalidJson(): void
    {
        $mockExecutor = $this->createMock(CoreExecutorInterface::class);
        $mockExecutor->method('execute')->willReturn(CoreResult::inputError('Invalid JSON input'));

        $generator = new GiftGenerator($mockExecutor);

        $this->expectException(GiftValidationException::class);
        $this->expectExceptionMessage('Invalid JSON input');

        $generator->generateGifts('invalid json {');
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnMissingAge(): void
    {
        $mockExecutor = $this->createMock(CoreExecutorInterface::class);
        $mockExecutor->method('execute')->willReturn(CoreResult::runtimeError('Invalid data (age or interests)'));

        $generator = new GiftGenerator($mockExecutor);

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts('{"interests":"jeux video"}');
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnInvalidAge(): void
    {
        $mockExecutor = $this->createMock(CoreExecutorInterface::class);
        $mockExecutor->method('execute')->willReturn(CoreResult::runtimeError('Invalid data (age or interests)'));

        $generator = new GiftGenerator($mockExecutor);

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts('{"age":0,"interests":"jeux video"}');
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnMissingInterests(): void
    {
        $mockExecutor = $this->createMock(CoreExecutorInterface::class);
        $mockExecutor->method('execute')->willReturn(CoreResult::runtimeError('Invalid data (age or interests)'));

        $generator = new GiftGenerator($mockExecutor);

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts('{"age":33}');
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnEmptyInterests(): void
    {
        $mockExecutor = $this->createMock(CoreExecutorInterface::class);
        $mockExecutor->method('execute')->willReturn(CoreResult::runtimeError('Invalid data (age or interests)'));

        $generator = new GiftGenerator($mockExecutor);

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts('{"age":33,"interests":""}');
    }

    #[Test]
    public function testGenerateGiftsThrowsRuntimeExceptionOnCrash(): void
    {
        $mockExecutor = $this->createMock(CoreExecutorInterface::class);
        $mockExecutor->method('execute')->willReturn(CoreResult::crash(139, 'Segmentation fault'));

        $generator = new GiftGenerator($mockExecutor);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Core crashed with exit code 139');

        $generator->generateGifts('{"age":33,"interests":"test"}');
    }
}