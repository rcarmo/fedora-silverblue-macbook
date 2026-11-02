# ACPI notes (MacBookPro13,2, firmware 529.120.1.0.0)

The raw DSDT/SSDT dumps are not published (Apple firmware). To reproduce:
`sudo cat /sys/firmware/acpi/tables/DSDT > DSDT.dat; iasl -e SSDT*.dat -d DSDT.dat` (acpica-tools).

Facts used by the sleep fixes (`docs/SLEEP.md`):

| GPE | Handler | `_PRW` wake GPE of |
|---|---|---|
| 0x6F (GPIO community 2, pin GPD2 "LAN_WAKE#") | `_L6F` only clears GPD GPE status (PCR 0xAD, 0x140/0x160 bit 2) | **LID0**, EC, ADP1, BLTH |
| 0x6D | notifies PWRB, XHC1, HDEF | XHC1, HDEF, XHC2/XHC3 (Alpine Ridge) |
| 0x69 | notifies PEG0, RP01, RP05, ARPT; `TGPE()` (Thunderbolt) | PEG0, RP01/05/09/12, ARPT |
| 0x17 | (SPI keyboard/trackpad) | SPIT |
| 0x07 | EC runtime GPE (`_GPE` of PNP0C09) | — |

- Only LID0 of the 0x6F group is wake-enabled by default, so it arms GPE 0x6F for S3. With the lid already
  open at suspend, the line asserts immediately → 3 s "instant wake". Fix: disable LID0 wake when the lid
  is open at suspend (hook, Phase 1e).
- XHC1 (00:14.0) hosts the T1/iBridge; its S3 wake caused the first instant-wake variant.
- T1 host sleep/wake message: `\_SB.PCI0.XHC1.RHUB.ASOC.SOCW(0|1)` (module `macbook_t1_socw`).
