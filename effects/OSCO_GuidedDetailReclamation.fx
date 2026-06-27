// OpenSurface Camera Obscura Guided Detail Reclamation
// SPDX-License-Identifier: MIT
// Requires ReShade runtime headers; ReShade.fxh is intentionally not vendored here.

#include "ReShade.fxh"
#include "../header/OSCO_GuidedDetail_Common.fxh"
#include "../header/OSCO_GuidedDetail_DebugVisibility.fxh"

uniform int OSCO_GDR_Help
<
    ui_label = " ";
    ui_text =
        "OpenSurface Camera Obscura Guided Detail Reclamation\n"
        "\n"
        "Purpose:\n"
        "  Recover same-surface RGB-neutral lightness detail only when reuse readiness,\n"
        "  depth confidence, and neighborhood support agree.\n"
        "  The pass stays RGB-neutral and keeps a hard ceiling on the\n"
        "  signed sharpness contribution.\n"
        "\n"
        "Basic use:\n"
        "  1. Start with Tuning Target = Manual Controls.\n"
        "  2. If the image feels too gentle, try Balanced Recovery or\n"
        "     Crisp Surface Detail.\n"
        "  3. If halos appear, try Halo Guard before changing sliders.\n"
        "  4. Detail Diagnostic is only for proving signal reach.\n"
        "  5. Manual Controls lets the sliders below drive the math.\n"
        "\n"
        "Inspection order:\n"
        "  Reuse Ready -> Surface Support -> Detail Field -> Sharpness Mask\n"
        "  -> Applied Sharpness -> Final Composite.\n"
        "\n"
        "Important:\n"
        "  Debug Visibility controls affect inspection views only.\n"
        "  They do not alter Final Composite.\n"
        ;
    ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / Help";
    ui_category_closed = true;
    ui_type = "radio";
> = 0;

uniform int OSCO_GDR_TuningTarget
< ui_type = "combo"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 00 Target"; ui_label = "Tuning Target"; ui_items = "Default Verified\0Soft Recovery\0Balanced Recovery\0Crisp Surface Detail\0Aggressive Surface Detail\0Halo Guard\0Detail Diagnostic\0Manual Controls\0"; ui_tooltip =
    "Named tuning rail.\n"
    "Default Verified preserves the original baseline.\n"
    "Manual Controls uses the sliders in the blocks below.\n"
    "\nDefault: Manual Controls";
> = 7;

uniform float OSCO_GDR_DepthProtect
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 01 Stability"; ui_category_closed = true; ui_label = "Depth Protect"; ui_min = 0.00010; ui_max = 0.02000; ui_step = 0.00005; ui_tooltip = "Depth mismatch tolerance used to keep sharpness on the same surface."; > = 0.00350;

uniform float OSCO_GDR_LumaProtect
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 01 Stability"; ui_category_closed = true; ui_label = "Luma Protect"; ui_min = 0.010; ui_max = 0.500; ui_step = 0.002; ui_tooltip = "Luma tolerance used by the stability evaluation."; > = 0.140;

uniform float OSCO_GDR_ReadyStart
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 01 Stability"; ui_category_closed = true; ui_label = "Stability Start"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Reuse readiness where sharpening begins."; > = 0.11;

uniform float OSCO_GDR_ReadyFull
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 01 Stability"; ui_category_closed = true; ui_label = "Stability Full"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Reuse readiness where sharpening reaches full authority."; > = 0.54;

uniform float OSCO_GDR_RadiusPixels
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 01 Stability"; ui_category_closed = true; ui_label = "Sharpness Radius Pixels"; ui_min = 0.50; ui_max = 8.00; ui_step = 0.05; ui_tooltip = "Radius of the same-surface neighborhood used to isolate fine detail."; > = 1.10;

uniform float OSCO_GDR_SupportStart
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 01 Stability"; ui_category_closed = true; ui_label = "Support Start"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Neighborhood support where the sharpness mask begins to trust the surface."; > = 0.05;

uniform float OSCO_GDR_SupportFull
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 01 Stability"; ui_category_closed = true; ui_label = "Support Full"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Neighborhood support where the sharpness mask has full same-surface authority."; > = 0.26;

