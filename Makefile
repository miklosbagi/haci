SHELL=/bin/bash
TEST_DIR:=test
TEST_ENV:=stable
TEST_SITE:=haci-test-nginx
SUBJ:='/C=HU/ST=Budapest/O=HACItest/CN=haci-test-nginx'
COMPOSE_CMD=docker compose -f ${TEST_DIR}/docker-compose/docker-compose.yaml -f ${TEST_DIR}/docker-compose/docker-compose-env.yaml

include legacy.mk

export

.PHONY: all
all:
	@echo -ne "Usage: \t make run-tests: \t\tthis will launch default stable env\n\t make TEST_ENV=dev run-tests: \tthis will test against homassistant:dev\n"
	@echo -ne "\nTEST_ENV options are: \tstable, dev, beta, rc, latest\nFull list of options at: https://hub.docker.com/r/homeassistant/home-assistant/tags\n"
	@exit 0

.PHONY: run-tests
run-tests: clean
run-tests: lint
run-tests: start-test-env
run-tests: add-haci-config
run-tests: test-haci
run-tests: stop-test-env
run-tests: clean

.PHONY: lint
lint:
	@a=$(shellcheck --help) || { apt install -y shellcheck || exit 1; }
	@echo -ne " * Linting HACI... "
	@shellcheck -S  warning haci.sh && echo ✅ || echo ❌

.PHONY: start-test-env
start-test-env:
	@echo -ne " * Building home-assistant (${TEST_ENV})... "
	@mkdir -p ${TEST_DIR}/cert-gen
	@export COMPOSE_DOCKER_CLI_BUILD=0 && export TEST_ENV=${TEST_ENV} && \
		${COMPOSE_CMD} up --force-recreate --remove-orphans --detach || { \
				echo -ne "\n\n!!!\n!!! DOCKER-COMPOSE LOG\n!!!\n"; ${COMPOSE_CMD} logs | grep --color=always -i "(error\|err\|warn\|warning)"; \
				${COMPOSE_CMD} rm -v; echo ❌; exit 1; }

.PHONY: add-haci-config
add-haci-config:
	@echo -ne " * Adding HACI config: ${TEST_SITE_STRING}... "
	@echo -ne 'test_site="${TEST_SITE_STRING}"\ncertifi=yes\n' > haci.conf && echo ✅ || echo ❌

# haci test
.PHONY: test-haci
test-haci:
	${COMPOSE_CMD} logs
	@echo -ne " * Waiting for HASS to come alive... "
	@until curl --retry 5 --retry-all-errors --connect-timeout 1 -s http://localhost:8823/ -o /dev/null; do sleep 1; done && echo ✅ || echo ❌
	@echo -ne " * Testing HACI"
	@docker exec homeassistant-${TEST_ENV} /haci/haci.sh debug && echo "✅ PASSED" || { echo "❌ FAILED."; exit 1; }

.PHONY: stop-test-env
stop-test-env:
	@echo -ne " * Stopping test environment... "
	@${COMPOSE_CMD} down -v >/dev/null && echo ✅ || echo ❌

.PHONY: clean
clean:
	@echo -ne " * Cleaning temp data... "
	@rm -rf ${TEST_DIR}/cert-gen/* ${TEST_DIR}/config-nginx/certs/* haci.conf ca-certificates.crt.backup cacert.pem.backup > /dev/null 2>&1 || exit 0
	@echo ✅

