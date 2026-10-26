GODOT ?= godot
export XDG_CONFIG_HOME := $(CURDIR)/.tools/config
export XDG_DATA_HOME := $(CURDIR)/.tools/data
export XDG_CACHE_HOME := $(CURDIR)/.tools/cache

.PHONY: run import test web serve
run:
	$(GODOT) --path .

import:
	mkdir -p .tools/config .tools/data .tools/cache
	$(GODOT) --headless --editor --path . --import --quit

test:
	timeout 30 $(GODOT) --headless --path . --script tests/test_simulation.gd

web:
	mkdir -p build/web
	touch build/.gdignore
	python3 tools/fetch_web_template.py
	$(MAKE) import
	$(GODOT) --headless --path . --export-release Web build/web/index.html

serve:
	python3 -m http.server 8000 --bind 0.0.0.0 --directory build/web
