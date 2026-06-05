# Service-specific configuration
SERVICE_NAME := thesa
APP_DIRS     := apps/default
HAS_UI       := true
UI_DIR       := ui

# Production OAuth2 values injected into the prod Flutter web build via
# --dart-define (see ui-build-prod). Default/dev/staging builds use the UI
# defaults in ui/lib/core/services/api_config.dart (the staging Thesa Studio
# client), so only the production build overrides them.
OAUTH2_CLIENT_ID_PROD ?= c2f4j7au6s7f91uqnomg
OAUTH2_ISSUER_URL_PROD ?= https://oauth2.stawi.org

# Bootstrap: download shared Makefile.common if missing or stale.
# Older cached copies lack Flutter auto-install support, which breaks parity
# with service-fintech's current workflow.
ifeq (,$(shell test -f .tmp/Makefile.common && grep -q 'FLUTTER_HOME' .tmp/Makefile.common && echo ok))
  $(shell mkdir -p .tmp && curl -sSfL https://raw.githubusercontent.com/antinvestor/common/main/Makefile.common -o .tmp/Makefile.common)
endif

include .tmp/Makefile.common

# Override prod build so this service can inject its production OAuth2 values.
.PHONY: ui-build-prod
ui-build-prod: ui-generate ## Build Flutter web (production -- prod OAuth2 values)
	cd $(UI_DIR) && "$(FLUTTER)" build web \
		--release \
		--base-href="/" \
		--tree-shake-icons \
		--dart-define=OAUTH2_CLIENT_ID=$(OAUTH2_CLIENT_ID_PROD) \
		--dart-define=OAUTH2_ISSUER_URL=$(OAUTH2_ISSUER_URL_PROD)
	@echo "Production build: $(UI_DIR)/build/web/"