uniform float OSCO_GDR_Strength
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 02 Sharpness"; ui_label = "Sharpness Strength"; ui_min = 0.00; ui_max = 4.00; ui_step = 0.005; ui_tooltip = "Strength of RGB-neutral signed lightness detail recovery."; > = 0.92;

uniform float OSCO_GDR_EdgeProtection
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 02 Sharpness"; ui_label = "Harsh Edge Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Suppresses sharpening on large contrast boundaries to limit halos."; > = 0.76;

uniform float OSCO_GDR_NoiseFloor
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 02 Sharpness"; ui_category_closed = true; ui_label = "Detail Start"; ui_min = 0.000; ui_max = 0.050; ui_step = 0.0005; ui_tooltip = "Fine-detail energy where sharpening begins."; > = 0.0018;

uniform float OSCO_GDR_NoiseFull
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 02 Sharpness"; ui_category_closed = true; ui_label = "Detail Full"; ui_min = 0.001; ui_max = 0.100; ui_step = 0.0005; ui_tooltip = "Fine-detail energy where sharpening reaches full strength."; > = 0.0110;

uniform float OSCO_GDR_ContributionCeiling
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 02 Sharpness"; ui_label = "Contribution Ceiling"; ui_min = 0.005; ui_max = 0.350; ui_step = 0.001; ui_tooltip = "Maximum signed lightness change contributed by the filter."; > = 0.080;

uniform float OSCO_GDR_MaskBoost
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 02 Sharpness"; ui_label = "Mask Boost"; ui_min = 0.25; ui_max = 5.00; ui_step = 0.01; ui_tooltip = "Gain applied to the admitted sharpness mask after readiness, support, detail, and tone protection are combined."; > = 1.45;

uniform int OSCO_GDR_HardMask
< ui_type = "combo"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 02 Sharpness"; ui_label = "Mask Curve"; ui_items = "Soft Admitted\0Hard Mask\0"; ui_tooltip = "Soft Admitted keeps the current eased admission curve. Hard Mask keeps more of the earned authority and detail response for a sharper, more aggressive result."; > = 0;

uniform float OSCO_GDR_ShadowProtection
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 03 Tone Guards"; ui_category_closed = true; ui_label = "Shadow Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Preserves deep shadows from extra same-surface bite."; > = 0.92;

uniform float OSCO_GDR_HighlightProtection
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 03 Tone Guards"; ui_category_closed = true; ui_label = "Highlight Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.005; ui_tooltip = "Suppresses sharpening on tiny bright highlights."; > = 0.90;

uniform int OSCO_GDR_View
< ui_type = "combo"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 04 Views"; ui_label = "Sharpness View"; ui_items = "Final Composite\0Reuse Ready\0Depth Confidence\0Addressed Neighbor Coverage\0Surface Support\0Detail Field\0Sharpness Mask\0Applied Sharpness\0Harsh Edge Protection\0Source Preserve Delta\0"; ui_tooltip = "Shows the final image or the evidence used to admit stable sharpness."; > = 0;

uniform int OSCO_GDR_DebugPostMode
< ui_type = "combo"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 04 Views"; ui_category_closed = true; ui_label = "Debug Visibility Mode"; ui_items = "Normal Adjusted\0Lift Floor\0Heat Luma\0Threshold Mask\0Invert\0"; > = 0;

uniform float OSCO_GDR_DebugExposure
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 04 Views"; ui_category_closed = true; ui_label = "Debug Exposure"; ui_min = 0.00; ui_max = 8.00; ui_step = 0.01; > = 1.00;

uniform float OSCO_GDR_DebugBias
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 04 Views"; ui_category_closed = true; ui_label = "Debug Bias"; ui_min = -1.00; ui_max = 1.00; ui_step = 0.01; > = 0.00;

uniform float OSCO_GDR_DebugContrast
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 04 Views"; ui_category_closed = true; ui_label = "Debug Contrast"; ui_min = 0.00; ui_max = 8.00; ui_step = 0.01; > = 1.00;

