Shader "BasicLit/AdvancedSurfaceSlider"
{
    Properties
    {
        _BaseColor ("Color", Color) = (1,1,1,1)
        
        [Header(Glossy Settings)]
        [Space(10)]
        [Range(0,1)] _Metallic ("Metallic", Float) = 0.0
        [Range(0,1)] _Smoothness ("Smoothness", Float) = 0.5
        [Range(1,100)] _SpecularPower ("Specular Power", Float) = 20
        
        [Header(Roughness Settings)]
        [Space(10)]
        [Range(0,1)] _Roughness ("Roughness Amount", Float) = 0.5
        [Range(0,2)] _RoughnessEffect ("Roughness Effect", Float) = 1.0
        [Range(0.1,2.0)] _RoughnessScale ("Roughness Scale", Float) = 0.5
        [Range(0,2)] _RoughnessIntensity ("Roughness Intensity", Float) = 1.0
        
        [Header(Roughness Mode)]
        [Space(10)]
        [Toggle(_FLATSURFACE_ON)] _FlatSurface ("Flat Surface Mode", Float) = 0
        [Range(0.1,5.0)] _NoiseFrequency ("Noise Frequency", Float) = 2.0
        [Range(0,1)] _NoiseAmplitude ("Noise Amplitude", Float) = 0.6
        
        [Header(Matt Settings)]
        [Space(10)]
        [Range(0,2)] _DiffusePower ("Diffuse Power", Float) = 1.0
        [Range(0,1)] _MatteEffect ("Matte Effect", Float) = 0.0
        
        [Header(Extra Controls)]
        [Space(10)]
        [Range(0,1)] _AmbientIntensity ("Ambient Light", Float) = 0.5
        [Range(0,1)] _ShadowIntensity ("Shadow Intensity", Float) = 1.0
    }
    SubShader
    {
        Tags { 
            "RenderPipeline"="UniversalPipeline" 
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fog
            #pragma shader_feature _FLATSURFACE_ON
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : NORMAL;
                float3 positionWS : TEXCOORD0;
                float3 viewDirWS : TEXCOORD1;
                half fogCoord : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _Metallic;
                half _Smoothness;
                half _SpecularPower;
                half _Roughness;
                half _RoughnessEffect;
                half _RoughnessScale;
                half _RoughnessIntensity;
                half _DiffusePower;
                half _MatteEffect;
                half _NoiseFrequency;
                half _NoiseAmplitude;
                half _AmbientIntensity;
                half _ShadowIntensity;
            CBUFFER_END

            // Simple noise function
            half SimpleNoise(half3 position)
            {
                return frac(sin(dot(position, half3(12.9898, 78.233, 45.543))) * 43758.5453);
            }

            // Multi-layer noise for organic look
            half MultiLayerNoise(half3 position, half3 normal)
            {
                half noise = 0.0;
                half frequency = _NoiseFrequency;
                half amplitude = _NoiseAmplitude;
                half persistence = 0.5;
                
                // 3 layers of noise
                for (int i = 0; i < 3; i++)
                {
                    noise += SimpleNoise(position * frequency) * amplitude;
                    frequency *= 2.0;
                    amplitude *= persistence;
                }
                
                return noise * 2.0 - 1.0;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS);
                
                OUT.positionHCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                OUT.normalWS = normalInput.normalWS;
                OUT.viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                OUT.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Normalized normal and view direction
                half3 normal = normalize(IN.normalWS);
                half3 viewDir = normalize(IN.viewDirWS);
                
                // Main light with shadows
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                // Apply shadow intensity
                mainLight.color *= _ShadowIntensity;
                
                // ROUGHNESS CALCULATION
                half3 finalNormal = normal;
                half roughnessNoise = 0.0;
                
                #ifdef _FLATSURFACE_ON
                    // FLAT SURFACE MODE - Subtle effect
                    roughnessNoise = SimpleNoise(IN.positionWS * _RoughnessScale) * _RoughnessEffect;
                    finalNormal = normalize(normal + roughnessNoise * _Roughness * 0.3);
                #else
                    // SPHERICAL MODE - Strong organic effect
                    roughnessNoise = MultiLayerNoise(IN.positionWS * _RoughnessScale, normal) * _RoughnessEffect;
                    finalNormal = normalize(normal + roughnessNoise * _Roughness);
                #endif
                
                finalNormal = lerp(normal, finalNormal, _Roughness * _RoughnessIntensity);
                
                // LIGHTING CALCULATIONS
                half NdotL = saturate(dot(finalNormal, mainLight.direction));
                
                // Matte effect
                NdotL = lerp(NdotL, pow(NdotL, 1.0 + _MatteEffect * 3.0), _MatteEffect);
                half3 diffuse = mainLight.color * NdotL * _DiffusePower;
                
                // SPECULAR
                half3 halfVec = normalize(mainLight.direction + viewDir);
                half NdotH = saturate(dot(finalNormal, halfVec));
                
                half smoothnessWithRoughness = _Smoothness * (1.0 - _Roughness * 0.5);
                half specular = pow(NdotH, _SpecularPower * smoothnessWithRoughness + 1.0);
                
                // Metallic effect
                half3 specularColor = lerp(half3(1,1,1), _BaseColor.rgb, _Metallic);
                half3 specularLight = specular * mainLight.color * specularColor;
                
                // FINAL COLOR
                half3 finalColor = _BaseColor.rgb * diffuse + specularLight;
                
                // Ambient light
                finalColor += unity_AmbientSky.rgb * _BaseColor.rgb * _AmbientIntensity;
                
                // Fog
                finalColor = MixFog(finalColor, IN.fogCoord);
                
                return half4(finalColor, _BaseColor.a);
            }
            ENDHLSL
        }
        
        // Shadow pass
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Lit"
}
