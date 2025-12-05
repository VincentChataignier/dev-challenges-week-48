<?php
declare(strict_types=1);

namespace App\Controller\Api;

use App\Exception\GiftValidationException;
use App\Service\GiftGenerator;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/gift-ideas', name: 'api_gift_ideas', methods: [Request::METHOD_GET])]
class GiftIdeasController extends AbstractController
{
    public function __construct(
        private readonly GiftGenerator $giftGenerator,
    ) {
    }

    public function __invoke(Request $request): JsonResponse
    {
        try {
            $jsonPayload = $this->buildJsonPayload($request);
            $result = $this->giftGenerator->generateGifts($jsonPayload);

            return new JsonResponse(
                $result,
                Response::HTTP_OK,
                [],
                true
            );
        } catch (\RuntimeException $e) {
            return $this->json(['error' => 'Internal server error'], Response::HTTP_INTERNAL_SERVER_ERROR);
        } catch (GiftValidationException $e) {
            return $this->json(['error' => $e->getMessage()], Response::HTTP_BAD_REQUEST);
        }
    }

    private function buildJsonPayload(Request $request): string
    {
        // Si query params présents, les utiliser
        $age       = $request->query->get('age');
        $interests = $request->query->get('interests');

        if ($age !== null && $interests !== null) {
            return json_encode([
                'age'       => (int) $age,
                'interests' => $interests,
            ], JSON_THROW_ON_ERROR);
        }

        // Sinon, utiliser le body JSON
        return $request->getContent();
    }
}
