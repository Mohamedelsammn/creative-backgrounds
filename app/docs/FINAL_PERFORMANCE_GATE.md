# Final Performance Gate

## PERFORMANCE NOT READY FOR PRODUCTION

The static/build gate is green, but the physical-performance acceptance gate
is not complete. The exact blocker is that the connected OPPO CPH1823 rejects
the newly built profile APK with `INSTALL_FAILED_VERIFICATION_FAILURE` in both
streamed and non-streaming ADB install modes. Its ADB verifier is enabled, and
the installed version cannot be proven to match the optimized binary.

| Requirement | Result |
|---|---|
| Device used | OPPO CPH1823, serial `8DTKUKNN4H49VGMR` |
| Android / ABI | Android 10 / arm64-v8a |
| Refresh rate | 130 Hz reported peak |
| RAM | 3,744,408 kB (about 3.57 GiB) |
| `flutter analyze` | Passed — no issues |
| Full test aggregate | 392 passed, 0 failed, 0 skipped, 392 total |
| Release AAB | Passed — 67,777,886 bytes (64.6 MB) |
| Signing check | `jarsigner` exit 0, `jar verified`; self-signed upload cert warning |
| Initial Home jank | Not measured — current profile APK could not install |
| Fully loaded Home jank | Not measured — current profile APK could not install |
| Live-section / fast-fling jank | Not measured — current profile APK could not install |
| Max active feed decoders | Source/test-verified cap: 1; not runtime-measured on OPPO |
| Decoders during scroll / off-screen | Source/test-verified release; not runtime-measured on OPPO |
| Startup → first frame / Home | Not measured on current binary |
| Splash visual result | Not measured on current binary |
| App Open sequencing | Source-verified; not measured on current binary |
| CPU / memory / five-minute idle | Not measured on current binary |
| Banner behavior | Source-verified; not measured on current binary |
| Functional regression | Automated suite green; physical regression pass blocked |

## Next technical step

Enable/authorize ADB installation on the OPPO or install the generated profile
APK through the device-approved path, then verify the installed package and
run the requested `dumpsys gfxinfo`, decoder, startup, CPU, memory, banner,
and functional matrices. If fully-loaded Home jank remains high after that,
capture Perfetto before proposing another code change.
