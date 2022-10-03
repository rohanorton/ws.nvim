SHELL = /bin/sh

minimal_init := './scripts/minimal_init.vim'
run_test = nvim --headless --noplugin -u $(minimal_init) -c "PlenaryBustedFile $(1)"

test: # Runs all tests
	nvim --headless --noplugin -u $(minimal_init) -c "PlenaryBustedDirectory ./lua/tests/ { minimal_init = $(minimal_init), timeout = 3000 }"
.PHONY: test

test.integration: # Runs integration test
	$(call run_test, lua/tests/ws/integration_spec.lua)
.PHONY: test.integration

test.websocket_client: # Runs websocket client test
	$(call run_test, lua/tests/ws/websocket_client_spec.lua)
.PHONY: test.websocket_client

test.url: # Runs url test
	$(call run_test, lua/tests/ws/url_spec.lua)
.PHONY: test.url

test.websocket_key: # Runs websocket key test
	$(call run_test, lua/tests/ws/websocket_key_spec.lua)
.PHONY: test.websocket_key

test.handshake: # Runs handshake test
	$(call run_test, lua/tests/ws/handshake_spec.lua)
.PHONY: test.handshake

test.sha1: # Runs sha1 test
	$(call run_test, lua/tests/ws/sha1_spec.lua)
.PHONY: test.sha1

test.receiver: # Runs receiver test
	$(call run_test, lua/tests/ws/receiver_spec.lua)
.PHONY: test.receiver
