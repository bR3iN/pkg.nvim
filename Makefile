SRC := $(wildcard fnl/**/*.fnl)
OUT := $(patsubst fnl/%.fnl,lua/%.lua,$(SRC))

build: $(OUT)

format: $(SRC)
	$(foreach src,$(SRC),fnlfmt --fix $(src);)

clean:
	rm $(OUT)

lua/%.lua: fnl/%.fnl
	fennel --compile $< > $@

.PHONY: build format clean
