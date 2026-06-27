# OpenSurface Camera Obscura Guided Detail

OpenSurface Camera Obscura Guided Detail is a production-staging shader unit for ReShade. It contains two paired effects that work from the same idea: do not enhance every contrast signal blindly; first ask whether the signal belongs to a coherent surface.

This package is the first public-facing staging shape for the Camera Obscura guided tonal-detail lane.

## The short version

This unit provides:

- **OpenSurface Camera Obscura Guided Detail Reclamation**
- **OpenSurface Camera Obscura Guided Ink Lines**

Both effects are RGB-neutral tonal tools. They change lightness while preserving hue direction. Both use depth confidence, same-surface neighbor support, and reuse-readiness style gating before touching the image.

In plain language:

- **Guided Detail Reclamation** recovers stable fine detail without acting like a global sharpener.
- **Guided Ink Lines** darkens admitted line, contour, and support-break evidence without acting like a blunt cartoon outline pass.

## Why this exists

Most sharpening and ink effects begin with a simple question:

> Is there contrast here?

Camera Obscura guided detail begins with a stricter question:

> Is this contrast on a believable same-surface neighborhood, and is it safe to touch?

That distinction is the whole rail.

A normal sharpener can make noise, UI, silhouettes, and texture chatter louder. A normal ink pass can draw any strong edge whether it is useful or not. The OpenSurface Camera Obscura guided pair tries to be more conservative and more inspectable: it exposes the admission masks, the surface support, the applied contribution, and the final composite separately.

## Package layout

```text
OpenSurface/CameraObscura/GuidedDetail/
├─ effects/
│  ├─ OSCO_GuidedDetailReclamation.fx
│  └─ OSCO_GuidedInkLines.fx
├─ header/
│  ├─ OSCO_GuidedDetail_Common.fxh
│  └─ OSCO_GuidedDetail_DebugVisibility.fxh
├─ docs/
│  ├─ HEADER_PRUNE_REPORT_2026-06-26.md
│  └─ staging_manifest.json
├─ licenses/
│  └─ THIRD_PARTY_NOTICES.md
├─ LICENSE
└─ README.md
```

The staged unit is intentionally small. Earlier transitional API scaffolding was peeled away. The active header capsule is now two files:

- `OSCO_GuidedDetail_Common.fxh`
- `OSCO_GuidedDetail_DebugVisibility.fxh`

The old large header fan-out was removed from this public staging unit because these two effects do not need trace, scene, SSGI, SSR, material, primary march, secondary march, or full distributed API support.

## Effects

### OpenSurface Camera Obscura Guided Detail Reclamation

File:

```text
effects/OSCO_GuidedDetailReclamation.fx
```

Technique:

```text
OSCO_GuidedDetailReclamation
```

Purpose:

Guided Detail Reclamation is a same-surface detail recovery pass. It compares the source pixel against an admitted local neighborhood and adds back a capped signed lightness contribution.

It can lighten or darken locally, because the contribution is signed:

- if the source pixel is brighter than its trusted local average, it may brighten;
- if the source pixel is darker than its trusted local average, it may darken;
- if the same-surface support is weak, it should do little or nothing.

It is not a generic global sharpener. It is a guarded detail-recovery effect.

Primary controls:

- `Tuning Target` : [loads a sane starting profile]
- `Depth Protect` : [reduces action where depth authority is weak]
- `Luma Protect` : [holds back action on fragile brightness transitions]
- `Stability Start` : [sets where stability gating begins to count]
- `Stability Full` : [sets where stability gating reaches full authority]
- `Sharpness Radius Pixels` : [sets how wide the detail search reaches]
- `Support Start` : [sets where surface support begins to count]
- `Support Full` : [sets where surface support reaches full authority]
- `Sharpness Strength` : [makes the reclaimed detail stronger]
- `Harsh Edge Protection` : [suppresses sharpening on big hard edges]
- `Detail Start` : [sets the minimum detail level that starts to pass]
- `Detail Full` : [sets the detail level that reaches full effect]
- `Contribution Ceiling` : [caps how much sharpening contribution can be applied]
- `Mask Boost` : [amplifies the admitted sharpness mask]
- `Mask Curve` : [reshapes the mask response]
- `Shadow Protection` : [holds back action in dark regions]
- `Highlight Protection` : [holds back action in bright regions]

Useful debug views:

- `Reuse Ready`
- `Depth Confidence`
- `Addressed Neighbor Coverage`
- `Surface Support`
- `Detail Field`
- `Sharpness Mask`
- `Applied Sharpness`
- `Harsh Edge Protection`
- `Source Preserve Delta`

Expected personality:

- Clean same-surface detail should gain presence.
- Halos should be restrained by edge protection and contribution ceiling.
- Faint masks may need debug visibility lift, but debug visibility does not alter the final composite.

### OpenSurface Camera Obscura Guided Ink Lines

File:

```text
effects/OSCO_GuidedInkLines.fx
```

Technique:

```text
OSCO_GuidedInkLines
```

Purpose:

