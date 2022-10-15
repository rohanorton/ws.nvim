SHELL = /bin/sh

minimal_init := './scripts/minimal_init.vim'
run_test = nvim --headless --noplugin -u $(minimal_init) -c "PlenaryBustedFile $(1)"

test: # Runs all tests
	nvim --headless --noplugin -u $(minimal_init) -c "PlenaryBustedDirectory ./lua/tests/ { minimal_init = $(minimal_init), timeout = 3000 }"
.PHONY: test

test.e2e: # Runs e2e test
	$(call run_test, lua/tests/ws/e2e_spec.lua)
.PHONY: test.e2e

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
	$(call run_test, lua/tests/ws/opening_handshake_sender_spec.lua)
.PHONY: test.handshake

test.handshake_receiver: # Runs handshake receiver test
	$(call run_test, lua/tests/ws/opening_handshake_receiver_spec.lua)
.PHONY: test.handshake_receiver

test.sha1: # Runs sha1 test
	$(call run_test, lua/tests/ws/sha1_spec.lua)
.PHONY: test.sha1

test.bytes: # Runs bytes test
	$(call run_test, lua/tests/ws/bytes_spec.lua)
.PHONY: test.bytes

test.buffer: # Runs buffer test
	$(call run_test, lua/tests/ws/buffer_spec.lua)
.PHONY: test.buffer

test.receiver: # Runs receiver test
	$(call run_test, lua/tests/ws/receiver_spec.lua)
.PHONY: test.receiver

test.sender: # Runs sender test
	$(call run_test, lua/tests/ws/sender_spec.lua)
.PHONY: test.sender

test.frame_builder: # Runs frame builder test
	$(call run_test, lua/tests/ws/frame_builder_spec.lua)
.PHONY: test.frame_builder
