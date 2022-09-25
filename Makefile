SHELL = /bin/sh

minimal_init := './scripts/minimal_init.vim'

test: # Runs all tests
	nvim --headless --noplugin -u $(minimal_init) -c "PlenaryBustedDirectory ./lua/tests/ { minimal_init = $(minimal_init), timeout = 3000 }"

test.integration: # Runs integration test
	nvim --headless --noplugin -u $(minimal_init) -c "PlenaryBustedFile ./lua/tests/ws/integration_spec.lua"


.PHONY: test
.PHONY: test.integration
