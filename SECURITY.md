# Security

CTT Pulse is designed so users can clone, build, and run the app without putting CTT credentials in the repository.

## Credential Handling

- CTT Personal Access Tokens are entered in the app UI.
- Tokens are stored in macOS Keychain by `KeychainTokenStore`.
- Tokens are loaded from Keychain only when making authenticated CTT API requests.
- Tokens are sent in the `Authorization` header as bearer tokens.
- Tokens are not stored in UserDefaults.
- Tokens are not written to source files.
- Tokens are not written to URLs.
- Tokens should not be logged.

CTT Pulse also supports a one-time local migration from legacy Telemetry Island Keychain service names into the current CTT Pulse Keychain service. The token remains inside Keychain during that migration. macOS may ask the user to allow Keychain access if the old item cannot be read silently.

## Files That Must Not Be Committed

Do not commit:

- `.env` or `.env.*`,
- local `.xcconfig` files containing secrets,
- Keychain exports,
- Apple signing certificates or private keys,
- provisioning profiles,
- generated app bundles,
- DMG/PKG/ZIP release artifacts unless intentionally publishing a release through GitHub Releases.

The repository `.gitignore` blocks common local credential and build artifact patterns.

## Safe Test Data

Tests use fake API clients and synthetic project/device/location data. They do not require a real PAT and should not contain real customer telemetry.

## Reporting Security Issues

For now, report security issues directly to the repository owner. Do not open a public issue containing real tokens, customer project IDs, precise sensitive wildlife coordinates, or private deployment data.
