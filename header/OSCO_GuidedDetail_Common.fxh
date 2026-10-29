#ifndef OSCO_GUIDED_DETAIL_COMMON_FXH
#define OSCO_GUIDED_DETAIL_COMMON_FXH 1

// OpenSurface Camera Obscura Guided Detail common runtime capsule.
// SPDX-License-Identifier: MIT
// Purpose: minimal dependency surface for Guided Detail Reclamation and Guided Ink Lines.

texture2D OSCO_RM_ColorTex : COLOR;
texture2D OSCO_RM_DepthTex : DEPTH;

sampler2D OSCO_RM_ColorSampler
{
    Texture = OSCO_RM_ColorTex;
    AddressU = CLAMP;
    AddressV = CLAMP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = POINT;
};

sampler2D OSCO_RM_DepthSampler
{
    Texture = OSCO_RM_DepthTex;
    AddressU = CLAMP;
    AddressV = CLAMP;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
};

uniform bool OSCO_RM_HasDepth < source = "bufready_depth"; >;

uniform int OSCO_RM_DepthReverseMode
<
    ui_type = "combo";
    ui_label = "OSCO Depth Reverse Mode";
    ui_items = "Use ReShade Setting\0Force Normal\0Force Reversed\0";
    ui_tooltip = "Runtime override for depth orientation. Use ReShade Setting follows RESHADE_DEPTH_INPUT_IS_REVERSED.";
> = 0;

uniform float OSCO_RM_DepthSkyThreshold
<
    ui_type = "slider";
    ui_label = "OSCO Sky Depth Threshold";
    ui_min = 0.800; ui_max = 1.000; ui_step = 0.001;
    ui_tooltip = "Linear-depth threshold treated as sky/far plane.";
> = 0.985;

uniform float OSCO_RM_DepthEdgeScale
<
    ui_type = "slider";
    ui_label = "OSCO Depth Edge Scale";
    ui_min = 0.0001; ui_max = 0.0500; ui_step = 0.0001;
    ui_tooltip = "Normalizes local depth discontinuity into the stability edge-reject mask.";
> = 0.0060;

struct OSCO_RM_DepthSample
{
    float raw;
    float linear01;
    float confidence;
    float edge;
    float sky;
    float empty_like;
};

struct OSCO_RM_StabilityTapAddress
{
    float2 requested_uv;
    float2 resolved_uv;
    float2 footprint_half_uv;
    float requested_in_bounds;
    float resolved_in_bounds;
    float address_valid;
    float independent_evidence;
    float border_coverage;
    float remapped;
    float duplicate_axis_count;
    float address_confidence;
};

struct OSCO_RM_StabilityAuthority
{
    float depth_linear01;
    float depth_confidence;
    float depth_edge;
    float neighbor_coverage;
    float depth_agreement;
    float normal_profile;
    float luma_agreement;
    float stability;
    float reuse_ready;
};

float OSCO_SafeRcp(float value, float fallbackValue)
{
    return (abs(value) > 1.0e-6) ? (1.0 / value) : fallbackValue;
}

float2 OSCO_RM_PixelSize()
{
    return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
}

float2 OSCO_RM_ClampUV(float2 uv)
{
    return clamp(uv, float2(0.0, 0.0), float2(1.0, 1.0));
}

float4 OSCO_RM_LoadColor(float2 uv)
{
    return tex2Dlod(OSCO_RM_ColorSampler, float4(OSCO_RM_ClampUV(uv), 0.0, 0.0));
}

float OSCO_RM_LoadDepthRaw(float2 uv)
{
    return tex2Dlod(OSCO_RM_DepthSampler, float4(OSCO_RM_ClampUV(uv), 0.0, 0.0)).r;
}

float OSCO_RM_Luma(float3 rgb)
{
    return dot(rgb, float3(0.2126, 0.7152, 0.0722));
}

float OSCO_RM_DepthUseReversedForMode(int depthMode)
{
    float useReversed = 0.0;
#if RESHADE_DEPTH_INPUT_IS_REVERSED
    useReversed = 1.0;
#endif
    int mode = depthMode;
    mode = (mode == 0) ? OSCO_RM_DepthReverseMode : mode;
    useReversed = (mode == 1) ? 0.0 : useReversed;
    useReversed = (mode == 2) ? 1.0 : useReversed;
    return saturate(useReversed);
}

