APP := build/Sparkle Trail.app
ZIP := dist/SparkleTrail.zip

.PHONY: app universal dist test run install uninstall clean

app:
	./build.sh

test:
	./test.sh

universal:
	UNIVERSAL=1 ./build.sh

# The committed download. Regenerate and commit this whenever the app changes.
dist: universal
	mkdir -p dist
	rm -f "$(ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(ZIP)"
	@echo "packaged: $(ZIP) ($$(du -h "$(ZIP)" | cut -f1))"

run: app
	@pkill -x SparkleTrail || true
	open "$(APP)"

install: app
	@pkill -x SparkleTrail || true
	rm -rf "/Applications/Sparkle Trail.app"
	cp -R "$(APP)" /Applications/
	open "/Applications/Sparkle Trail.app"

uninstall:
	@pkill -x SparkleTrail || true
	rm -rf "/Applications/Sparkle Trail.app"

clean:
	rm -rf build dist .build .build-x86_64 .build-arm64
