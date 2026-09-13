# Nimbreth

> Early release. If something breaks or confuses you, tell us on [Discord](https://discord.gg/gtjCSv4ZPf).

A private shared space for your files. Nimbreth syncs folders directly between your devices and the people you trust.

Your files go straight from your machine to theirs, encrypted on the way.

## Download

Grab the installer for your platform from the [latest release](../../releases/latest), or visit [nimbreth.com/download](https://nimbreth.com/download).

| Platform | Format | Status |
|----------|--------|--------|
| macOS (Apple Silicon) | DMG | Supported |
| Linux x64 | AppImage, deb | Supported |
| Linux arm64 | AppImage, deb | Supported |
| Windows | | Planned |

### Install

- **macOS:** open the DMG and drag Nimbreth to your Applications folder. The build is signed and notarized, so it launches with no security prompts.
- **Linux (AppImage):** make it executable and run it.
  ```bash
  chmod +x Nimbreth-*.AppImage
  ./Nimbreth-*.AppImage
  ```
- **Linux (deb):** install it with your package manager.
  ```bash
  sudo apt install ./nimbreth_*.deb
  ```

## Get started

1. Open Nimbreth and create a space. It picks a sensible home for your files, so there is nothing to configure.
2. Copy the share key.
3. Send the key to whoever is joining. They paste it, and the folder is theirs. That is the whole onboarding.

## Verify your download

Every asset ships with a `.sha256` checksum next to it. To check one:

```bash
sha256sum -c Nimbreth-*.sha256
```

## Updates

Nimbreth keeps itself current. On macOS and for Linux AppImage installs it downloads the new release in the background and asks you to restart when it is ready. If you installed the deb, Nimbreth shows a notification when a new release is out and links you to the download, since the installed file belongs to your package manager. Details at [nimbreth.com/docs/updating](https://nimbreth.com/docs/updating).

## Community

Questions, bug reports, and ideas are welcome on [Discord](https://discord.gg/gtjCSv4ZPf), or email us at hello@nimbreth.com.

Found a security issue? Please report it privately. See [SECURITY.md](SECURITY.md).

## About

Nimbreth is made by Nimbreth Labs. The app is free to use and closed source. Every build is signed and checksummed, so you can trust the binary you run. See [LICENSE](LICENSE).