Guided Ink Lines is a same-surface ink and contour darkening pass. It builds line evidence from stable local luma/detail changes, object-contour evidence, and optional surface-support outline evidence. It only darkens; it does not perform signed sharpening.

It is not a blunt edge detector. It is a guided ink pass with explicit contour carry and support-outline controls.

Primary controls:

- `Tuning Target` : [loads a sane starting profile]
- `Depth Protect` : [reduces line action where depth authority is weak]
- `Luma Protect` : [holds back ink on fragile brightness transitions]
- `Stability Start` : [sets where stability gating begins to count]
- `Stability Full` : [sets where stability gating reaches full authority]
- `Ink Radius Pixels` : [sets how wide the line search reaches]
- `Ink Strength` : [makes the image darker where ink is admitted]
- `Edge Ink` : [adds darkening from stable edge evidence]
- `Detail Ink` : [adds darkening from fine detail evidence]
- `Object Contour Carry` : [lets object-boundary evidence feed the ink mask]
- `Object Contour Darken` : [adds extra darkening on admitted object borders]
- `Object Contour Headroom` : [limits how much contour darkening can accumulate]
- `Surface Support Outline` : [adds direct surface-break outlines into the image]
- `Surface Outline Strength` : [controls how strongly the support outline shows up]
- `Line Start` : [sets the minimum line evidence that starts to pass]
- `Line Full` : [sets the line evidence that reaches full effect]
- `Deep Shadow Protection` : [holds back ink in very dark regions]
- `Highlight Protection` : [holds back ink in bright regions]
- `Ink Darkening Ceiling` : [caps the total darkening the ink pass can apply]

Useful debug views:

- `Reuse Ready`
- `Depth Confidence`
- `Addressed Neighbor Coverage`
- `Surface Support`
- `Edge Ink Field`
- `Detail Ink Field`
- `Ink Mask`
- `Applied Ink`
- `Tone Protection`
- `Source Preserve Delta`
- `Object Contour Field`
- `Surface Support Outline`

Expected personality:

- Valid line evidence should appear in `Ink Mask` and `Applied Ink`.
- Object contours should be inspectable before they are trusted in final output.
- Surface-support outlines should be enabled only when the support-outline debug view is clean enough for the game/content being tested.

## Shared method

Both effects use the same minimal support capsule:

```hlsl
#include "ReShade.fxh"
#include "../header/OSCO_GuidedDetail_Common.fxh"
#include "../header/OSCO_GuidedDetail_DebugVisibility.fxh"
```

The common header provides:

- color and depth samplers;
- depth-ready uniform;
- runtime depth reverse mode;
- sky-depth and depth-edge controls;
- safe reciprocal;
- UV clamp and pixel-size helpers;
- color/depth load helpers;
- luma calculation;
- linear depth conversion;
- depth agreement;
- luma agreement;
- same-surface stability authority;
- tap addressing and border coverage;
- same-surface tap support.

The debug header provides:

- scalar debug visibility shaping;
- color debug visibility shaping;
- heat-map debug palette;
- threshold, invert, lift-floor, and exposure/contrast/gamma post views.

Debug visibility controls affect inspection views only. They do not change the final composite path.

## Compile dependency model

This package intentionally does **not** vendor `ReShade.fxh`.

Compile inside a normal ReShade shader environment where `ReShade.fxh` is supplied by ReShade or by the user's shader include path.

Expected relative layout during compile:

```text
<shader-root>/
├─ effects/
│  ├─ OSCO_GuidedDetailReclamation.fx
│  └─ OSCO_GuidedInkLines.fx
└─ header/
   ├─ OSCO_GuidedDetail_Common.fxh
   └─ OSCO_GuidedDetail_DebugVisibility.fxh
```

The effects include `../header/...`, so the `effects` and `header` folders should remain siblings unless the include paths are edited intentionally.

## Installation for local ReShade testing

One practical test layout is:

```text
reshade-shaders/
├─ Shaders/
│  └─ OpenSurface/
│     └─ CameraObscura/
│        └─ GuidedDetail/
│           ├─ effects/
│           │  ├─ OSCO_GuidedDetailReclamation.fx
│           │  └─ OSCO_GuidedInkLines.fx
│           └─ header/
│              ├─ OSCO_GuidedDetail_Common.fxh
│              └─ OSCO_GuidedDetail_DebugVisibility.fxh
```

If ReShade does not discover effects nested this deeply in your setup, use a flatter test layout while preserving `effects/` and `header/` as siblings.

For example:

```text
reshade-shaders/Shaders/
├─ effects/
│  ├─ OSCO_GuidedDetailReclamation.fx
│  └─ OSCO_GuidedInkLines.fx
└─ header/
   ├─ OSCO_GuidedDetail_Common.fxh
   └─ OSCO_GuidedDetail_DebugVisibility.fxh
```

## First compile checklist

Before judging the look, verify the compile state.

1. Reload ReShade effects.
2. Confirm both techniques appear:
   - `OSCO_GuidedDetailReclamation`
   - `OSCO_GuidedInkLines`
3. Confirm there are no missing include errors for:
   - `ReShade.fxh`
   - `OSCO_GuidedDetail_Common.fxh`
   - `OSCO_GuidedDetail_DebugVisibility.fxh`
