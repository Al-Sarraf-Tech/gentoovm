# GentooVM — build and validation targets
# Usage: make help

SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help test lint validate qemu-test clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

test: ## Run unit tests (repo-level, no build env needed)
	@bash run-unit-tests.sh

lint: ## Run ShellCheck + shfmt on all scripts
	@find . -name '*.sh' -not -path './.git/*' -type f | xargs shellcheck --severity=warning
	@echo "ShellCheck: OK"
	@find . -name '*.sh' -not -path './.git/*' -type f | xargs shfmt -d && echo "shfmt: OK" || echo "shfmt: formatting diffs found"

validate: ## Run full pre-QEMU validation pipeline (stages 0-7, needs build env)
	@bash run-all-preqemu-validation.sh

qemu-test: ## Run QEMU boot tests (stages 8-9, needs ISO + KVM)
	@bash run-qemu-live-test.sh
	@bash run-qemu-installed-test.sh

clean: ## Remove generated CI artifacts
	@rm -f sbom.cdx.json test-results.txt
	@rm -rf release-assets/
	@echo "Cleaned generated artifacts"
