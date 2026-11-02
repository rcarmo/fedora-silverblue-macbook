# Local Apple CS8409 akmod

Apple source: davidjo/snd_hda_macbookpro commit 89b22ff90b86468b186706861dd18663562defa7, GPL-2.0.
Base HDA source: upstream Linux 7.2.13 sound/hda, from kernel.org HTTPS archive, SHA256 08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c. Individual source files retain their SPDX licenses. This is not the complete Fedora source RPM.

Prepared offline source includes upstream cs8409.c patch, six Apple headers, upstream external-module Makefiles, and explicit cs8409.h port: omit comment-only enum hunk, insert Apple structures/fields while preserving new RECEIVER names, speaker_muted and component binding. No source is fetched by RPM scriptlets or akmods rebuilds.

Builds limited to kernel 7.2.*. On a newer major/minor kernel, akmods should fail the deployment composition rather than silently reuse incompatible source. Refresh and test this local source package before that upgrade. Compilation on a newer 7.2 patch release is not a hardware safety guarantee either.

Stock Fedora codec is retained under kernel/. Local codec under extra/macbook-cs8409/ is selected with a depmod override and included in regenerated initramfs.

Headphone noise and sleep/power behavior are not fully verified. Never play to hw:0,0 or plughw:0,0: there is no direct hardware volume control. Use muted then low-volume PipeWire playback. Do not assume microphone or suspend works from speaker success.

Recovery: boot pinned original deployment. To remove, uninstall both akmod-macbook-cs8409 and macbook-cs8409-kmod-common with rpm-ostree, allow deployment composition to complete, then reboot when ready. Do not overwrite/remove Fedora's stock module by hand.

## 0.1.20261101 local changes (patch ../../0002-cs8409-apple-probe-op-and-resume-reinit.patch)
- cs_8409_apple_ops gains .probe = cs8409_probe: cs8409_apple() replaces driver->ops with this table, so any
  second probe (controller unbind/bind) WARNed at bind.c:115 and failed -EINVAL (seen 2026-11-01 13:47).
- Resume after system sleep re-runs cs_8409_boot_setup() once (PM notifier flag; works whether the codec is
  system-resumed or runtime-resumed later) and resets play/capture init. Module param resume_reinit=0 disables.
  Reason: speakers silent after S3 (old resume = snd_hda_codec_init + regmap sync only). Compile-tested only.