float OSCO_RM_ConfiguredDepthMode(float rawDepth, int depthMode)
{
    float d = saturate(rawDepth);
    float useReversed = OSCO_RM_DepthUseReversedForMode(depthMode);
    d = lerp(d, 1.0 - d, useReversed);
    return saturate(d);
}

float OSCO_RM_LinearDepth01FromRawMode(float rawDepth, int depthMode)
{
    float d = OSCO_RM_ConfiguredDepthMode(rawDepth, depthMode);
    float farPlane = max((float)RESHADE_DEPTH_LINEARIZATION_FAR_PLANE, 1.0);
    float denom = d * (1.0 - farPlane) + farPlane;
    return saturate(OSCO_SafeRcp(denom, 0.0));
}

float OSCO_RM_LinearDepth01FromRaw(float rawDepth)
{
    return OSCO_RM_LinearDepth01FromRawMode(rawDepth, 0);
}

float OSCO_RM_ResolveDepthAgreement(float centerDepth, float tapDepth, float edgeProtect)
{
    float safeProtect = max(edgeProtect, 0.000001);
    return saturate(1.0 - abs(centerDepth - tapDepth) * OSCO_SafeRcp(safeProtect, 0.0));
}

float OSCO_RM_TemporalLumaAgreement1(float centerLuma, float tapLuma, OSCO_RM_DepthSample tap, float protect)
{
    float safeProtect = max(protect, 0.000001);
    float agree = saturate(1.0 - abs(centerLuma - tapLuma) * OSCO_SafeRcp(safeProtect, 0.0));
    return agree * step(0.0001, tap.confidence);
}

float OSCO_RM_SoftNormalPreference(float normalGate)
{
    float g = saturate(normalGate);
    return g * g * (3.0 - 2.0 * g);
}

float OSCO_RM_StabilityTapInBounds(float2 uv)
{
    return
        step(0.0, uv.x) * step(uv.x, 1.0) *
        step(0.0, uv.y) * step(uv.y, 1.0);
}

float OSCO_RM_StabilityAxisCoverage(float requested, float footprintHalf)
{
    float coverage = 0.0;
    float halfWidth = abs(footprintHalf);

    if (halfWidth <= 0.000001)
    {
        coverage = step(0.0, requested) * step(requested, 1.0);
    }
    else
    {
        float low = requested - halfWidth;
        float high = requested + halfWidth;
        float overlap = max(0.0, min(high, 1.0) - max(low, 0.0));
        coverage = saturate(overlap / max(2.0 * halfWidth, 0.000001));
    }

    return coverage;
}

OSCO_RM_StabilityTapAddress OSCO_RM_BuildStabilityTapAddress(float2 requestedUv, float2 footprintHalfUv)
{
    OSCO_RM_StabilityTapAddress address;
    float2 safeFootprint = abs(footprintHalfUv);
    float coverageX = OSCO_RM_StabilityAxisCoverage(requestedUv.x, safeFootprint.x);
    float coverageY = OSCO_RM_StabilityAxisCoverage(requestedUv.y, safeFootprint.y);
    float duplicateX = 1.0 - step(0.999999, coverageX);
    float duplicateY = 1.0 - step(0.999999, coverageY);

    address.requested_uv = requestedUv;
    address.resolved_uv = OSCO_RM_ClampUV(requestedUv);
    address.footprint_half_uv = safeFootprint;
    address.requested_in_bounds = OSCO_RM_StabilityTapInBounds(requestedUv);
    address.resolved_in_bounds = OSCO_RM_StabilityTapInBounds(address.resolved_uv);
    address.address_valid = address.resolved_in_bounds;
    address.independent_evidence = address.requested_in_bounds;
    address.border_coverage = saturate(coverageX * coverageY);
    address.remapped = step(0.000001, max(abs(address.resolved_uv.x - requestedUv.x), abs(address.resolved_uv.y - requestedUv.y)));
    address.duplicate_axis_count = duplicateX + duplicateY;
    address.address_confidence = saturate(address.address_valid * address.independent_evidence * address.border_coverage);
    return address;
}

OSCO_RM_DepthSample OSCO_RM_LoadLeanTapDepth(float2 uv)
{
    OSCO_RM_DepthSample o;
    float2 safeUv = OSCO_RM_ClampUV(uv);

    o.raw = OSCO_RM_LoadDepthRaw(safeUv);
    o.linear01 = OSCO_RM_LinearDepth01FromRaw(o.raw);
    o.sky = (o.linear01 >= OSCO_RM_DepthSkyThreshold) ? 1.0 : 0.0;
    o.confidence = (OSCO_RM_HasDepth ? 1.0 : 0.0) * (1.0 - o.sky);
    o.edge = 0.0;
    o.empty_like = 0.0;
    return o;
}

