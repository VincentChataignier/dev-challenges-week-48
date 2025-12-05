.PHONY: tests functional-tests

tests:
	php bin/phpunit --testdox

functional-tests:
	php bin/phpunit --group functional --testdox