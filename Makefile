# Developer tasks. Run `make help` for an overview.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# Validate only this blueprint folder, e.g. blueprints/automation/motion-light.
BLUEPRINT ?=
# Home Assistant versions to validate against: min, stable, beta, dev or X.Y.Z.
HA ?= min stable
# Options for `make create-blueprint`.
NAME ?=
DOMAIN ?= automation
MIN_VERSION ?=
# Options for the pull request targets, e.g. BRANCH=scripts/github-pr ARGS=--draft.
BRANCH ?=
ARGS ?=

.PHONY: help lint test-blueprints create-blueprint create-branch open-pr delete-branch cleanup-repo

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "} {printf "  %-17s %s\n", $$1, $$2}'

lint: ## Lint all YAML files
	yamllint .

test-blueprints: ## Validate blueprints [BLUEPRINT=<dir>] [HA="min stable"]
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

create-blueprint: ## Create a blueprint NAME=<name> [DOMAIN=] [MIN_VERSION=]
	@if [[ -z "$(NAME)" ]]; then echo "NAME is required." >&2; exit 1; fi
	@bash scripts/create-blueprint.sh -d "$(DOMAIN)" \
		$(if $(MIN_VERSION),-m "$(MIN_VERSION)") "$(NAME)"

create-branch: ## Create a branch from main [BRANCH=<scope>/<topic>]
	@bash scripts/github-pr.sh create-branch $(if $(BRANCH),"$(BRANCH)")

open-pr: ## Push a branch and open its pull request [BRANCH=] [ARGS=<gh args>]
	@bash scripts/github-pr.sh open-pr $(if $(BRANCH),"$(BRANCH)") -- $(ARGS)

delete-branch: ## Delete a branch once its pull request is closed [BRANCH=]
	@bash scripts/github-pr.sh delete-branch $(if $(BRANCH),"$(BRANCH)")

cleanup-repo: ## Delete leftover branches of closed pull requests
	@bash scripts/github-pr.sh cleanup-repo
