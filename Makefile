.SILENT:

.PHONY: init
init: format lint test doc

.PHONY: deps
deps:
	@if [ ! -d .temp/deps/mini.test ]; then \
		echo "Cloning mini.test"; \
		git clone --depth=1 --single-branch https://github.com/nvim-mini/mini.test .temp/deps/mini.test; \
	fi
	@if [ ! -d .temp/deps/mini.icons ]; then \
		echo "Cloning mini.icons"; \
		git clone --depth=1 --single-branch https://github.com/nvim-mini/mini.icons .temp/deps/mini.icons; \
	fi
	@if [ ! -d .temp/deps/mini.doc ]; then \
		echo "Cloning mini.doc"; \
		git clone --depth=1 --single-branch https://github.com/nvim-mini/mini.doc .temp/deps/mini.doc; \
	fi

.PHONY: format
format:
	@printf "\033[34mFYLER.NVIM - Code Formatting\033[0m\n"
	@stylua . 2>/dev/null && printf "\033[32mCode formatted\033[0m\n\n" || (printf "\033[31mFormatting failed\033[0m\n\n"; exit 1)

.PHONY: lint
lint:
	@printf "\033[34mFYLER.NVIM - Code Linting\033[0m\n"
	@selene --config selene/config.toml lua 2>/dev/null && printf "\033[32mLinting passed\033[0m\n\n" || (printf "\033[31mLinting failed\033[0m\n\n"; exit 1)

.PHONY: test
test: deps
	@printf "\033[34mFYLER.NVIM - Running Tests\033[0m\n"
	@nvim --headless --clean --noplugin -u tests/minimal_init.lua -l bin/run_tests.lua

.PHONY: test_debug
test_debug:
	@make test DEBUG=1

.PHONY: doc
doc: deps
	@printf "\n\033[34mFYLER.NVIM - Generating vim docs\033[0m\n"
	@nvim --headless --clean --noplugin -l bin/gen_vimdoc.lua
