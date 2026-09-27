# Development and install helpers for tree-sitter-gohtml.
# Requires: cc, and (for `make generate` / `make test`) tree-sitter CLI.

SHELL := /bin/bash
TS ?= tree-sitter
CC ?= cc
UNAME_S := $(shell uname -s)
PARSER_DIR := parser
PARSER := $(PARSER_DIR)/gohtml.so
SRC := src/parser.c

CFLAGS ?= -O2 -fPIC -I src
ifeq ($(UNAME_S),Darwin)
  LINKFLAGS ?= -dynamiclib -undefined dynamic_lookup
else
  LINKFLAGS ?= -shared
endif

PREFIX ?= $(HOME)/.local/share/nvim/site
INSTALL_PARSER := $(PREFIX)/parser/gohtml.so
INSTALL_QUERIES := $(PREFIX)/queries/gohtml
INSTALL_PLUGIN := $(PREFIX)/pack/gohtml/start/tree-sitter-gohtml

.PHONY: all generate compile test highlight-check install install-plugin uninstall clean help

help:
	@echo "Targets:"
	@echo "  generate          tree-sitter generate (writes src/parser.c)"
	@echo "  compile           compile parser/gohtml.so"
	@echo "  test              tree-sitter corpus + query sanity"
	@echo "  highlight-check   parse required examples and dump highlight captures"
	@echo "  install           copy parser + queries into PREFIX ($(PREFIX))"
	@echo "  install-plugin    copy the whole plugin into a native packpath"
	@echo "  uninstall         remove installed parser/queries/plugin"
	@echo "  clean             remove compiled parser objects"

all: compile test

generate: grammar.js
	$(TS) generate

$(SRC): grammar.js
	$(TS) generate

# 編譯出so檔案
$(PARSER): $(SRC)
	mkdir -p $(PARSER_DIR)
	$(CC) $(CFLAGS) $(LINKFLAGS) -o $@ $(SRC)

compile: $(PARSER)

test: $(SRC)
	$(TS) test
	$(TS) query queries/gohtml/highlights.scm examples/required.gohtml >/dev/null

highlight-check: $(SRC)
	@bash scripts/check_highlights.sh


# 放so到:    ~/.local/share/nvim/site/parser/
# 放*.scm到: ~/.local/share/nvim/site/queries/
install: compile
	mkdir -p "$(PREFIX)/parser" "$(INSTALL_QUERIES)"
	cp "$(PARSER)" "$(INSTALL_PARSER)"
	cp queries/gohtml/*.scm "$(INSTALL_QUERIES)/"
	@echo "Installed parser to $(INSTALL_PARSER)"
	@echo "Installed queries to $(INSTALL_QUERIES)"

install-plugin: compile
	mkdir -p "$(INSTALL_PLUGIN)"
	# Runtime files Neovim actually loads from the plugin root.
	mkdir -p "$(INSTALL_PLUGIN)/parser" "$(INSTALL_PLUGIN)/queries/gohtml" \
		"$(INSTALL_PLUGIN)/ftdetect" "$(INSTALL_PLUGIN)/ftplugin" \
		"$(INSTALL_PLUGIN)/plugin" "$(INSTALL_PLUGIN)/lua/gohtml"
	cp "$(PARSER)" "$(INSTALL_PLUGIN)/parser/gohtml.so"
	cp queries/gohtml/*.scm "$(INSTALL_PLUGIN)/queries/gohtml/"
	cp ftdetect/gohtml.lua "$(INSTALL_PLUGIN)/ftdetect/"
	cp ftplugin/gohtml.lua "$(INSTALL_PLUGIN)/ftplugin/"
	cp plugin/gohtml.lua "$(INSTALL_PLUGIN)/plugin/"
	cp lua/gohtml/*.lua "$(INSTALL_PLUGIN)/lua/gohtml/"
	@echo "Installed plugin pack to $(INSTALL_PLUGIN)"

uninstall:
	rm -f "$(INSTALL_PARSER)"
	rm -rf "$(INSTALL_QUERIES)" "$(INSTALL_PLUGIN)"

clean:
	rm -f "$(PARSER)" src/*.o
