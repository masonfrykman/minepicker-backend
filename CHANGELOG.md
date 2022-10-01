# Minepicker Backend changelog.

## 1.1.0

COMPATIBILITY: tbd

- Added locked-down file management. (Requres NALA patch 2)
- Server now gracefully exits & saves the manifest on SIGINT & SIGTERM.
- Cached versions list now refreshes every 3 days.
- Combined unauth & auth instance info handler into /instance/<uuid>/info.
- Passwords are now stored hashed & automatically migrates the database on start.
- Fixed account creation without a previous username & password

## 1.0.4

COMPATIBILITY: 1.0.2 - 1.1.0

SUMMARY: Not everyone wants to type.

- Advertise server via Multicast for quick joining in Minecraft. (Requires NALA patch 1)
- Query features of the server.

## 1.0.3

COMPATIBILITY: 1.0.2 - 1.0.3

SUMMARY: Not everyone wants to type a new port number every time.

- Added setting an optional static port outside the dynamic range. Must be toggled with a try-static=true value while sending a start request. (Requires SIMBA patch 4)
- Fixed port not releasing when instance stops
- Under the hood improvements.

## 1.0.2

COMPATIBILITY: 1.0.2

SUMMARY: Mostly bug fixes but adds a small, yet useful feature of random port assignment.

- Checks to make sure an account is in the db.
- Added handler for SIGKILL-ing a server process.
- Added Multiple instances at once support (port range & random port assignment)
- Authentication switched to a catch-all middleware requiring X-Username & X-Password headers. Any pre-username/password fields obsolete (except for select /account URLs).
- Fixed saving server.properties mixins w/ the manifest.
- Fixed change password handler returning 403 on success & 200 on fail.
- Fixed player list not clearing when server closes with player still in game.


## 1.0.1

COMPATIBILITY: 1.0.0 - 1.0.1

SUMMARY: Small update to fix issues with intial release.

- Added handler to get server.properties mixins.
- Added Date handler.

## 1.0.0

COMPATIBILITY: 1.0.0

- Initial version.
