.PHONY: build-asm tests unit-tests functional-tests

build-asm:
	docker build --platform linux/amd64 -t gift-asm asm/

tests: build-asm
	php bin/phpunit --testdox

unit-tests:
	php bin/phpunit --group unit --testdox

functional-tests: build-asm
	php bin/phpunit --group functional --testdox