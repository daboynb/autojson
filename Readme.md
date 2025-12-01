# If you wanna help me

<a href="https://www.buymeacoffee.com/daboynb" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

# Support group

https://t.me/playfixnext

# Current Fingerprint

## pif.json (STRONG integrity - requires Tricky Store + valid keybox)
<!-- PIF_JSON_START -->
```json
{
  "MANUFACTURER": "Google",
  "MODEL": "Pixel 9 Pro XL",
  "FINGERPRINT": "google/komodo_beta/komodo:16/BP31.250610.009/13905196:user/release-keys",
  "BRAND": "google",
  "PRODUCT": "komodo_beta",
  "DEVICE": "komodo",
  "RELEASE": "16",
  "ID": "BP31.250610.009",
  "INCREMENTAL": "13905196",
  "TYPE": "user",
  "TAGS": "release-keys",
  "SECURITY_PATCH": "2025-07-05",
  "DEVICE_INITIAL_SDK_INT": "32",
  "*.build.id": "BP31.250610.009",
  "*.security_patch": "2025-07-05",
  "*api_level": "32",
  "spoofBuild": "1",
  "spoofProps": "1",
  "spoofProvider": "0",
  "spoofSignature": "0",
  "spoofVendingFinger": "0",
  "spoofVendingSdk": "0",
  "verboseLogs": "0"
}
```
<!-- PIF_JSON_END -->

## Why only STRONG integrity?

This script generates **Pixel Beta fingerprints**. According to the official [PlayIntegrityFork documentation](https://github.com/osm0sis/PlayIntegrityFork):

> "Unfortunately Pixel Beta fingerprints have changed and **can no longer pass DEVICE integrity**, so can now **only be used for STRONG integrity setups**"

### Requirements

To use this fingerprint you need:
- [Tricky Store](https://github.com/5ec1cff/TrickyStore) 
- A valid **hardware keybox** (not the default AOSP one)

### Need DEVICE integrity instead?

You must find a **private fingerprint** from a non-Beta device. Pixel Beta fingerprints won't work for DEVICE integrity.

# Credits

This module was created using **Shell Scripts** that have been carefully adapted and customized from the original work of the **PlayIntegrityFork** module.

The original scripts were forked from the following repository:

- [osm0sis/PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork)