uniform float OSCO_GDR_DebugGamma
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 04 Views"; ui_category_closed = true; ui_label = "Debug Gamma"; ui_min = 0.10; ui_max = 4.00; ui_step = 0.01; > = 1.00;

uniform float OSCO_GDR_DebugFloor
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 04 Views"; ui_category_closed = true; ui_label = "Debug Floor"; ui_min = 0.00; ui_max = 0.50; ui_step = 0.005; > = 0.00;

uniform float OSCO_GDR_DebugThreshold
< ui_type = "slider"; ui_category = "OpenSurface / Camera Obscura / Guided Detail Reclamation / 04 Views"; ui_category_closed = true; ui_label = "Debug Threshold"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; > = 0.50;

float OSCO_GDR_SmoothRange(float edge0, float edge1, float value)
{
    float width = max(edge1 - edge0, 0.000001);
    float t = saturate((value - edge0) * OSCO_SafeRcp(width, 0.0));
    return t * t * (3.0 - 2.0 * t);
}

void OSCO_GDR_ConsiderTap(
    float2 requestedUv,
    float2 footprintHalfUv,
    float basisWeight,
    OSCO_RM_StabilityAuthority center,
    float centerLuma,
    float effectiveDepthProtect,
    float effectiveLumaProtect,
    inout float3 colorSum,
    inout float weightSum,
    inout float supportSum,
    inout float basisSum,
    inout float rawBoundaryLumaDifference)
{
    OSCO_RM_StabilityTapAddress address = OSCO_RM_BuildStabilityTapAddress(
        requestedUv,
        footprintHalfUv);
    float tapWeight = 0.0;
    float support = 0.0;
    float3 tapColor = 0.0.xxx;

    if (address.address_confidence > 0.0001)
    {
        OSCO_RM_DepthSample tapDepth = OSCO_RM_LoadLeanTapDepth(address.resolved_uv);
        float tapLuma;

        if (tapDepth.confidence > 0.0001)
        {
            tapColor = OSCO_RM_LoadColor(address.resolved_uv).rgb;
            tapLuma = OSCO_RM_Luma(tapColor);
            rawBoundaryLumaDifference = max(
                rawBoundaryLumaDifference,
                abs(tapLuma - centerLuma) * max(address.border_coverage, 0.25));
            support = OSCO_RM_StabilityTapSupport(
                center,
                centerLuma,
                tapLuma,
                tapDepth,
                address.address_confidence,
                effectiveDepthProtect,
                effectiveLumaProtect);
            tapWeight = basisWeight * support;
        }
    }

    colorSum += tapColor * tapWeight;
    weightSum += tapWeight;
    supportSum += support * basisWeight;
    basisSum += basisWeight * address.address_confidence;
}

