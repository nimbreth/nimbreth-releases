# Security Policy

Nimbreth is a private, peer-to-peer file sync app. We take the safety of your files
and your machine seriously. This document explains how to report a security
problem and what you can expect from us.

## Reporting a vulnerability

Please report security vulnerabilities privately. Do not open a public issue, a
discussion, or a Discord message for a suspected vulnerability, because that
exposes other users before a fix is out.

Email **hello@nimbreth.com** with:

- a description of the issue and why you believe it is a security problem,
- the steps to reproduce it, or a proof of concept,
- the affected platform, app version, and install format (DMG, AppImage, deb, or
  terminal),
- any logs or screenshots that help.

We will acknowledge your report within a few days, keep you updated as we
investigate, and let you know when a fix ships. We are grateful for coordinated
disclosure and will credit you in the release notes if you would like.

We do not run a paid bug bounty at this time.

## Supported versions

Security fixes go into the latest release. Because Nimbreth updates itself
(automatically on macOS, and with a notice on Linux), staying current is the way
to stay protected. Older builds do not receive back-ported fixes.

## Our security posture

- **Direct, encrypted transport.** Files move directly between peers over
  encrypted connections. There is no Nimbreth server in the middle, and no cloud that
  holds your content.
- **Signed and verifiable downloads.** macOS builds are signed and notarized by
  Nimbreth Labs. Every asset ships with a `.sha256` checksum so you can verify what
  you downloaded.
- **Minimal network chatter.** The app does not phone home for analytics. It
  contacts the update service only to check for new versions.
- **Closed source, published safely.** Source is not distributed, but every
  release is signed and checksummed so you can trust the binary you run.

## Scope

This policy covers the Nimbreth desktop app and the terminal tools distributed in
this repository. If a vulnerability in a third-party dependency affects Nimbreth,
please report it to us as well, and we will coordinate upstream where needed.
