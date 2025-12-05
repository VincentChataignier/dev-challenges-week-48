# Gift Ideas Generator - DevChallenges Week 48

API de génération d'idées cadeaux utilisant une IA auto-hébergée, avec un coeur en **assembleur x86_64**.

--> https://devchallenges.yoandev.co/

J’ai fait ce projet pour le fun, mais aussi pour tester jusqu’où je pouvais aller avec Claude Code dans un langage que je ne maîtrisais pas du tout.
L’idée : voir si l’IA pouvait générer un assembleur assez propre pour que je puisse itérer dessus, tout en apprenant le x86_64 en lui posant des questions sur son propre code.

Au final, c’était autant une expérimentation technique qu’une expérience d’apprentissage assistée par IA.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Client    │────▶│   Symfony    │────▶│  ASM Core   │
│  (Browser)  │◀────│   (PHP 8)    │◀────│  (x86_64)   │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                │ TCP Socket
                                                ▼
                                         ┌─────────────┐
                                         │   Ollama    │
                                         │ (qwen2.5:3b)│
                                         └─────────────┘
```

**Particularité** : Le coeur de l'application est écrit en assembleur x86_64 Linux :
- Parsing JSON manuel
- Communication TCP via syscalls (socket, connect, read, write)
- Requêtes HTTP construites manuellement

## Prérequis

- Docker & Docker Compose
- PHP
- Composer
- Symfony CLI

## Installation

```bash
# Cloner le repo
git clone https://github.com/YOUR_USERNAME/dev-challenges-week-48.git
cd dev-challenges-week-48

# Installer les dépendances PHP
composer install

# Lancer Ollama et télécharger le modèle
docker compose up -d ollama
docker exec ollama ollama pull qwen2.5:3b

# Builder le coeur ASM
make build-asm

# Lancer le serveur Symfony
symfony serve
```

## Utilisation

### Via query parameters (navigateur)

```
http://localhost:8000/api/gift-ideas?age=25&interests=jeux%20video
```

### Via JSON body (curl)

```bash
curl -X GET http://localhost:8000/api/gift-ideas \
  -H "Content-Type: application/json" \
  -d '{"age": 25, "interests": "jeux video"}'
```

### Réponse

```json
{
  "ideas": [
    "Console de jeux",
    "Casque gaming",
    "Carte cadeau Steam",
    "Manette sans fil",
    "Chaise gamer"
  ]
}
```

## Tests

```bash
# Tous les tests
make tests

# Tests unitaires uniquement
make unit-tests

# Tests fonctionnels uniquement
make functional-tests
```

## Structure du projet

```
.
├── asm/                    # Coeur ASM
│   ├── gift_core.asm       # Point d'entrée principal
│   ├── constants.inc       # Constantes système
│   ├── data.inc            # Données et buffers
│   ├── string_utils.inc    # Fonctions de chaînes
│   ├── json_parser.inc     # Parsing JSON
│   ├── Dockerfile
│   └── run                 # Script d'exécution
├── src/
│   ├── Controller/Api/     # Endpoints Symfony
│   └── Service/            # Services métier
├── tests/                  # Tests PHPUnit
├── docker-compose.yml      # Ollama service
```
