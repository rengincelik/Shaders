
Shader "Custom/URPWaterLit_Noise"
{
    Properties
    {
        _WaveHeight("Wave Height", Range(0,1)) = 0.1
        _WaveSpeed("Wave Speed", Range(0,5)) = 1
        _ColorShallow("Shallow Color", Color) = (0.3,0.6,1,1)
        _ColorDeep("Deep Color", Color) = (0.0,0.1,0.3,1)
        _Smoothness("Smoothness", Range(0,1)) = 0.5
        _SpecularStrength("Specular Strength", Range(0,1)) = 0.3
        _ReflectionStrength("Reflection Strength", Range(0,1)) = 0.2
        _NoiseScale("Noise Scale", Range(0,1)) = 1.0
        _NoiseAmplitude("Noise Amplitude", Range(0,1)) = 0.2
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 200

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 posCS : SV_POSITION;
                float3 posWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float height : TEXCOORD2;
            };

            float _WaveHeight;
            float _WaveSpeed;
            float4 _ColorShallow;
            float4 _ColorDeep;
            float _Smoothness;
            float _SpecularStrength;
            float _ReflectionStrength;
            float _NoiseScale;
            float _NoiseAmplitude;

            //----------------------------------------
            // Perlin Noise (2D)
            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1,311.7))) * 43758.5453);
            }

            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                // 4 corner hashes
                float a = hash(i);
                float b = hash(i + float2(1,0));
                float c = hash(i + float2(0,1));
                float d = hash(i + float2(1,1));

                // Smooth interpolation
                float2 u = f*f*(3.0-2.0*f);
                return lerp(a, b, u.x) + (lerp(c, d, u.x) - lerp(a,b,u.x)) * u.y;
            }

            //----------------------------------------
            // Dalga yüksekliği
            float GetWave(float3 pos)
            {
                float raw = sin(_Time.y * _WaveSpeed + pos.x * 3.1415)
                          + cos(_Time.y * _WaveSpeed + pos.z * 3.1415);

                float t = (raw + 2.0)/4.0;
                t = sin(t * 3.1415 * 0.5);

                float yOffset = t * _WaveHeight * 2.0 - _WaveHeight;

                // Noise ile rastgele dalga yüksekliği
                float n = noise(pos.xz * _NoiseScale + _Time.y * 0.1);
                yOffset += (n - 0.5) * _NoiseAmplitude;

                return yOffset;
            }

            float3 GetWaveNormal(float3 pos)
            {
                float eps = 0.01;
                float hL = GetWave(pos + float3(-eps,0,0));
                float hR = GetWave(pos + float3( eps,0,0));
                float hD = GetWave(pos + float3(0,0,-eps));
                float hU = GetWave(pos + float3(0,0, eps));

                return normalize(float3(hL - hR, 2*eps, hD - hU));
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 pos = IN.positionOS.xyz;
                float yOffset = GetWave(pos);
                pos.y += yOffset;

                OUT.posWS = TransformObjectToWorld(pos);
                OUT.posCS = TransformWorldToHClip(OUT.posWS);
                OUT.normalWS = GetWaveNormal(pos);
                OUT.height = yOffset;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Base color
                float t = saturate((IN.height + _WaveHeight)/(_WaveHeight*2));
                float3 baseColor = lerp(_ColorDeep.rgb, _ColorShallow.rgb, t);

                // Main light
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float3 lightColor = mainLight.color;

                float NdotL = saturate(dot(IN.normalWS, lightDir));
                float3 diffuse = baseColor * NdotL * lightColor;

                float3 viewDir = normalize(_WorldSpaceCameraPos - IN.posWS);
                float3 halfDir = normalize(lightDir + viewDir);
                float spec = pow(saturate(dot(IN.normalWS, halfDir)), 16) * _SpecularStrength;

                // Fake reflection / Fresnel
                float fresnel = pow(1 - saturate(dot(viewDir, IN.normalWS)), 3);
                float3 finalColor = diffuse + spec + fresnel * _ReflectionStrength;

                return float4(finalColor, 1);
            }

            ENDHLSL
        }
    }
}