4. Confirm no duplicate-symbol errors appear if both effects are enabled together.
5. Confirm each effect can show `Final Composite` without black-screen output.
6. Only then begin tuning/debug-view inspection.

If compile fails, capture the first error block before changing code. Later errors are often fallout from the first missing include or first syntax failure.

## Live test order: Guided Detail Reclamation

Use this order when checking the sharpness/detail effect:

1. `Reuse Ready`
   - Good: coherent gray/white where depth-supported surfaces exist.
   - Bad: all black means no authority; check depth availability.
2. `Depth Confidence`
   - Good: valid objects/surfaces visible.
   - Bad: all black or inverted-looking depth means depth setup needs attention.
3. `Surface Support`
   - Good: stable surfaces are readable and not mostly shattered.
   - Bad: noisy/speckled support means the effect may shimmer or do little.
4. `Detail Field`
   - Good: fine same-surface texture/detail appears around mid-gray.
   - Bad: huge hard silhouettes dominating the field means edge protection matters.
5. `Sharpness Mask`
   - Good: selective mask on legitimate surface detail.
   - Bad: entire frame white means over-admission; entire frame black means too strict.
6. `Applied Sharpness`
   - Good: visible but controlled contribution.
   - Bad: halos or harsh rings mean lower strength, raise edge protection, or lower contribution ceiling.
7. `Final Composite`
   - Good: detail is clearer but not crunchy.

## Live test order: Guided Ink Lines

Use this order when checking the ink effect:

1. `Object Contour Field`
   - Good: useful borders and object breaks appear.
   - Bad: random texture noise dominates; contour carry should stay low.
2. `Surface Support Outline`
   - Good: clean support breaks around meaningful surfaces.
   - Bad: crawling or banded support lines; keep direct support outline off.
3. `Ink Mask`
   - Good: admitted ink shape is selective.
   - Bad: full-frame fog means thresholds/strength are too permissive.
4. `Applied Ink`
   - Good: darkening appears where final lines should be.
   - Bad: black crush means reduce ink strength or darkening ceiling.
5. `Tone Protection`
   - Good: deep shadows/highlights retain protection where needed.
6. `Final Composite`
   - Good: lines read, but the image does not collapse into charcoal.

## Tuning target guidance

### Guided Detail Reclamation

Start with a conservative target, then move up only if the output is too gentle.

Suggested ladder:

1. `Default Verified`
2. `Soft Recovery`
3. `Balanced Recovery`
4. `Crisp Surface Detail`
5. `Aggressive Surface Detail`
6. `Detail Diagnostic` only to prove reach
7. `Manual Controls` when actively tuning

If halos appear, try `Halo Guard` before touching many sliders.

### Guided Ink Lines

Start from the live-good baseline, then add line authority only where the debug views prove the signal is clean.

Suggested ladder:

1. `Default Verified`
2. `Soft Support Lines`
3. `Balanced Support Lines`
4. `Strong Object Borders`
5. `Heavy Ink Diagnostic` only to prove reach
6. `Clean No Overlay` if the support outline is too busy
7. `Manual Controls` when actively tuning

## Failure patterns and first responses

| Symptom | Likely cause | First response |
| --- | --- | --- |
| Effect compiles but does nothing | Depth confidence or reuse authority too low | Inspect `Depth Confidence`, then `Reuse Ready` |
| Debug views visible, final subtle | Mask exists but contribution ceiling/strength is conservative | Check `Applied Sharpness` or `Applied Ink` before raising strength |
| Halos around silhouettes | Detail reclamation touching large boundaries | Raise `Harsh Edge Protection`, lower `Contribution Ceiling` |
| Whole image darkens | Ink mask too broad or darkening ceiling too high | Inspect `Ink Mask`; lower `Ink Strength` or `Ink Darkening Ceiling` |
| Surface outline crawls or bands | Support-outline evidence is unstable | Turn off `Surface Support Outline` or use `Clean No Overlay` |
| Everything is black | Missing depth, failed compile, or all authority rejected | Check ReShade log first, then `Depth Confidence` |
| Everything is white in a mask | Admission too broad | Tighten start/full thresholds or lower mask boost/carry |

## Naming convention

Public production-final naming uses:

```text
OpenSurface Camera Obscura [Function Name]
```

Short/internal prefix:

```text
OSCO
```

Current staged effects:

```text
OSCO_GuidedDetailReclamation.fx
OSCO_GuidedInkLines.fx
```

The public name carries intent. The internal prefix keeps shader symbols compact enough for practical development.

## License posture

OpenSurface shader code staged here is licensed under the MIT License. See:

```text
LICENSE
```

Third-party/runtime posture is recorded in:

```text
licenses/THIRD_PARTY_NOTICES.md
```

Important points:

- `ReShade.fxh` is not bundled in this staging unit.
- ReShade runtime/framework files are external dependencies.
- The local reference copy of `ReShade.fxh` inspected during staging carried `SPDX-License-Identifier: CC0-1.0`.
- If a future package vendors any ReShade framework file, preserve that upstream file's license/SPDX notice exactly.


