<?php
declare(strict_types=1);

namespace App\Tests\Controller\Api;

use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

#[Group('functional')]
class GiftIdeasApiTest extends WebTestCase
{
    #[Test]
    public function testGetGiftIdeasWithValidDataReturnsIdeas(): void
    {
        $response = $this->request(
            Request::METHOD_GET,
            json_encode([
                'age'       => 33,
                'interests' => 'jeux video, high-tech',
            ])
        );

        $this->assertSame(200, $response->getStatusCode());
        $this->assertJson($response->getContent());

        $data = json_decode($response->getContent(), true);

        $this->assertArrayHasKey('ideas', $data);
        $this->assertIsArray($data['ideas']);
        $this->assertNotEmpty($data['ideas']);
    }

    #[Test]
    public function testGetGiftIdeasWithoutAgeReturns400(): void
    {
        $response = $this->request(
            Request::METHOD_GET,
            json_encode([
                'interests' => 'jeux video, high-tech',
            ])
        );

        $this->assertSame(400, $response->getStatusCode());
        $this->assertJson($response->getContent());

        $data = json_decode($response->getContent(), true);
        $this->assertArrayHasKey('error', $data);
    }

    #[Test]
    public function testGetGiftIdeasWithoutInterestsReturns400(): void
    {
        $response = $this->request(
            Request::METHOD_GET,
            json_encode([
                'age' => 33,
            ])
        );

        $this->assertSame(400, $response->getStatusCode());
        $this->assertJson($response->getContent());

        $data = json_decode($response->getContent(), true);
        $this->assertArrayHasKey('error', $data);
    }

    #[Test]
    public function testGetGiftIdeasWithInvalidAgeReturns400(): void
    {
        $response = $this->request(
            Request::METHOD_GET,
            json_encode([
                'age'       => 0,
                'interests' => 'jeux video, high-tech',
            ])
        );

        $this->assertSame(400, $response->getStatusCode());
        $this->assertJson($response->getContent());

        $data = json_decode($response->getContent(), true);
        $this->assertArrayHasKey('error', $data);
    }

    #[Test]
    public function testGetGiftIdeasWithEmptyInterestsReturns400(): void
    {
        $response = $this->request(
            Request::METHOD_GET,
            json_encode([
                'age'       => 33,
                'interests' => '',
            ])
        );

        $this->assertSame(400, $response->getStatusCode());
        $this->assertJson($response->getContent());

        $data = json_decode($response->getContent(), true);
        $this->assertArrayHasKey('error', $data);
    }

    #[Test]
    public function testGetGiftIdeasWithInvalidJsonReturns400(): void
    {
        $response = $this->request(Request::METHOD_GET, 'invalid json {');

        $this->assertSame(400, $response->getStatusCode());
    }

    #[Test]
    public function testPostGiftIdeasReturns405(): void
    {
        $response = $this->request(Request::METHOD_POST);

        $this->assertSame(405, $response->getStatusCode());
    }

    protected function request(string $method, ?string $content = null) : Response
    {
        $client = static::createClient();
        $client->request(
            $method,
            '/api/gift-ideas',
            [],
            [],
            ['CONTENT_TYPE' => 'application/json'],
            $content
        );

        return $client->getResponse();
    }
}
