// OpenSurface Camera Obscura Guided Ink Lines
// SPDX-License-Identifier: MIT
// Requires ReShade runtime headers; ReShade.fxh is intentionally not vendored here.

#include "ReShade.fxh"
#include "../header/OSCO_GuidedDetail_Common.fxh"
#include "../header/OSCO_GuidedDetail_DebugVisibility.fxh"

uniform int OSCO_GIL_Help
<
    ui_label = " ";
    ui_text =
        "OpenSurface Camera Obscura Guided Ink Lines\n"
        "\n"
        "Purpose:\n"
        "  RGB-neutral ink darkening from stable same-surface structure.\n"
        "  Object contours and optional surface-support outlines can be\n"
        "  carried into the final image.\n"
        "\n"
        "Basic use:\n"
        "  1. Start with Tuning Target = Default Verified.\n"
        "  2. If more outline is needed, try Soft Support Lines,\n"
        "     Balanced Support Lines, then Strong Object Borders.\n"
        "  3. Heavy Ink Diagnostic is only for proving signal reach.\n"
        "  4. Clean No Overlay disables direct support-outline burn-in.\n"
        "  5. Manual Controls lets the individual sliders drive the math.\n"
        "\n"
        "Key blocks:\n"
        "  01 Stability: same-surface readiness and neighborhood radius.\n"
        "  02 Ink: base edge/detail ink and line thresholds.\n"
        "  03 Object Contours: object-border carry, darken, and headroom.\n"
        "  04 Surface Outline: direct support-outline overlay controls.\n"
        "  05 Tone Guards: shadow/highlight protection and darkening cap.\n"
        "  06 Views: final/debug views and display-only debug shaping.\n"
        "\n"
        "Inspection order:\n"
        "  Object Contour Field -> Surface Support Outline -> Ink Mask ->\n"
        "  Applied Ink -> Final Composite.\n"
        "\n"
        "Important:\n"
        "  Debug Visibility controls affect inspection views only.\n"
        "  They do not alter Final Composite.\n"
        ;
    ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / Help";
    ui_category_closed = true;
    ui_type = "radio";
> = 0;

uniform int OSCO_GIL_TuningTarget
< ui_type = "combo"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 00 Target"; ui_label = "Tuning Target"; ui_items = "Default Verified\0Soft Support Lines\0Balanced Support Lines\0Strong Object Borders\0Heavy Ink Diagnostic\0Clean No Overlay\0Manual Controls\0"; ui_tooltip =
    "Named tuning rail.\n"
    "Default Verified is the live-good baseline.\n"
    "Manual Controls uses the sliders in the blocks below.\n"
    "\nDefault: Default Verified";
> = 0;

uniform float OSCO_GIL_DepthProtect
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 01 Stability"; ui_category_closed = true; ui_label = "Depth Protect"; ui_min = 0.00010; ui_max = 0.02000; ui_step = 0.00005; ui_tooltip = "Same-surface depth tolerance. Lower is stricter near silhouettes."; > = 0.00350;

uniform float OSCO_GIL_LumaProtect
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 01 Stability"; ui_category_closed = true; ui_label = "Luma Protect"; ui_min = 0.010; ui_max = 0.500; ui_step = 0.002; ui_tooltip = "Luma tolerance for readiness. Higher accepts broader tone changes."; > = 0.140;

uniform float OSCO_GIL_ReadyStart
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 01 Stability"; ui_category_closed = true; ui_label = "Stability Start"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Readiness point where ink starts entering the mask."; > = 0.10;

uniform float OSCO_GIL_ReadyFull
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 01 Stability"; ui_category_closed = true; ui_label = "Stability Full"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Readiness point where stable ink has full authority."; > = 0.52;

uniform float OSCO_GIL_RadiusPixels
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 01 Stability"; ui_category_closed = true; ui_label = "Ink Radius Pixels"; ui_min = 0.50; ui_max = 6.00; ui_step = 0.05; ui_tooltip = "Neighborhood radius for local line and support checks."; > = 1.25;

uniform float OSCO_GIL_Strength
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 02 Ink"; ui_label = "Ink Strength"; ui_min = 0.00; ui_max = 3.00; ui_step = 0.005; ui_tooltip = "Master darkening strength for admitted ink."; > = 1.10;