OSCO_RM_DepthSample OSCO_RM_MakeDeniedLeanTapDepth()
{
    OSCO_RM_DepthSample o;
    o.raw = 0.0;
    o.linear01 = 0.0;
    o.confidence = 0.0;
    o.edge = 0.0;
    o.sky = 1.0;
    o.empty_like = 1.0;
    return o;
}

float OSCO_RM_StabilityTapAvailability(OSCO_RM_StabilityTapAddress address, OSCO_RM_DepthSample tapDepth)
{
    return address.address_confidence * step(0.0001, tapDepth.confidence);
}

OSCO_RM_StabilityAuthority OSCO_RM_EvaluateStabilityAuthorityFast(float2 uv, float centerLuma, float depthProtect, float lumaProtect)
{
    OSCO_RM_StabilityAuthority o;
    float2 uvSafe = OSCO_RM_ClampUV(uv);
    OSCO_RM_DepthSample centerDepth = OSCO_RM_LoadLeanTapDepth(uvSafe);
    o.depth_linear01 = centerDepth.linear01;
    o.depth_edge = 0.0;
    o.depth_confidence = centerDepth.confidence;
    o.neighbor_coverage = 0.0;
    o.depth_agreement = 0.0;
    o.normal_profile = 0.0;
    o.luma_agreement = 0.0;
    o.stability = 0.0;
    o.reuse_ready = 0.0;

    if (centerDepth.confidence <= 0.0001)
        return o;

    float2 px = OSCO_RM_PixelSize();
    float2 footprintHalfUv = px * 0.5;
    OSCO_RM_StabilityTapAddress aL = OSCO_RM_BuildStabilityTapAddress(uvSafe - float2(px.x, 0.0), footprintHalfUv);
    OSCO_RM_StabilityTapAddress aR = OSCO_RM_BuildStabilityTapAddress(uvSafe + float2(px.x, 0.0), footprintHalfUv);
    OSCO_RM_StabilityTapAddress aU = OSCO_RM_BuildStabilityTapAddress(uvSafe - float2(0.0, px.y), footprintHalfUv);
    OSCO_RM_StabilityTapAddress aD = OSCO_RM_BuildStabilityTapAddress(uvSafe + float2(0.0, px.y), footprintHalfUv);
    OSCO_RM_DepthSample dL = OSCO_RM_MakeDeniedLeanTapDepth();
    OSCO_RM_DepthSample dR = OSCO_RM_MakeDeniedLeanTapDepth();
    OSCO_RM_DepthSample dU = OSCO_RM_MakeDeniedLeanTapDepth();
    OSCO_RM_DepthSample dD = OSCO_RM_MakeDeniedLeanTapDepth();
    float lL = centerLuma;
    float lR = centerLuma;
    float lU = centerLuma;
    float lD = centerLuma;
    float tapAvailL = 0.0;
    float tapAvailR = 0.0;
    float tapAvailU = 0.0;
    float tapAvailD = 0.0;

    if (aL.address_confidence > 0.0001) { dL = OSCO_RM_LoadLeanTapDepth(aL.resolved_uv); tapAvailL = OSCO_RM_StabilityTapAvailability(aL, dL); }
    if (aR.address_confidence > 0.0001) { dR = OSCO_RM_LoadLeanTapDepth(aR.resolved_uv); tapAvailR = OSCO_RM_StabilityTapAvailability(aR, dR); }
    if (aU.address_confidence > 0.0001) { dU = OSCO_RM_LoadLeanTapDepth(aU.resolved_uv); tapAvailU = OSCO_RM_StabilityTapAvailability(aU, dU); }
    if (aD.address_confidence > 0.0001) { dD = OSCO_RM_LoadLeanTapDepth(aD.resolved_uv); tapAvailD = OSCO_RM_StabilityTapAvailability(aD, dD); }

    float activeTapWeight = tapAvailL + tapAvailR + tapAvailU + tapAvailD;
    float activeTapNorm = max(activeTapWeight, 1.0);
    float neighborCoverage = saturate(activeTapWeight * 0.25);
    o.neighbor_coverage = neighborCoverage;

    float edgeRaw = max(
        max(abs(o.depth_linear01 - dL.linear01) * tapAvailL, abs(o.depth_linear01 - dR.linear01) * tapAvailR),
        max(abs(o.depth_linear01 - dU.linear01) * tapAvailU, abs(o.depth_linear01 - dD.linear01) * tapAvailD));
    o.depth_edge = saturate(edgeRaw * OSCO_SafeRcp(max(OSCO_RM_DepthEdgeScale, 0.000001), 0.0));
    o.depth_confidence = saturate(centerDepth.confidence * (1.0 - o.depth_edge));

    if ((o.depth_confidence <= 0.0001) || (activeTapWeight <= 0.0001))
        return o;

    if (tapAvailL > 0.0001) lL = OSCO_RM_Luma(OSCO_RM_LoadColor(aL.resolved_uv).rgb);
    if (tapAvailR > 0.0001) lR = OSCO_RM_Luma(OSCO_RM_LoadColor(aR.resolved_uv).rgb);
    if (tapAvailU > 0.0001) lU = OSCO_RM_Luma(OSCO_RM_LoadColor(aU.resolved_uv).rgb);
    if (tapAvailD > 0.0001) lD = OSCO_RM_Luma(OSCO_RM_LoadColor(aD.resolved_uv).rgb);

    o.depth_agreement = saturate((
        OSCO_RM_ResolveDepthAgreement(o.depth_linear01, dL.linear01, depthProtect) * tapAvailL +
        OSCO_RM_ResolveDepthAgreement(o.depth_linear01, dR.linear01, depthProtect) * tapAvailR +
        OSCO_RM_ResolveDepthAgreement(o.depth_linear01, dU.linear01, depthProtect) * tapAvailU +
        OSCO_RM_ResolveDepthAgreement(o.depth_linear01, dD.linear01, depthProtect) * tapAvailD)
        * OSCO_SafeRcp(activeTapNorm, 0.0));
    o.luma_agreement = saturate((
        OSCO_RM_TemporalLumaAgreement1(centerLuma, lL, dL, lumaProtect) * tapAvailL +
        OSCO_RM_TemporalLumaAgreement1(centerLuma, lR, dR, lumaProtect) * tapAvailR +
        OSCO_RM_TemporalLumaAgreement1(centerLuma, lU, dU, lumaProtect) * tapAvailU +
        OSCO_RM_TemporalLumaAgreement1(centerLuma, lD, dD, lumaProtect) * tapAvailD)
        * OSCO_SafeRcp(activeTapNorm, 0.0));

    float normalProxy = saturate(max(1.0 - o.depth_edge, o.depth_agreement * 0.85));
    o.normal_profile = OSCO_RM_SoftNormalPreference(normalProxy);
    float agreementMean = saturate((o.depth_agreement + normalProxy + o.luma_agreement) * 0.333333);
    o.stability = saturate(agreementMean * saturate((o.depth_confidence + neighborCoverage) * 0.5));
    o.reuse_ready = saturate(o.stability * saturate(1.0 - o.depth_edge));
    return o;
}

