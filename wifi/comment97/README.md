# Comment 97 Wi-Fi candidate — downloaded, NOT installed

Fetched directly from kernel bug 193121 on 2026-11-01 at the user's request.

Comment 97 provides **a one-line correction to attachment 290569**, not a new firmware binary or a separate complete attachment. This bundle preserves the original and derives the corrected NVRAM reproducibly.

## Files
- `comment97.txt` / `comment97.json`: the fetched report and recipe.
- `attachment-290569.original.txt`: untouched upstream attachment; byte-identical to the previously reviewed download.
- `brcmfmac43602-pcie.comment97.txt`: attachment with **only `swctrlmap_2g` corrected**.
- `comment97.patch`: exact one-line diff.
- `PROVENANCE.json`: source URLs, timestamp, hashes and comparison results.
- `SHA256SUMS`: bundle integrity checks.

Source: https://bugzilla.kernel.org/show_bug.cgi?id=193121#c97
Base: https://bugzilla.kernel.org/attachment.cgi?id=290569

The change is:
```
swctrlmap_2g=0x02020202,0x01010101,0x02020202,0x00000000,0x000000ff
```
`boardflags3=0xC0000303`, the 5-GHz map, all remaining RF/calibration tables and country/revision fields are unchanged. This is a community experimental configuration, not a verified board calibration dump from this machine.

## Identity and integration — not ready to install as-is

The derived file deliberately retains the attachment's **Broadcom fallback MAC**, not another person's address or a recovered real Apple permanent MAC. It is **unpersonalized research input**. No MAC selection or NetworkManager setting changed.

Compared with `../wifi-trial/brcmfmac43602-pcie.txt`, **all RF/configuration keys are identical**; only `macaddr` differs because the historical trial used a locally administered identity. Thus comment 97 is the same RF candidate already attempted, not a different fix.

That old trial's initramfs lacked the dynamically loaded stock `brcmfmac-wcc` helper, with matching loader/attach failure. See **`../wifi-research-20261101/BUG193121-REVIEW.md`**. Any later trial must correct and independently verify that integration, review identity/calibration/recovery and obtain separate approval with alternate networking. Do not reuse the retained failed image or run the old installer unchanged. No additional binary, CLM blob or alternative Wi-Fi driver was downloaded or needed by the comment 97 recipe.

**Nothing installed, staged, reloaded or rebooted.** The current NVMe suspend trial remains separate. User selected **deep** for the next attended sleep comparison; the existing s2idle override has not yet been changed and no suspend test has started.
