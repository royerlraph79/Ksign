NAME := Ksign
PLATFORM := iphoneos
SCHEMES := Ksign

# ⬇️ Choix de config: Release (défaut) ou Debug
CONFIGURATION ?= Release

# ⬇️ DerivedData isolé par config pour éviter les collisions en parallèle
VARIANT_DIR := $(CONFIGURATION)
TMP := $(TMPDIR)/$(NAME)/$(VARIANT_DIR)
STAGE := $(TMP)/stage

# ⬇️ Le chemin produits suit la config (Release-iphoneos, Debug-iphoneos, etc.)
APP := $(TMP)/Build/Products/$(CONFIGURATION)-$(PLATFORM)

.PHONY: all clean $(SCHEMES)

all: $(SCHEMES)

clean:
	rm -rf "$(TMPDIR)/$(NAME)"
	rm -rf packages
	rm -rf Payload

deps:
	rm -rf deps || true
	mkdir -p deps
	curl -L -o deps/server.crt https://backloop.dev/backloop.dev-cert.crt || true
	curl -L -o deps/server.key1 https://backloop.dev/backloop.dev-key.part1.pem || true
	curl -L -o deps/server.key2 https://backloop.dev/backloop.dev-key.part2.pem || true
	cat deps/server.key1 deps/server.key2 > deps/server.pem 2>/dev/null || true
	rm -f deps/server.key1 deps/server.key2
	echo "*.backloop.dev" > deps/commonName.txt

$(SCHEMES): deps
	xcodebuild \
	    -project Ksign.xcodeproj \
	    -scheme "$@" \
	    -configuration "$(CONFIGURATION)" \
	    -arch arm64 \
	    -sdk "$(PLATFORM)" \
	    -derivedDataPath "$(TMP)" \
	    -skipPackagePluginValidation \
	    CODE_SIGNING_ALLOWED=NO \
	    ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO

	# Stage Payload
	rm -rf Payload
	rm -rf "$(STAGE)/"
	mkdir -p "$(STAGE)/Payload"

	mv "$(APP)/$@.app" "$(STAGE)/Payload/$@.app"

	# Permissions + ad-hoc sign
	chmod -R 0755 "$(STAGE)/Payload/$@.app"
	codesign --force --sign - --timestamp=none "$(STAGE)/Payload/$@.app"

	# Dépendances runtime
	cp deps/* "$(STAGE)/Payload/$@.app/" || true

	# Nettoyage signature embarquée
	rm -rf "$(STAGE)/Payload/$@.app/_CodeSignature"

	# Symlink Payload à la racine (comme avant)
	ln -sf "$(STAGE)/Payload" Payload

	# Zip → nom explicite par config
	mkdir -p packages
	zip -r9 "packages/$@-$(CONFIGURATION).ipa" Payload
