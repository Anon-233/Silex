# Silex Personal Installer and Offline Update Design

## Goal

Silex must produce a macOS installer that behaves like a conventionally
downloaded application while remaining suitable for personal, local use. The
installer must place one copy of Silex in `/Applications`, install the
restricted SMART service, and support later versions as in-place updates
without deleting user history or creating duplicate applications.

The application itself is offline. Obtaining source code from GitHub and
building a new installer happen outside Silex and are initiated manually by
the user.

## Distribution artifacts

The build produces:

- `Silex-<version>.pkg`, the actual system installer.
- `Silex-<version>.dmg`, a download-style disk image containing the package,
  concise installation instructions, and an uninstall utility.

The package is the authoritative installation artifact. The disk image is a
convenient container and does not use drag-and-drop application installation,
because Silex also requires a privileged SMART service.

Building these artifacts must not install them, register a daemon, request
administrator access, or otherwise modify the build Mac outside the repository
build directory.

## Installed layout

The package uses stable paths and identifiers:

- Application: `/Applications/Silex.app`
- Package identifier: `com.anon233.Silex.pkg`
- Application identifier: `com.anon233.Silex`
- Launch daemon label: `com.anon233.Silex.SMARTService`
- Launch daemon plist:
  `/Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist`
- Privileged helper:
  `/Library/PrivilegedHelperTools/SilexSMARTService.app/Contents/MacOS/SilexSMARTService`
- Bundled SMART executable:
  `/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl`

The installed root-owned service files use restrictive ownership and modes.
The daemon does not accept commands, paths, devices, or arguments from the
application. It runs only the fixed bundled `smartctl` executable with
`-j -x /dev/disk0`.

The daemon starts on demand through its Mach service and exits after 30 seconds
without an active request. It is not configured as an always-running process.

The package and `launchd` own the SMART daemon lifecycle. The application does
not register, unregister, install, replace, or update that daemon. It only
queries whether the service is available and sends the fixed XPC request.
`SMAppService.mainApp` remains limited to the separate, user-controlled
launch-at-login preference.

## Installation and authentication

The package installs the application and system service components, validates
their locations and modes, and loads or refreshes the daemon. The macOS
Installer controls administrator authentication. On a supported and configured
Mac, macOS may offer Touch ID; Silex cannot require Touch ID, and macOS may
require the administrator password after restart, after a security timeout, or
after failed biometric attempts.

The installation scripts must:

1. Stop the existing Silex daemon if it is loaded.
2. Replace application and service files atomically through Installer-managed
   payload installation.
3. Set root ownership and restrictive permissions on system service files.
4. Bootstrap the new daemon plist.
5. Leave application data in the user's home directory untouched.

Package scripts receive no user-supplied paths or shell fragments. All managed
paths are fixed constants under `/Applications` and `/Library`.

The application is not automatically launched by a package script. The user
launches it normally after installation. Its existing login-item preference
remains user-controlled.

## In-place updates

Every release uses the same application path, bundle identifier, package
identifier, daemon label, and service paths. The application short version and
build version must increase for a new release.

Installing a newer package:

- replaces `/Applications/Silex.app`;
- replaces and reloads the SMART service components;
- preserves `~/Library/Application Support/Silex/silex.sqlite3`;
- preserves preferences and alert rules;
- does not create names such as `Silex 2.app`;
- does not depend on the network or an update server.

The package must reject an accidental downgrade by default. A deliberate
downgrade remains possible only through an explicit developer or maintenance
workflow, not through normal double-click installation.

## Uninstallation

The disk image includes an uninstall utility that requests administrator
authorization, stops and removes the daemon, removes the privileged service
files, removes the package receipt, and removes `/Applications/Silex.app`.

User history and settings are preserved by default. The utility explains the
separate optional command for deleting
`~/Library/Application Support/Silex`. This prevents an uninstall or reinstall
from silently destroying health history.

## Offline and least-privilege policy

Silex contains no application networking feature. It must not include:

- update checks or download logic;
- telemetry, analytics upload, or crash upload;
- GitHub API access;
- `URLSession`, Network.framework connections, WebViews, or embedded remote
  content;
- network client or server entitlements.

The application must not request Full Disk Access, Accessibility, Location,
Camera, Microphone, Contacts, Calendar, Bluetooth, Screen Recording, or other
unrelated privacy permissions.

The expected permissions and system approvals are limited to:

- administrator authorization during package installation, update, or
  privileged uninstall;
- notification authorization only when alerts need to notify the user;
- optional login-item registration controlled by the user;
- privileged access by the fixed SMART daemon to read `/dev/disk0`.

macOS desktop applications are not universally isolated from networking merely
because they omit a network entitlement. Therefore the offline guarantee is
enforced by source and binary checks rather than described as an operating
system network sandbox.

## Signing levels

The same packaging flow supports two levels:

### Personal local build

- Application and nested executables use ad-hoc signing.
- The package is unsigned or locally signed when a suitable local installer
  identity is supplied.
- The disk image is generated locally.
- Gatekeeper may require the user to explicitly approve the package or app.

This level requires no paid Apple Developer membership and is the initial
deliverable.

### Developer ID distribution

When the builder supplies Developer ID Application and Developer ID Installer
identities plus notarization credentials:

- nested executables and the application are Developer ID signed;
- the package is signed with Developer ID Installer;
- the package or disk image is submitted to Apple's notary service;
- the resulting ticket is stapled and validated.

This optional path improves Gatekeeper behavior but does not change application
features, identifiers, installed paths, or update semantics.

## Build interface

A repository script accepts a semantic version and build number, builds the
release application, assembles the package root and scripts, creates the
component package, creates the product package, and wraps it in a compressed
read-only disk image.

Signing identities and notarization credentials are optional environment
inputs. Secrets are never committed, printed, or copied into the artifacts.
Generated roots, packages, disk images, mount points, and logs remain ignored
by Git.

The selected `smartctl` source is copied into the package during the build. At
runtime, neither the application nor the root service executes a Homebrew-owned
path.

## Verification

Automated tests and packaging verification must cover:

- stable package, application, and daemon identifiers;
- stable installation paths;
- monotonically increasing version inputs and downgrade prevention metadata;
- package payload ownership and modes;
- fixed SMART executable and argument policy;
- absence of network APIs, remote URLs, WebViews, and network entitlements;
- absence of unrelated privacy usage descriptions and entitlements;
- package receipt metadata;
- application and nested-code signature verification;
- LaunchDaemon plist validation;
- package expansion and payload inspection;
- disk image verification, read-only mounting, and expected contents;
- preservation of user data paths by install and uninstall scripts.

Tests must not install the package, load a daemon, invoke `sudo`, or modify
`/Applications`, `/Library`, or user application data.

## Git attribution

All existing commits on the unpushed development branch carry:

`Co-authored-by: Codex <codex@openai.com>`

Future commits created with Codex assistance use the same trailer.