float4 OSCO_GuidedDetailReclamation_PS(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float effectiveDepthProtect = OSCO_GDR_DepthProtect;
    float effectiveLumaProtect = OSCO_GDR_LumaProtect;
    float effectiveReadyStart = OSCO_GDR_ReadyStart;
    float effectiveReadyFull = OSCO_GDR_ReadyFull;
    float effectiveRadiusPixels = OSCO_GDR_RadiusPixels;
    float effectiveSupportStart = OSCO_GDR_SupportStart;
    float effectiveSupportFull = OSCO_GDR_SupportFull;
    float effectiveStrength = OSCO_GDR_Strength;
    float effectiveEdgeProtection = OSCO_GDR_EdgeProtection;
    float effectiveNoiseFloor = OSCO_GDR_NoiseFloor;
    float effectiveNoiseFull = OSCO_GDR_NoiseFull;
    float effectiveContributionCeiling = OSCO_GDR_ContributionCeiling;
    float effectiveMaskBoost = OSCO_GDR_MaskBoost;
    float effectiveShadowProtection = OSCO_GDR_ShadowProtection;
    float effectiveHighlightProtection = OSCO_GDR_HighlightProtection;

    if (OSCO_GDR_TuningTarget == 0)
    {
        effectiveDepthProtect = 0.00350;
        effectiveLumaProtect = 0.140;
        effectiveReadyStart = 0.12;
        effectiveReadyFull = 0.58;
        effectiveRadiusPixels = 1.00;
        effectiveSupportStart = 0.08;
        effectiveSupportFull = 0.42;
        effectiveStrength = 0.72;
        effectiveEdgeProtection = 0.82;
        effectiveNoiseFloor = 0.0025;
        effectiveNoiseFull = 0.0140;
        effectiveContributionCeiling = 0.065;
        effectiveMaskBoost = 1.00;
        effectiveShadowProtection = 1.00;
        effectiveHighlightProtection = 1.00;
    }
    else if (OSCO_GDR_TuningTarget == 1)
    {
        effectiveDepthProtect = 0.00350;
        effectiveLumaProtect = 0.140;
        effectiveReadyStart = 0.10;
        effectiveReadyFull = 0.52;
        effectiveRadiusPixels = 0.90;
        effectiveSupportStart = 0.10;
        effectiveSupportFull = 0.40;
        effectiveStrength = 0.48;
        effectiveEdgeProtection = 0.90;
        effectiveNoiseFloor = 0.0035;
        effectiveNoiseFull = 0.0160;
        effectiveContributionCeiling = 0.040;
        effectiveMaskBoost = 0.85;
        effectiveShadowProtection = 1.00;
        effectiveHighlightProtection = 1.00;
    }
    else if (OSCO_GDR_TuningTarget == 2)
    {
        effectiveDepthProtect = 0.00350;
        effectiveLumaProtect = 0.140;
        effectiveReadyStart = 0.11;
        effectiveReadyFull = 0.54;
        effectiveRadiusPixels = 1.10;
        effectiveSupportStart = 0.06;
        effectiveSupportFull = 0.30;
        effectiveStrength = 0.90;
        effectiveEdgeProtection = 0.82;
        effectiveNoiseFloor = 0.0018;
        effectiveNoiseFull = 0.0105;
        effectiveContributionCeiling = 0.075;
        effectiveMaskBoost = 1.30;
        effectiveShadowProtection = 0.95;
        effectiveHighlightProtection = 0.95;
    }
    else if (OSCO_GDR_TuningTarget == 3)
    {
        effectiveDepthProtect = 0.00320;
        effectiveLumaProtect = 0.125;
        effectiveReadyStart = 0.12;
        effectiveReadyFull = 0.48;
        effectiveRadiusPixels = 1.30;
        effectiveSupportStart = 0.04;
        effectiveSupportFull = 0.22;
        effectiveStrength = 1.20;
        effectiveEdgeProtection = 0.70;
        effectiveNoiseFloor = 0.0012;
        effectiveNoiseFull = 0.0085;
        effectiveContributionCeiling = 0.095;
        effectiveMaskBoost = 1.75;
        effectiveShadowProtection = 0.90;
        effectiveHighlightProtection = 0.88;
    }
    else if (OSCO_GDR_TuningTarget == 4)
    {
        effectiveDepthProtect = 0.00300;
        effectiveLumaProtect = 0.115;
        effectiveReadyStart = 0.10;
        effectiveReadyFull = 0.42;
        effectiveRadiusPixels = 1.35;
        effectiveSupportStart = 0.03;
        effectiveSupportFull = 0.16;
        effectiveStrength = 1.55;
        effectiveEdgeProtection = 0.52;
        effectiveNoiseFloor = 0.0009;
        effectiveNoiseFull = 0.0068;
        effectiveContributionCeiling = 0.145;
        effectiveMaskBoost = 2.20;
        effectiveShadowProtection = 0.82;
        effectiveHighlightProtection = 0.80;
    }
    else if (OSCO_GDR_TuningTarget == 5)
    {
        effectiveDepthProtect = 0.00380;
        effectiveLumaProtect = 0.150;
        effectiveReadyStart = 0.14;
        effectiveReadyFull = 0.62;
        effectiveRadiusPixels = 0.95;
        effectiveSupportStart = 0.12;
        effectiveSupportFull = 0.45;
        effectiveStrength = 0.55;
        effectiveEdgeProtection = 0.98;
        effectiveNoiseFloor = 0.0030;
        effectiveNoiseFull = 0.0180;
        effectiveContributionCeiling = 0.035;
        effectiveMaskBoost = 0.75;
        effectiveShadowProtection = 1.00;
        effectiveHighlightProtection = 1.00;
    }
    else if (OSCO_GDR_TuningTarget == 6)
    {
        effectiveDepthProtect = 0.00350;
        effectiveLumaProtect = 0.140;
        effectiveReadyStart = 0.02;
        effectiveReadyFull = 0.18;
        effectiveRadiusPixels = 1.50;
        effectiveSupportStart = 0.02;
        effectiveSupportFull = 0.12;
        effectiveStrength = 1.65;
        effectiveEdgeProtection = 0.55;
        effectiveNoiseFloor = 0.0006;
        effectiveNoiseFull = 0.0060;
        effectiveContributionCeiling = 0.130;
        effectiveMaskBoost = 2.40;
        effectiveShadowProtection = 0.80;
        effectiveHighlightProtection = 0.75;
    }

    float2 uvSafe = OSCO_RM_ClampUV(uv);
    float2 px = OSCO_RM_PixelSize() * max(effectiveRadiusPixels, 0.50);
    float2 footprintHalfUv = px * 0.5;
    float3 sourceColor = OSCO_RM_LoadColor(uvSafe).rgb;
    if (!OSCO_RM_HasDepth)
        return float4(sourceColor, 1.0);
    float sourceLuma = OSCO_RM_Luma(sourceColor);
    OSCO_RM_StabilityAuthority center = OSCO_RM_EvaluateStabilityAuthorityFast(
        uvSafe,
        sourceLuma,
        effectiveDepthProtect,
        effectiveLumaProtect);
    float centerAuthority = OSCO_RM_StabilityCenterAuthority(
        center.reuse_ready,
        center.depth_confidence,
        effectiveReadyStart,
        effectiveReadyFull);
    if (centerAuthority <= 0.0001)
        return float4(sourceColor, 1.0);

    float3 colorSum = 0.0.xxx;
    float weightSum = 0.0;
    float supportSum = 0.0;
    float basisSum = 0.0;
    float rawBoundaryLumaDifference = 0.0;

    OSCO_GDR_ConsiderTap(uvSafe - float2(px.x, 0.0), footprintHalfUv, 0.75, center, sourceLuma, effectiveDepthProtect, effectiveLumaProtect, colorSum, weightSum, supportSum, basisSum, rawBoundaryLumaDifference);
    OSCO_GDR_ConsiderTap(uvSafe + float2(px.x, 0.0), footprintHalfUv, 0.75, center, sourceLuma, effectiveDepthProtect, effectiveLumaProtect, colorSum, weightSum, supportSum, basisSum, rawBoundaryLumaDifference);
    OSCO_GDR_ConsiderTap(uvSafe - float2(0.0, px.y), footprintHalfUv, 0.75, center, sourceLuma, effectiveDepthProtect, effectiveLumaProtect, colorSum, weightSum, supportSum, basisSum, rawBoundaryLumaDifference);
    OSCO_GDR_ConsiderTap(uvSafe + float2(0.0, px.y), footprintHalfUv, 0.75, center, sourceLuma, effectiveDepthProtect, effectiveLumaProtect, colorSum, weightSum, supportSum, basisSum, rawBoundaryLumaDifference);

    // Use admitted neighbors as the comparison field instead of blending the
    // center pixel back into its own blur estimate. The previous formulation
    // self-damped single-pass response, which made the mask look active while
    // the final image barely moved unless the effect was stacked twice.
    float3 localAverage = (weightSum > 0.000001)
        ? (colorSum * OSCO_SafeRcp(weightSum, 0.0))
        : sourceColor;
    float localAverageLuma = OSCO_RM_Luma(localAverage);
    float detailLuma = sourceLuma - localAverageLuma;
    float detailEnergy = abs(detailLuma);

    float surfaceSupport = saturate(supportSum * OSCO_SafeRcp(max(basisSum, 0.000001), 0.0));
    float supportGate = OSCO_GDR_SmoothRange(
        effectiveSupportStart,
        max(effectiveSupportFull, effectiveSupportStart + 0.001),
        surfaceSupport);
    float detailGate = OSCO_GDR_SmoothRange(
        effectiveNoiseFloor,
        max(effectiveNoiseFull, effectiveNoiseFloor + 0.0005),
        detailEnergy);
    float harshEdgeSuppression = 1.0 - OSCO_GDR_SmoothRange(0.08, 0.24, rawBoundaryLumaDifference);
    float edgeGate = lerp(1.0, harshEdgeSuppression, saturate(effectiveEdgeProtection));
    float shadowRelease = OSCO_GDR_SmoothRange(0.015, 0.075, sourceLuma);
    float highlightRelease = 1.0 - OSCO_GDR_SmoothRange(0.88, 0.985, sourceLuma);
    float shadowGate = lerp(1.0, shadowRelease, saturate(effectiveShadowProtection));
    float highlightGate = lerp(1.0, highlightRelease, saturate(effectiveHighlightProtection));
    float hardMaskBlend = (OSCO_GDR_HardMask != 0) ? 1.0 : 0.0;
    float authorityBase = max(centerAuthority * supportGate, 0.0);
    float authorityGate = lerp(
        authorityBase,
        sqrt(authorityBase),
        hardMaskBlend);
    float carriedDetailGate = lerp(
        detailGate,
        lerp(detailGate, sqrt(max(detailGate, 0.0)), 0.45),
        hardMaskBlend);
    float protectionGate = min(edgeGate, min(shadowGate, highlightGate));
    float rawSharpnessMask = saturate(authorityGate * carriedDetailGate * protectionGate * max(effectiveMaskBoost, 0.0));
    float sharpnessMask = lerp(
        rawSharpnessMask,
        lerp(rawSharpnessMask, sqrt(max(rawSharpnessMask, 0.0)), 0.65),
        hardMaskBlend);

    float signedContribution = clamp(
        detailLuma * max(effectiveStrength, 0.0),
        -max(effectiveContributionCeiling, 0.0),
        max(effectiveContributionCeiling, 0.0));
    float appliedContribution = signedContribution * sharpnessMask;
    float3 finalColor = saturate(sourceColor + appliedContribution.xxx);
    float sourcePreserveDelta = saturate(OSCO_RM_Luma(abs(finalColor - sourceColor)) * 16.0);

    float3 outColor;
    if (OSCO_GDR_View == 1) outColor = center.reuse_ready.xxx;
    else if (OSCO_GDR_View == 2) outColor = center.depth_confidence.xxx;
    else if (OSCO_GDR_View == 3) outColor = center.neighbor_coverage.xxx;
    else if (OSCO_GDR_View == 4) outColor = surfaceSupport.xxx;
    else if (OSCO_GDR_View == 5) outColor = saturate(0.5.xxx + detailLuma.xxx * 8.0);
    else if (OSCO_GDR_View == 6) outColor = sharpnessMask.xxx;
    else if (OSCO_GDR_View == 7) outColor = saturate(abs(finalColor - sourceColor) * 12.0);
    else if (OSCO_GDR_View == 8) outColor = edgeGate.xxx;
    else if (OSCO_GDR_View == 9) outColor = sourcePreserveDelta.xxx;
    else return float4(finalColor, 1.0);

    outColor = OSCO_DebugVisibilityPost(
        outColor,
        OSCO_GDR_DebugPostMode,
        OSCO_GDR_DebugExposure,
        OSCO_GDR_DebugBias,
        OSCO_GDR_DebugContrast,
        OSCO_GDR_DebugGamma,
        OSCO_GDR_DebugFloor,
        OSCO_GDR_DebugThreshold);
    return float4(saturate(outColor), 1.0);
}

technique OSCO_GuidedDetailReclamation
<
    ui_label = "OpenSurface Camera Obscura Guided Detail Reclamation";
    ui_tooltip = "RGB-neutral signed lightness sharpness admitted by reuse readiness, depth confidence, and same-surface neighborhood support.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OSCO_GuidedDetailReclamation_PS;
    }
}


