# Minepicker Backend changelog.

## ESPRESSO with HAZELNUT

COMPATIBILITY: SIMBA patch 3 - NALA patch 1

- Advertise server via Multicast for quick joining in Minecraft.
- Query features of the server.

## ESPRESSO with CARAMEL

COMPATIBILITY: SIMBA patch 3 - SIMBA patch 4

- Added setting an optional static port outside the dynamic range. Must be toggled with a try-static=true value while sending a start request.
- Fixed port not releasing when instance stops
- Under the hood improvements.

## ESPRESSO with VANILLA

COMPATIBILITY: SIMBA patch 3

- Checks to make sure an account is in the db.
- Added handler for SIGKILL-ing a server process.
- Added Multiple instances at once support (port range & random port assignment)
- Authentication switched to a catch-all middleware requiring X-Username & X-Password headers. Any pre-username/password fields obsolete (except for select /account URLs).
- Fixed saving server.properties mixins w/ the manifest.
- Fixed change password handler returning 403 on success & 200 on fail.
- Fixed player list not clearing when server closes with player still in game.


## AMERICANO with CARAMEL

COMPATIBILITY: SIMBA patch 1 - SIMBA patch 2

- Added handler to get server.properties mixins.
- Added Date handler.

## AMERICANO with VANILLA

COMPATIBILITY: SIMBA patch 1

- Initial version.
