Shader "Raymarching/uRaymarchingGears"
{

    Properties
    {
        [Header(PBS)]
        _Color ("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.5
        _Glossiness ("Smoothness", Range(0.0, 1.0)) = 0.5

        [Header(Pass)]
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Culling", Int) = 2

        [Header(Raymarching)]
        _Loop ("Loop", Range(1, 100)) = 30
        _MinDistance ("Minimum Distance", Range(0.001, 0.1)) = 0.01
        _DistanceMultiplier ("Distance Multiplier", Range(0.001, 2.0)) = 1.0

        [PowerSlider(10.0)] _NormalDelta ("NormalDelta", Range(0.00001, 0.1)) = 0.0001

        // @block Properties
        [Header(Gear)]
        _GearFoldRotate ("Gear Fold Rotate", Range(1, 20)) = 6
        [HDR] _EmissionColor ("Emission Color", Color) = (1, 1, 1, 1)
        _EmissionY ("Emission Y", Float) = 0
        _GearRepeat ("Gear Repeat", Vector) = (10, 10, 10, 1)
        _BoxASize ("Box A Size", Vector) = (1, 4, 1, 1)
        _BoxAMove ("Box A Move", Vector) = (1, 1, 1, 1)
        _BoxBRepeat ("Box B Repeat", Range(0, 2)) = 0.2
        _BoxBSize ("Box B Size", Vector) = (1, 4, 1, 1)
        _BoxBMove ("Box B Move", Vector) = (1, 1, 1, 1)

        [Header(Pillar)]
        _PillarFoldRotate ("Pillar Fold Rotate", Range(1, 20)) = 3
        _PillarRepeat ("Pillar Repeat", Vector) = (100, 2, 100, 1)
        _PillarSize ("Pillar Size", Vector) = (0.67, 0.11, 3.77, 1)
        _PillarMove ("Pillar Move", Vector) = (0, 0, 0, 1)
        // @endblock
    }

    SubShader
    {

        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" "DisableBatching" = "True" }

        Cull [_Cull]

        CGINCLUDE

        #define FULL_SCREEN

        #define WORLD_SPACE

        #define OBJECT_SHAPE_NONE

        #define CAMERA_INSIDE_OBJECT

        #define USE_RAYMARCHING_DEPTH

        #define SPHERICAL_HARMONICS_PER_PIXEL

        #define DISTANCE_FUNCTION DistanceFunction
        #define POST_EFFECT PostEffect
        #define PostEffectOutput SurfaceOutputStandard

        #include "Assets\uRaymarching\Shaders\Include\Legacy/Common.cginc"

        // @block DistanceFunction
        #define TAU 6.28318530718

        float sdBox(float3 p, float3 b)
        {
            float3 q = abs(p) - b;
            return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
        }

        // 2D????????????????????????????????????
        float2x2 rotate(float a)
        {
            float s = sin(a), c = cos(a);
            return float2x2(c, s, -s, c);
        }

        // ??????????????????????????????????????????????????????????????????
        float2 foldRotate(float2 p, float n)
        {
            float a = PI / n - atan2(p.x, p.y);
            float b = TAU / n;
            a = floor(a / b) * b;
            p = mul(rotate(a), p);
            return p;
        }

        float opRepLim(float p, float c, float l)
        {
            return p - c * clamp(round(p / c), -l, l);
        }

        float _GearFoldRotate;
        float3 _GearRepeat;

        float3 _BoxASize;
        float3 _BoxAMove;

        float _BoxBRepeat;
        float3 _BoxBSize;
        float3 _BoxBMove;

        float _PillarFoldRotate;
        float3 _PillarRepeat;
        float3 _PillarSize;
        float3 _PillarMove;

        float dGearA(float3 p)
        {
            p = Repeat(p, _GearRepeat);
            p.xz = foldRotate(p.xz, _GearFoldRotate);
            p = abs(p);
            p -= _BoxAMove;

            return sdBox(p, _BoxASize);
        }

        float dGearB(float3 p)
        {
            p = Repeat(p, _GearRepeat);
            p.xz = foldRotate(p.xz, _GearFoldRotate);
            p = abs(p);
            p -= _BoxAMove;
            p.y = opRepLim(p.y, _BoxBRepeat, 5);
            p -= _BoxBMove;
            
            return sdBox(p, _BoxBSize);
        }

        float dPillar(float3 p)
        {
            p = Repeat(p, _PillarRepeat);
            p.xz = foldRotate(p.xz, _PillarFoldRotate);
            p = abs(p);
            p -= _PillarMove;

            return sdBox(p, _PillarSize);
        }

        inline float DistanceFunction(float3 p)
        {
            // ??????
            float d = dGearA(p);
            d = min(d, dGearB(p));

            // ???
            d = min(d, dPillar(p));

            return d;
        }
        // @endblock

        // @block PostEffect
        half4 _EmissionColor;
        float _EmissionY;

        inline void PostEffect(RaymarchInfo ray, inout PostEffectOutput o)
        {
            float3 p = ray.endPos;

            // GearA???Emission??????
            if (dGearA(p) < ray.minDistance && (Mod(p.y, _GearRepeat.y) - _EmissionY) < 0.2)
            {
                o.Emission = _EmissionColor;
            }

            // GearB???Emission??????
            if (dGearB(p) < ray.minDistance && abs(o.Normal.y) < 0.1)
            {
                o.Emission = _EmissionColor;
            }

            // Pillar????????????????????????
            if (dPillar(p) < ray.minDistance)
            {
                o.Smoothness = 0.95;
                o.Metallic = 1;
                o.Occlusion = 0;
                o.Albedo = half3(1, 1, 1);
            }
        }
        // @endblock
        
        ENDCG

        Pass
        {
            Tags { "LightMode" = "Deferred" }

            Stencil
            {
                Comp Always
                Pass Replace
                Ref 128
            }
            
            CGPROGRAM

            #include "Assets\uRaymarching\Shaders\Include\Legacy/DeferredStandard.cginc"
            #pragma target 3.0
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma exclude_renderers nomrt
            #pragma multi_compile_prepassfinal
            #pragma multi_compile ___ UNITY_HDR_ON
            ENDCG

        }
    }

    Fallback Off

    CustomEditor "uShaderTemplate.MaterialEditor"
}