
all: repl test

%.zip: %.app %.app/main.lua
	cd $< && zip -r -9 ../$@ . && cd ..

%: %.zip
	make -C .. luvi
	cat ../luvi $< > $@
	chmod +x $@

clean:
	rm -f repl repl.zip test test.zip
