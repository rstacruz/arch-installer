.PHONY: test

test:
	@for fn in test/*.sh; do echo "[$$fn]"; if ! ./$$fn; then exit 1; fi; done
	@echo "OK"

sandbox:
	nodemon -x bash sandbox.sh

watch:
	nodemon -x bash install.sh
