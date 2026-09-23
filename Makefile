.PHONY: test bench debug

check:
	# running luacheck...
	
	lx --lua-version 5.1 lint
	stylua --check .

	# running doc check...
	./scripts/check-docs

	# running workflow validation...
	./scripts/check-workflows

ifdef GITHUB_ACTIONS
build:
	echo "Skipping build in GitHub Actions"
else
build:
	echo "Building project..."
	lx --lua-version 5.1 build
endif

test: build
	# Single file: MiniTest.run() with a find_files override. Full suite:
	# 120s here is only a runner backstop.
	 bash scripts/test-with-timeout.sh $(if $(filter-out $@, $(MAKECMDGOALS)),10,120) $(filter-out $@, $(MAKECMDGOALS))

bench: build
	bash scripts/bench

docs-check:
	./scripts/check-docs

debug:
	bash scripts/debug

docs:
	./scripts/gendocs

%:
	@:
