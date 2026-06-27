# Third-Party Notices

## ReShade

These OpenSurface Camera Obscura shaders are intended to compile and run in ReShade.

`ReShade.fxh` and the ReShade runtime/framework are not bundled in this staging unit. They are expected to be provided by the user's ReShade installation or shader include path.

If future public packages vendor any ReShade framework file, preserve that file's upstream SPDX/license notice exactly. The local reference copy of `ReShade.fxh` inspected in Aurora/inbox carries `SPDX-License-Identifier: CC0-1.0`.

## Compatibility posture

The OpenSurface shader code in this staged unit is MIT licensed, matching the permissive style used by many ReShade example shaders while keeping ReShade framework files external.
