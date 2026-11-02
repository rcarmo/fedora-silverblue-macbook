#!/usr/bin/env bash
# Compile only. No host package installation, module loading, or modules_install.
set -euo pipefail
container=macbook-driver-build
kernel=7.2.13-200.fc44.x86_64
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
tar --strip-components=5 -xf build/inputs/linux-7.2.13.tar.xz -C "$work" linux-7.2.13/sound/hda/codecs/cirrus/cs8409.h
python3 audio/port-audio-header-7.2.py "$work/cs8409.h" audio/upstream/audio-src/patch_cs8409.h.diff
podman cp "$work/cs8409.h" "$container:/root/cs8409-7.2-adapted.h"
podman exec -i "$container" bash -se -- "$kernel" <<'BUILD'
set -euo pipefail
kernel=$1
cd /root/audio
# Refuse to overwrite an existing prepared tree; use a fresh copy to retry.
test ! -e build/hda
mkdir -p build
tar --strip-components=2 -xf /root/linux-7.2.13.tar.xz -C build linux-7.2.13/sound/hda
cp makefiles/Makefile build/hda/Makefile
cp makefiles/Makefile_common build/hda/common/Makefile
cp makefiles/Makefile_codecs build/hda/codecs/Makefile
cp makefiles/Makefile_cirrus build/hda/codecs/cirrus/Makefile
for header in cirrus_apple.h patch_cirrus_boot84.h patch_cirrus_new84.h patch_cirrus_real84.h patch_cirrus_hda_generic_copy.h patch_cirrus_real84_i2c.h; do
    cp "patch_cirrus/$header" build/hda/codecs/cirrus/
done
cd build/hda
patch --batch --fuzz=0 -p1 < /root/audio/patch_cs8409.c.diff
# Upstream header patch conflicts with Linux 7.2 context; retain all new stock fields.
cp /root/cs8409-7.2-adapted.h codecs/cirrus/cs8409.h
make -C "/usr/src/kernels/$kernel" M="$PWD" -j2 \
    CFLAGS_MODULE='-DAPPLE_PINSENSE_FIXUP -DAPPLE_CODECS -DCONFIG_SND_HDA_RECONFIG=1 -Wno-unused-variable -Wno-unused-function' modules
modinfo codecs/cirrus/snd-hda-codec-cs8409.ko
BUILD
