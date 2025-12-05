<?php
declare(strict_types=1);

namespace App\Controller\Api;

use App\Exception\GiftValidationException;
use App\Service\GiftAsmGenerator;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/gift-ideas', name: 'api_gift_ideas', methods: [Request::METHOD_GET])]
class GiftIdeasController extends AbstractController
{
    public function __construct(
        private readonly GiftAsmGenerator $giftAsmGenerator,
    ) {
    }

    public function __invoke(Request $request): JsonResponse
    {
        try {
            $result = $this->giftAsmGenerator->generateGifts($request->getContent());

            return new JsonResponse(
                $result,
                Response::HTTP_OK,
                [],
                true
            );
        } catch (GiftValidationException $e) {
            return $this->json(['error' => $e->getMessage()], Response::HTTP_BAD_REQUEST);
        }
    }
}
