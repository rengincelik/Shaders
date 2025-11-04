Shader "Custom/OrganicTextureMorph"
{
    Properties
    {
        _TexA ("Texture A", 2D) = "white" {}
        _TexB ("Texture B", 2D) = "white" {}
        _Speed ("Morph Speed", Range(0,5)) = 1
        _WarpIntensity ("Warp Intensity", Range(0,1)) = 0.25
        _NoiseScale ("Noise Scale", Range(0,10)) = 4
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off

        Pass
        {
            Name "TextureMorph"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _TexA;
            sampler2D _TexB;
            float4 _TexA_ST;
            float4 _TexB_ST;
            float _Speed;
            float _WarpIntensity;
            float _NoiseScale;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uvA : TEXCOORD0;
                float2 uvB : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uvA = TRANSFORM_TEX(v.uv, _TexA);
                o.uvB = TRANSFORM_TEX(v.uv, _TexB);
                return o;
            }

            // basit hash + noise fonksiyonu
            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(12.9898,78.233))) * 43758.5453);
            }

            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float a = hash(i);
                float b = hash(i + float2(1,0));
                float c = hash(i + float2(0,1));
                float d = hash(i + float2(1,1));
                float2 u = f * f * (3.0 - 2.0*f);
                return lerp(lerp(a,b,u.x), lerp(c,d,u.x), u.y);
            }

            float4 frag (v2f i) : SV_Target
            {
                float time = _Time.y * _Speed;

                // UV warp
                float2 warp;
                warp.x = noise(i.uvA * _NoiseScale + time);
                warp.y = noise(i.uvA * _NoiseScale - time);
                warp = (warp - 0.5) * _WarpIntensity;

                float2 warpedUVA = i.uvA + warp;
                float2 warpedUVB = i.uvB + warp * 1.1;

                // morph oranı
                float t = 0.5 + 0.5 * sin(time);
                float4 colA = tex2D(_TexA, warpedUVA);
                float4 colB = tex2D(_TexB, warpedUVB);
                float4 col = lerp(colA, colB, t);

                col.a = 1;
                return col;
            }
            ENDHLSL
        }
    }
}