uniform float OSCO_GIL_EdgeAmount
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 02 Ink"; ui_label = "Edge Ink"; ui_min = 0.00; ui_max = 4.00; ui_step = 0.005; ui_tooltip = "Ink drawn from local luma edge evidence."; > = 1.35;

uniform float OSCO_GIL_DetailAmount
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 02 Ink"; ui_label = "Detail Ink"; ui_min = 0.00; ui_max = 4.00; ui_step = 0.005; ui_tooltip = "Ink drawn from fine same-surface variation."; > = 0.65;

uniform float OSCO_GIL_ContourCarry
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 03 Object Contours"; ui_label = "Object Contour Carry"; ui_min = 0.00; ui_max = 3.00; ui_step = 0.005; ui_tooltip =
    "Carries object-border contour evidence into final ink.\n"
    "Use when borders exist but the final image is too faint.\n"
    "Higher values admit more contour mask.\n"
    "\nDefault: 0.60";
> = 0.60;

uniform float OSCO_GIL_ContourDarken
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 03 Object Contours"; ui_label = "Object Contour Darken"; ui_min = 0.00; ui_max = 3.00; ui_step = 0.005; ui_tooltip =
    "Darkening strength for carried object contours.\n"
    "Raise when the mask is good but the line is pale.\n"
    "Lower if the image gets charcoal-heavy.\n"
    "\nDefault: 0.90";
> = 0.90;

uniform float OSCO_GIL_ContourHeadroom
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 03 Object Contours"; ui_label = "Object Contour Headroom"; ui_min = 0.00; ui_max = 0.75; ui_step = 0.005; ui_tooltip =
    "Reserves contour mask and darkening headroom.\n"
    "Higher is cleaner and less pinned.\n"
    "Lower gives more bite when the signal is already clean.\n"
    "\nDefault: 0.20";
> = 0.20;

uniform int OSCO_GIL_SurfaceSupportOutlineToggle
< ui_type = "combo"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 04 Surface Outline"; ui_label = "Surface Support Outline"; ui_items = "Off\0On\0"; ui_tooltip =
    "Manual switch for direct support-outline overlay.\n"
    "Targets override this unless Manual Controls is selected.\n"
    "Use only when the Surface Support Outline view is clean.\n"
    "\nDefault: Off";
> = 0;

uniform float OSCO_GIL_SurfaceSupportOutlineStrength
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 04 Surface Outline"; ui_label = "Surface Outline Strength"; ui_min = 0.00; ui_max = 2.00; ui_step = 0.005; ui_tooltip =
    "Direct support-outline strength.\n"
    "Higher burns support breaks darker.\n"
    "Lower keeps the frame cleaner.\n"
    "\nDefault: 0.75";
> = 0.75;

uniform float OSCO_GIL_LineStart
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 02 Ink"; ui_category_closed = true; ui_label = "Line Start"; ui_min = 0.000; ui_max = 0.200; ui_step = 0.001; ui_tooltip = "Line energy where ink begins."; > = 0.010;

uniform float OSCO_GIL_LineFull
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 02 Ink"; ui_category_closed = true; ui_label = "Line Full"; ui_min = 0.001; ui_max = 0.400; ui_step = 0.001; ui_tooltip = "Line energy where ink reaches full coverage."; > = 0.075;

uniform float OSCO_GIL_ShadowProtection
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 05 Tone Guards"; ui_category_closed = true; ui_label = "Deep Shadow Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Protects existing deep shadows from extra ink crush."; > = 0.72;

uniform float OSCO_GIL_HighlightProtection
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 05 Tone Guards"; ui_category_closed = true; ui_label = "Highlight Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Reduces dark ink on tiny bright highlights."; > = 0.35;

uniform float OSCO_GIL_DarkeningCeiling
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 05 Tone Guards"; ui_category_closed = true; ui_label = "Ink Darkening Ceiling"; ui_min = 0.005; ui_max = 0.500; ui_step = 0.002; ui_tooltip = "Maximum lightness reduction from ink."; > = 0.18;

