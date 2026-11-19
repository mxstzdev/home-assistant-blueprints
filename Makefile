# Developer tasks. Run `make help` for an overview.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# Validate only this blueprint folder, e.g. blueprints/automation/motion-light.
BLUEPRINT ?=
# Home Assistant versions to validate against: min, stable, beta, dev or X.Y.Z.
HA ?= min stable
# Options for `make create`.
NAME ?=
DOMAIN ?= automation
MIN_VERSION ?=

.PHONY: help lint test create

help: ## Show this help
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "} {printf "  %-8s %s\n", $$1, $$2}'

lint: ## Lint all YAML files
	yamllint .

test: ## Validate blueprints [BLUEPRINT=<dir>] [HA="min stable"]
	@blueprints="$(BLUEPRINT)"; \
	if [[ -z "$${blueprints}" ]]; then \
		blueprints="$$(bash scripts/list-blueprints.sh | jq -r '.[]')"; \
	fi; \
	if [[ -z "$${blueprints}" ]]; then echo "No blueprints found."; fi; \
	for blueprint in $${blueprints}; do \
		for ha in $(HA); do \
			bash scripts/validate-blueprint.sh "$${blueprint}" "$${ha}"; \
		done; \
	done

create: ## Create a blueprint NAME=<name> [DOMAIN=] [MIN_VERSION=]
	@if [[ -z "$(NAME)" ]]; then echo "NAME is required." >&2; exit 1; fi
	@bash scripts/create-blueprint.sh -d "$(DOMAIN)" \
		$(if $(MIN_VERSION),-m "$(MIN_VERSION)") "$(NAME)"
