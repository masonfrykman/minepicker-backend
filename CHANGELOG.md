# Minepicker Backend changelog.

## ESPRESSO with MOCHA SWIRL

COMPATIBILITY: tbd

- Added locked-down file management.
- Server now gracefully exits & saves the manifest on SIGINT & SIGTERM.
- Cached versions list now refreshes every 3 days.
- Combined unauth & auth instance info handler into /instance/<uuid>/info.
- Passwords are now stored hashed & automatically migrates the database on start.
- Fixed account creation without a previous username & password

## ESPRESSO with HAZELNUT

COMPATIBILITY: SIMBA patch 3 - NALA patch 1

SUMMARY: Not everyone wants to type.

- Advertise server via Multicast for quick joining in Minecraft. (Requires NALA patch 1)
- Query features of the server.

## ESPRESSO with CARAMEL

COMPATIBILITY: SIMBA patch 3 - SIMBA patch 4

SUMMARY: Not everyone wants to type a new port number every time.

- Added setting an optional static port outside the dynamic range. Must be toggled with a try-static=true value while sending a start request. (Requires SIMBA patch 4)
- Fixed port not releasing when instance stops
- Under the hood improvements.

## ESPRESSO with VANILLA

COMPATIBILITY: SIMBA patch 3

SUMMARY: Mostly bug fixes but adds a small, yet useful feature of random port assignment.

- Checks to make sure an account is in the db.
- Added handler for SIGKILL-ing a server process.
- Added Multiple instances at once support (port range & random port assignment)
- Authentication switched to a catch-all middleware requiring X-Username & X-Password headers. Any pre-username/password fields obsolete (except for select /account URLs).
- Fixed saving server.properties mixins w/ the manifest.
- Fixed change password handler returning 403 on success & 200 on fail.
- Fixed player list not clearing when server closes with player still in game.


## AMERICANO with CARAMEL

COMPATIBILITY: SIMBA patch 1 - SIMBA patch 2

SUMMARY: Small update to fix issues with intial release.

- Added handler to get server.properties mixins.
- Added Date handler.

## AMERICANO with VANILLA

COMPATIBILITY: SIMBA patch 1

- Initial version.