uniform int OSCO_GIL_View
< ui_type = "combo"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 06 Views"; ui_label = "Ink View"; ui_items = "Final Composite\0Reuse Ready\0Depth Confidence\0Addressed Neighbor Coverage\0Surface Support\0Edge Ink Field\0Detail Ink Field\0Ink Mask\0Applied Ink\0Tone Protection\0Source Preserve Delta\0Object Contour Field\0Surface Support Outline\0"; ui_tooltip =
    "Final image plus inspection views.\n"
    "Use Object Contour Field and Surface Support Outline first.\n"
    "Then inspect Ink Mask, Applied Ink, and Final Composite.\n"
    "\nDefault: Final Composite";
> = 0;

uniform int OSCO_GIL_DebugPostMode
< ui_type = "combo"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 06 Views"; ui_category_closed = true; ui_label = "Debug Visibility Mode"; ui_items = "Normal Adjusted\0Lift Floor\0Heat Luma\0Threshold Mask\0Invert\0"; ui_tooltip =
    "Display shaping for inspection views only.\n"
    "Does not change Final Composite.\n"
    "Use it to reveal faint masks or isolate thresholds.\n"
    "\nDefault: Normal Adjusted";
> = 0;

uniform float OSCO_GIL_DebugExposure
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 06 Views"; ui_category_closed = true; ui_label = "Debug Exposure"; ui_min = 0.00; ui_max = 8.00; ui_step = 0.01; ui_tooltip = "Inspection brightness only."; > = 1.00;

uniform float OSCO_GIL_DebugBias
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 06 Views"; ui_category_closed = true; ui_label = "Debug Bias"; ui_min = -1.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Inspection brightness offset only."; > = 0.00;

uniform float OSCO_GIL_DebugContrast
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 06 Views"; ui_category_closed = true; ui_label = "Debug Contrast"; ui_min = 0.00; ui_max = 8.00; ui_step = 0.01; ui_tooltip = "Inspection contrast only."; > = 1.00;

uniform float OSCO_GIL_DebugGamma
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 06 Views"; ui_category_closed = true; ui_label = "Debug Gamma"; ui_min = 0.10; ui_max = 4.00; ui_step = 0.01; ui_tooltip = "Inspection gamma only. Lower lifts faint signals."; > = 1.00;

uniform float OSCO_GIL_DebugFloor
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 06 Views"; ui_category_closed = true; ui_label = "Debug Floor"; ui_min = 0.00; ui_max = 0.50; ui_step = 0.005; ui_tooltip = "Inspection floor only. Reveals faint masks."; > = 0.00;

uniform float OSCO_GIL_DebugThreshold
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Ink Lines / 06 Views"; ui_category_closed = true; ui_label = "Debug Threshold"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Threshold for Threshold Mask view."; > = 0.50;

float OSCO_GIL_SmoothRange(float edge0, float edge1, float value)
{
    float width = max(edge1 - edge0, 0.000001);
    float t = saturate((value - edge0) * OSCO_SafeRcp(width, 0.0));
    return t * t * (3.0 - 2.0 * t);
}

void OSCO_GIL_ConsiderTap(
    float2 requestedUv,
    float2 footprintHalfUv,
    float basisWeight,
    OSCO_RM_StabilityAuthority center,
    float centerLuma,
    inout float lumaSum,
    inout float weightSum,
    inout float supportSum,
    inout float basisSum,
    inout float weightedDifferenceSum,
    inout float peakDifference,
    inout float rawContourPeak)
{
    OSCO_RM_StabilityTapAddress address = OSCO_RM_BuildStabilityTapAddress(
        requestedUv,
        footprintHalfUv);
    float tapWeight = 0.0;
    float support = 0.0;
    float tapLuma = 0.0;
    float lumaDifference = 0.0;
    float rawContour = 0.0;

    if (address.address_confidence > 0.0001)
    {
        OSCO_RM_DepthSample tapDepth = OSCO_RM_LoadLeanTapDepth(address.resolved_uv);

        if (tapDepth.confidence > 0.0001)
        {
            float3 tapColor = OSCO_RM_LoadColor(address.resolved_uv).rgb;
            float depthDifference;
            float lumaContour;
            float depthContour;

            tapLuma = OSCO_RM_Luma(tapColor);
            lumaDifference = abs(tapLuma - centerLuma);
            depthDifference = abs(tapDepth.linear01 - center.depth_linear01);
            lumaContour = OSCO_GIL_SmoothRange(
                OSCO_GIL_LineStart,
                max(OSCO_GIL_LineFull, OSCO_GIL_LineStart + 0.001),
                lumaDifference);
            depthContour = OSCO_GIL_SmoothRange(
                OSCO_GIL_DepthProtect * 0.60,
                max(OSCO_GIL_DepthProtect * 5.00, OSCO_GIL_DepthProtect * 0.60 + 0.000001),
                depthDifference);
            rawContour = max(lumaContour * 0.75, depthContour);
            support = OSCO_RM_StabilityTapSupport(
                center,
                centerLuma,
                tapLuma,
                tapDepth,
                address.address_confidence,
                OSCO_GIL_DepthProtect,
                OSCO_GIL_LumaProtect);
            tapWeight = basisWeight * support;
        }
    }

    lumaSum += tapLuma * tapWeight;
    weightSum += tapWeight;
    supportSum += support * basisWeight;
    basisSum += basisWeight * address.address_confidence;
    weightedDifferenceSum += lumaDifference * tapWeight;
    peakDifference = max(peakDifference, lumaDifference * support);
    rawContourPeak = max(rawContourPeak, rawContour * max(address.border_coverage, 0.25));
}

