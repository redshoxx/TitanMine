# AltStore installation

Titan Mine is configured as a standard iPhone application without special entitlements.

## GitHub Actions route (works from Windows)

Because an iOS `.ipa` needs Apple's iOS SDK to compile, the included workflow builds it on a macOS GitHub runner.

1. Create or choose a GitHub repository.
2. Upload/commit the entire TitanMine project.
3. Open the repository's **Actions** tab.
4. Select **Build AltStore IPA**.
5. Choose **Run workflow**.
6. When the job is green, download the `TitanMine-AltStore` artifact.
7. Extract it; inside is `TitanMine-AltStore.ipa`.
8. Install that IPA using AltStore Classic / AltServer.

No Apple signing certificate is embedded by this workflow; AltStore performs the re-signing during sideloading.
