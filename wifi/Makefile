.DEFAULT_GOAL := help
# Override with ADMIN=pkexec for graphical authentication, or ADMIN= when root.
ADMIN ?= sudo
PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
RECOVERY := $(PROJECT_DIR)/recover-wifi.sh

.PHONY: help check recovery-plan arm-wifi restore restore-wifi status
help:
	@printf '%s\n' \
	  'make recovery-plan  Show recovery scope; no changes' \
	  'make check          Check script syntax and read-only plan' \
	  'make arm-wifi       Record empty baseline BEFORE a future Wi-Fi trial' \
	  'make restore        Remove trial override; stage recovery (no reboot)' \
	  'make status         Show OSTree deployment status' \
	  'Use ADMIN=pkexec for graphical approval, or ADMIN= when already root.'

check:
	/usr/bin/bash -n "$(RECOVERY)"
	/usr/bin/bash "$(RECOVERY)" --dry-run

recovery-plan:
	/usr/bin/bash "$(RECOVERY)" --dry-run

arm-wifi:
	$(ADMIN) /usr/bin/bash "$(RECOVERY)" --arm

restore: restore-wifi
restore-wifi:
	$(ADMIN) /usr/bin/bash "$(RECOVERY)" --recover

status:
	rpm-ostree status
