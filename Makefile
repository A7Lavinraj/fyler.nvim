.SILENT:
.PHONY: check format lint test doc

check: format lint test doc

format:
	@printf "\033[34mFYLER.NVIM - Code Formatting\033[0m\n"
	stylua . 2>/dev/null && printf "\033[32mCode formatted\033[0m\n\n" || (printf "\033[31mFormatting failed\033[0m\n\n"; exit 1)

lint:
	@printf "\033[34mFYLER.NVIM - Code Linting\033[0m\n"
	selene --config selene/config.toml lua 2>/dev/null && printf "\033[32mLinting passed\033[0m\n\n" || (printf "\033[31mLinting failed\033[0m\n\n"; exit 1)

test:
	@printf "\033[34mFYLER.NVIM - Running Tests\033[0m\n"
	nvim -l bin/run_tests.lua

doc:
	@printf "\n\033[34mFYLER.NVIM - Generating vim docs\033[0m\n"
	nvim -l bin/gen_vimdoc.lua
