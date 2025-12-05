<?php
declare(strict_types=1);

namespace App\Tests\Service;

use App\Exception\GiftValidationException;
use App\Service\GiftAsmGenerator;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

#[Group('unit')]
class GiftAsmGeneratorTest extends TestCase
{
    #[Test]
    public function testGenerateGiftsReturnsJsonWithFiveIdeas(): void
    {
        $generator = new GiftAsmGenerator();
        $jsonPayload = json_encode([
            'age'       => 33,
            'interests' => 'jeux video, high-tech',
        ]);

        $result = $generator->generateGifts($jsonPayload);

        $this->assertJson($result);

        $data = json_decode($result, true);
        $this->assertArrayHasKey('ideas', $data);
        $this->assertIsArray($data['ideas']);
        $this->assertCount(5, $data['ideas']);
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnInvalidJson(): void
    {
        $generator = new GiftAsmGenerator();

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts('invalid json {');
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnMissingAge(): void
    {
        $generator = new GiftAsmGenerator();
        $jsonPayload = json_encode([
            'interests' => 'jeux video, high-tech',
        ]);

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts($jsonPayload);
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnInvalidAge(): void
    {
        $generator = new GiftAsmGenerator();
        $jsonPayload = json_encode([
            'age'       => 0,
            'interests' => 'jeux video, high-tech',
        ]);

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts($jsonPayload);
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnMissingInterests(): void
    {
        $generator = new GiftAsmGenerator();
        $jsonPayload = json_encode([
            'age' => 33,
        ]);

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts($jsonPayload);
    }

    #[Test]
    public function testGenerateGiftsThrowsExceptionOnEmptyInterests(): void
    {
        $generator = new GiftAsmGenerator();
        $jsonPayload = json_encode([
            'age'       => 33,
            'interests' => '',
        ]);

        $this->expectException(GiftValidationException::class);

        $generator->generateGifts($jsonPayload);
    }
}
