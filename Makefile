profile ?= local
TO_INSTALL = bin conf profile core lib plugins
ORPROXY_HOME ?= /usr/local/orProxy
ORPROXY_BIN ?= /usr/local/bin/orProxy
ORPROXY_HOME_PATH = $(subst /,\\/,$(ORPROXY_HOME))
ORPROXY_ORI_CONFIG_PATH = $(ORPROXY_HOME)/profile/application-$(profile).json
ORPROXY_DIS_CONFIG_PATH = $(ORPROXY_HOME)/conf/orProxy.json


.PHONY: test clean install show

test:
	@echo "to be continued..."

install:
	@rm -rf $(ORPROXY_BIN)
	@rm -rf $(ORPROXY_HOME)/bin
	@rm -rf $(ORPROXY_HOME)/conf
	@rm -rf $(ORPROXY_HOME)/profile
	@rm -rf $(ORPROXY_HOME)/core
	@rm -rf $(ORPROXY_HOME)/lor
	@rm -rf $(ORPROXY_HOME)/lib
	@rm -rf $(ORPROXY_HOME)/plugins

	@if test ! -e "$(ORPROXY_HOME)"; \
	then \
		mkdir -p $(ORPROXY_HOME); \
	fi

	@for item in $(TO_INSTALL) ; do \
		cp -a $$item $(ORPROXY_HOME)/; \
	done;

	@if test -f "$(ORPROXY_ORI_CONFIG_PATH)"; \
    then \
        mv $(ORPROXY_ORI_CONFIG_PATH) $(ORPROXY_DIS_CONFIG_PATH); \
    fi

	@rm -r $(ORPROXY_HOME)/profile
	@echo "#!/usr/bin/env resty" >> $(ORPROXY_BIN)
	@echo "package.path=\"$(ORPROXY_HOME)/?.lua;$(ORPROXY_HOME)/lib/?.lua;;\" .. package.path" >> $(ORPROXY_BIN)
	@echo "package.cpath=\"$(ORPROXY_HOME)/lualib/?.so;;\" .. package.cpath">> $(ORPROXY_BIN)
	@echo "require(\"bin.main\")(arg)" >> $(ORPROXY_BIN)
	@chmod +x $(ORPROXY_BIN)
	@echo "Pulsar Openresty Proxy Server installed."
	$(ORPROXY_BIN) help

show:
	$(ORPROXY_BIN) help

clean:
	@rm -rf $(ORPROXY_BIN)
	@rm -rf $(ORPROXY_HOME)
