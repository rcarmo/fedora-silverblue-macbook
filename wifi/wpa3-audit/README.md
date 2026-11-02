# Post-trial Wi-Fi / WPA3 read-only audit — 2026-11-01

Boot <uuid>, kernel 7.2.13-200.fc44.x86_64. Corrected trial 39e497f.0 is booted/first; rpm-ostree idle, no staged deployment. Recovery c4ebdd8 plus driver baseline and two stock deployments remain pinned. Old failed b0a3115 is no longer in reported status: do not reuse historical boot indexes.

User reports vastly improved Wi-Fi. brcmfmac-wcc is loaded, firmware attaches successfully, version 7.35.177.61 (build November 2015). PHY now exposes 2.4 and 5 GHz, and cached scan sees multiple 5 GHz APs. Current usable connection is on 2437 MHz, not yet a successful 5 GHz association.

The 10:00 connection attempt to `<home-5g>` used SAE/FT-SAE and required PMF (ieee80211w=2). Supplicant reports `WPA: Failed to select authenticated key management type` then `Failed to set WPA key management and encryption suites`. NM later reports misleading ssid-not-found timeout. Cached AP list shows that SSID as WPA3-only at 5200 and 5260 MHz, with strong signal at 5200. Profile key-mgmt is sae. No evidence here of a wrong password.

Live `iw phy` advertises neither SAE authentication nor SAE offload; it advertises only PSK/802.1X handshake offload. This strongly indicates the current Broadcom firmware/driver combination does not expose WPA3-Personal support. Modern brcmfmac code alone does not guarantee support: upstream v7.2 cfg80211.c advertises SAE only when firmware features SAE/SAE_EXT are detected; feature.c probes `sae ` and `sae_ext`. Sources saved locally as reference, not proof of exact Fedora patch parity. Supplicant D-Bus capabilities query was denied; no administrative escalation requested.

NVRAM correction restored RF/band availability, not cryptographic firmware functionality. No safe compatible WPA3 firmware replacement established. Do not force capability bits, replace unrelated firmware, disable PMF for SAE, or repeatedly retry passwords.

Options: if acceptable to router owner, use WPA2-Personal AES/CCMP on a separate 5 GHz SSID, or WPA2/WPA3 transition mode with this client using WPA2. This lowers security relative to WPA3-only; do not enable WPA1/TKIP. If WPA3-only is required, use a Linux-compatible WPA3-capable external adapter. Router changes and connection tests require separate user agreement; none performed here.

Custom audio codec remains selected; apple_ibridge/apple_touchbar loaded and skip_acpi_power=1 retained. No physical hardware retests. Early-initramfs-only firmware reset/resume integration and broken suspend remain unresolved. No profiles/system files changed, admin prompts, live reloads, disconnections, suspend, or reboot. Evidence under this directory; logs contain local network identifiers but no requested secret output.
