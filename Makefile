.PHONY: test

PLENARY_PATH ?=

test:
	PLENARY_PATH=$(PLENARY_PATH) nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/restclient { minimal_init = 'tests/minimal_init.lua' }"