float OSCO_RM_StabilityCenterAuthority(float reuseReady, float depthConfidence, float readyStart, float readyFull)
{
    float safeFull = max(readyFull, readyStart + 0.001);
    float width = max(safeFull - readyStart, 0.000001);
    float t = saturate((reuseReady - readyStart) * OSCO_SafeRcp(width, 0.0));
    float smoothReady = t * t * (3.0 - 2.0 * t);
    return saturate(smoothReady * max(depthConfidence, 0.0));
}

float OSCO_RM_StabilityCenterNormalProfile(OSCO_RM_StabilityAuthority center)
{
    return center.normal_profile;
}

float OSCO_RM_StabilityTapSupport(
    OSCO_RM_StabilityAuthority center,
    float centerLuma,
    float tapLuma,
    OSCO_RM_DepthSample tapDepth,
    float addressConfidence,
    float depthProtect,
    float lumaProtect)
{
    float depthAgreement = OSCO_RM_ResolveDepthAgreement(center.depth_linear01, tapDepth.linear01, depthProtect);
    float normalAgreement = OSCO_RM_StabilityCenterNormalProfile(center);
    float lumaAgreement = OSCO_RM_TemporalLumaAgreement1(centerLuma, tapLuma, tapDepth, lumaProtect);
    return saturate(addressConfidence * tapDepth.confidence * depthAgreement * normalAgreement * lumaAgreement);
}

#endif // OSCO_GUIDED_DETAIL_COMMON_FXH