float4 OSCO_GuidedInkLines_PS(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 uvSafe = OSCO_RM_ClampUV(uv);
    float2 px = OSCO_RM_PixelSize() * max(OSCO_GIL_RadiusPixels, 0.50);
    float2 footprintHalfUv = px * 0.5;
    float3 sourceColor = OSCO_RM_LoadColor(uvSafe).rgb;
    if (!OSCO_RM_HasDepth)
        return float4(sourceColor, 1.0);
    float sourceLuma = OSCO_RM_Luma(sourceColor);
    OSCO_RM_StabilityAuthority center = OSCO_RM_EvaluateStabilityAuthorityFast(
        uvSafe,
        sourceLuma,
        OSCO_GIL_DepthProtect,
        OSCO_GIL_LumaProtect);
    float centerAuthority = OSCO_RM_StabilityCenterAuthority(
        center.reuse_ready,
        center.depth_confidence,
        OSCO_GIL_ReadyStart,
        OSCO_GIL_ReadyFull);
    if (centerAuthority <= 0.0001)
        return float4(sourceColor, 1.0);

    float lumaSum = 0.0;
    float weightSum = 0.0;
    float supportSum = 0.0;
    float basisSum = 0.0;
    float weightedDifferenceSum = 0.0;
    float peakDifference = 0.0;
    float rawContourPeak = 0.0;

    OSCO_GIL_ConsiderTap(uvSafe - float2(px.x, 0.0), footprintHalfUv, 0.75, center, sourceLuma, lumaSum, weightSum, supportSum, basisSum, weightedDifferenceSum, peakDifference, rawContourPeak);
    OSCO_GIL_ConsiderTap(uvSafe + float2(px.x, 0.0), footprintHalfUv, 0.75, center, sourceLuma, lumaSum, weightSum, supportSum, basisSum, weightedDifferenceSum, peakDifference, rawContourPeak);
    OSCO_GIL_ConsiderTap(uvSafe - float2(0.0, px.y), footprintHalfUv, 0.75, center, sourceLuma, lumaSum, weightSum, supportSum, basisSum, weightedDifferenceSum, peakDifference, rawContourPeak);
    OSCO_GIL_ConsiderTap(uvSafe + float2(0.0, px.y), footprintHalfUv, 0.75, center, sourceLuma, lumaSum, weightSum, supportSum, basisSum, weightedDifferenceSum, peakDifference, rawContourPeak);

    float localAverageLuma = (weightSum > 0.000001)
        ? (lumaSum * OSCO_SafeRcp(weightSum, 0.0))
        : sourceLuma;
    float edgeInkField = abs(sourceLuma - localAverageLuma);
    float detailInkField = weightedDifferenceSum * OSCO_SafeRcp(max(weightSum, 0.000001), 0.0);
    float lineEnergy = max(
        edgeInkField * max(OSCO_GIL_EdgeAmount, 0.0),
        detailInkField * max(OSCO_GIL_DetailAmount, 0.0) + peakDifference * 0.20);

    float surfaceSupport = saturate(supportSum * OSCO_SafeRcp(max(basisSum, 0.000001), 0.0));
    float supportGate = OSCO_GIL_SmoothRange(0.06, 0.38, surfaceSupport);
    float lineGate = OSCO_GIL_SmoothRange(
        OSCO_GIL_LineStart,
        max(OSCO_GIL_LineFull, OSCO_GIL_LineStart + 0.001),
        lineEnergy);
    float contourLineGate = OSCO_GIL_SmoothRange(0.08, 0.65, rawContourPeak);

    float effectiveContourCarry = OSCO_GIL_ContourCarry;
    float effectiveContourDarken = OSCO_GIL_ContourDarken;
    float effectiveContourHeadroom = OSCO_GIL_ContourHeadroom;
    float effectiveSurfaceOutlineStrength = OSCO_GIL_SurfaceSupportOutlineStrength;
    int effectiveSurfaceOutlineToggle = OSCO_GIL_SurfaceSupportOutlineToggle;

    if (OSCO_GIL_TuningTarget == 0)
    {
        effectiveSurfaceOutlineToggle = 0;
        effectiveSurfaceOutlineStrength = 0.75;
        effectiveContourCarry = 0.60;
        effectiveContourDarken = 0.90;
        effectiveContourHeadroom = 0.20;
    }
    else if (OSCO_GIL_TuningTarget == 1)
    {
        effectiveSurfaceOutlineToggle = 1;
        effectiveSurfaceOutlineStrength = 0.35;
        effectiveContourCarry = 0.60;
        effectiveContourDarken = 0.90;
        effectiveContourHeadroom = 0.30;
    }
    else if (OSCO_GIL_TuningTarget == 2)
    {
        effectiveSurfaceOutlineToggle = 1;
        effectiveSurfaceOutlineStrength = 0.60;
        effectiveContourCarry = 0.70;
        effectiveContourDarken = 1.00;
        effectiveContourHeadroom = 0.25;
    }
    else if (OSCO_GIL_TuningTarget == 3)
    {
        effectiveSurfaceOutlineToggle = 1;
        effectiveSurfaceOutlineStrength = 0.90;
        effectiveContourCarry = 0.90;
        effectiveContourDarken = 1.15;
        effectiveContourHeadroom = 0.20;
    }
    else if (OSCO_GIL_TuningTarget == 4)
    {
        effectiveSurfaceOutlineToggle = 1;
        effectiveSurfaceOutlineStrength = 1.25;
        effectiveContourCarry = 1.10;
        effectiveContourDarken = 1.35;
        effectiveContourHeadroom = 0.10;
    }
    else if (OSCO_GIL_TuningTarget == 5)
    {
        effectiveSurfaceOutlineToggle = 0;
        effectiveSurfaceOutlineStrength = 0.00;
        effectiveContourCarry = 0.45;
        effectiveContourDarken = 0.70;
        effectiveContourHeadroom = 0.35;
    }

    float shadowRelease = OSCO_GIL_SmoothRange(0.012, 0.070, sourceLuma);
    float highlightRelease = 1.0 - OSCO_GIL_SmoothRange(0.90, 0.995, sourceLuma);
    float shadowGate = lerp(1.0, shadowRelease, saturate(OSCO_GIL_ShadowProtection));
    float highlightGate = lerp(1.0, highlightRelease, saturate(OSCO_GIL_HighlightProtection));
    float toneProtection = min(shadowGate, highlightGate);
    float authorityGate = sqrt(max(centerAuthority * supportGate, 0.0));
    float carriedLineGate = lerp(lineGate, sqrt(max(lineGate, 0.0)), 0.40);
    float contourHeadroom = saturate(effectiveContourHeadroom);
    float contourMaskCeiling = lerp(1.0, 0.82, contourHeadroom);
    float contourDarkenTrim = lerp(1.0, 0.72, contourHeadroom);
    float contourCarryGate = min(
        saturate(contourLineGate * center.depth_confidence * max(effectiveContourCarry, 0.0)),
        contourMaskCeiling);
    float surfaceSupportBreak = 1.0 - surfaceSupport;
    float surfaceSupportOutlineEvidence = surfaceSupportBreak
        * max(contourLineGate, lineGate * 0.50)
        * center.depth_confidence;
    float surfaceSupportOutline = OSCO_GIL_SmoothRange(0.08, 0.42, surfaceSupportOutlineEvidence);
    float rawInkMask = saturate(max(authorityGate * carriedLineGate, contourCarryGate) * toneProtection);
    float inkMask = lerp(rawInkMask, sqrt(max(rawInkMask, 0.0)), 0.25);

    float contourEnergy = contourLineGate
        * max(OSCO_GIL_LineFull, OSCO_GIL_LineStart + 0.001)
        * max(effectiveContourDarken, 0.0)
        * contourDarkenTrim;
    float inkDarkening = min(
        max(lineEnergy, contourEnergy) * max(OSCO_GIL_Strength, 0.0),
        max(OSCO_GIL_DarkeningCeiling, 0.0));
    float targetLuma = max(sourceLuma - inkDarkening, 0.0);
    float lumaScale = clamp(
        targetLuma * OSCO_SafeRcp(max(sourceLuma, 0.001), 1.0),
        0.12,
        1.0);
    float3 inkCandidate = saturate(sourceColor * lumaScale);
    float3 finalColor = lerp(sourceColor, inkCandidate, inkMask);

    if (effectiveSurfaceOutlineToggle != 0)
    {
        float outlineDarkening = min(
            max(OSCO_GIL_LineFull, OSCO_GIL_LineStart + 0.001)
                * max(effectiveSurfaceOutlineStrength, 0.0),
            max(OSCO_GIL_DarkeningCeiling, 0.0));
        float outlineLuma = OSCO_RM_Luma(finalColor);
        float outlineTargetLuma = max(outlineLuma - outlineDarkening, 0.0);
        float outlineScale = clamp(
            outlineTargetLuma * OSCO_SafeRcp(max(outlineLuma, 0.001), 1.0),
            0.08,
            1.0);
        finalColor = lerp(finalColor, saturate(finalColor * outlineScale), surfaceSupportOutline);
    }

    float sourcePreserveDelta = saturate(OSCO_RM_Luma(abs(finalColor - sourceColor)) * 10.0);

    float3 outColor;
    if (OSCO_GIL_View == 1) outColor = center.reuse_ready.xxx;
    else if (OSCO_GIL_View == 2) outColor = center.depth_confidence.xxx;
    else if (OSCO_GIL_View == 3) outColor = center.neighbor_coverage.xxx;
    else if (OSCO_GIL_View == 4) outColor = surfaceSupport.xxx;
    else if (OSCO_GIL_View == 5) outColor = OSCO_DebugVisibilityHeat(saturate(edgeInkField * 10.0));
    else if (OSCO_GIL_View == 6) outColor = OSCO_DebugVisibilityHeat(saturate(detailInkField * 10.0));
    else if (OSCO_GIL_View == 7) outColor = inkMask.xxx;
    else if (OSCO_GIL_View == 8) outColor = saturate(abs(finalColor - sourceColor) * 8.0);
    else if (OSCO_GIL_View == 9) outColor = toneProtection.xxx;
    else if (OSCO_GIL_View == 10) outColor = sourcePreserveDelta.xxx;
    else if (OSCO_GIL_View == 11) outColor = OSCO_DebugVisibilityHeat(saturate(contourLineGate));
    else if (OSCO_GIL_View == 12) outColor = surfaceSupportOutline.xxx;
    else return float4(finalColor, 1.0);

    outColor = OSCO_DebugVisibilityPost(
        outColor,
        OSCO_GIL_DebugPostMode,
        OSCO_GIL_DebugExposure,
        OSCO_GIL_DebugBias,
        OSCO_GIL_DebugContrast,
        OSCO_GIL_DebugGamma,
        OSCO_GIL_DebugFloor,
        OSCO_GIL_DebugThreshold);
    return float4(saturate(outColor), 1.0);
}

technique OSCO_GuidedInkLines
<
    ui_label = "OpenSurface Camera Obscura Guided Ink Lines";
    ui_tooltip = "RGB-neutral ink darkening drawn from stable same-surface structure, with reuse readiness acting as the primary ink authority.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OSCO_GuidedInkLines_PS;
    }
}


