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
// Shader "BasicLit/AdvancedSurface"
// {
//     Properties
//     {
//         _BaseColor ("Color", Color) = (1,1,1,1)
        
//         [Header(Glossy Settings)]
//         [Space(10)]
//         _Metallic ("Metallic", Range(0,1)) = 0.0
//         _Smoothness ("Smoothness", Range(0,1)) = 0.5
//         _SpecularPower ("Specular Power", Range(1,100)) = 20
        
//         [Header(Roughness Settings)]
//         [Space(10)]
//         _Roughness ("Roughness", Range(0,1)) = 0.5
//         _RoughnessEffect ("Roughness Effect", Range(0,2)) = 1.0
//         _RoughnessScale ("Roughness Scale", Range(0.1, 2.0)) = 0.5
        
//         [Header(Matt Settings)]
//         [Space(10)]
//         _DiffusePower ("Diffuse Power", Range(0,2)) = 1.0
//         _MatteEffect ("Matte Effect", Range(0,1)) = 0.0
//     }
//     SubShader
//     {
//         Tags { 
//             "RenderPipeline"="UniversalPipeline" 
//             "RenderType"="Opaque"
//             "Queue"="Geometry"
//         }

//         LOD 100

//         Pass
//         {
//             Name "ForwardLit"
//             Tags { "LightMode"="UniversalForward" }

//             HLSLPROGRAM
//             #pragma vertex vert
//             #pragma fragment frag
            
//             #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
//             #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
//             #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
//             #pragma multi_compile_fog
            
//             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

//             struct Attributes
//             {
//                 float3 positionOS : POSITION;
//                 float3 normalOS : NORMAL;
//             };

//             struct Varyings
//             {
//                 float4 positionHCS : SV_POSITION;
//                 float3 normalWS : NORMAL;
//                 float3 positionWS : TEXCOORD0;
//                 half fogCoord : TEXCOORD1;
//             };

//             CBUFFER_START(UnityPerMaterial)
//                 half4 _BaseColor;
//                 half _Metallic;
//                 half _Smoothness;
//                 half _SpecularPower;
//                 half _Roughness;
//                 half _RoughnessEffect;
//                 half _RoughnessScale;
//                 half _DiffusePower;
//                 half _MatteEffect;
//             CBUFFER_END

//             // Better noise function for roughness
//             half SimpleNoise(half3 position)
//             {
//                 return frac(sin(dot(position, half3(12.9898, 78.233, 45.543))) * 43758.5453);
//             }

//             // Smooth noise for better roughness
//             half SmoothNoise(half3 position)
//             {
//                 half3 fractional = frac(position);
//                 half3 integer = position - fractional;
                
//                 half a = SimpleNoise(integer);
//                 half b = SimpleNoise(integer + half3(1, 0, 0));
//                 half c = SimpleNoise(integer + half3(0, 1, 0));
//                 half d = SimpleNoise(integer + half3(1, 1, 0));
                
//                 half e = SimpleNoise(integer + half3(0, 0, 1));
//                 half f = SimpleNoise(integer + half3(1, 0, 1));
//                 half g = SimpleNoise(integer + half3(0, 1, 1));
//                 half h = SimpleNoise(integer + half3(1, 1, 1));
                
//                 fractional = fractional * fractional * (3.0 - 2.0 * fractional);
                
//                 half ab = lerp(a, b, fractional.x);
//                 half cd = lerp(c, d, fractional.x);
//                 half abcd = lerp(ab, cd, fractional.y);
                
//                 half ef = lerp(e, f, fractional.x);
//                 half gh = lerp(g, h, fractional.x);
//                 half efgh = lerp(ef, gh, fractional.y);
                
//                 return lerp(abcd, efgh, fractional.z);
//             }

//             Varyings vert(Attributes IN)
//             {
//                 Varyings OUT;
                
//                 VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
//                 VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS);
                
//                 OUT.positionHCS = vertexInput.positionCS;
//                 OUT.positionWS = vertexInput.positionWS;
//                 OUT.normalWS = normalInput.normalWS;
//                 OUT.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                
//                 return OUT;
//             }

//             half4 frag(Varyings IN) : SV_Target
//             {
//                 // Normalized normal
//                 half3 normal = normalize(IN.normalWS);
//                 half3 viewDir = normalize(_WorldSpaceCameraPos - IN.positionWS);
                
//                 // Main light with shadows
//                 float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
//                 Light mainLight = GetMainLight(shadowCoord);
                
//                 // IMPROVED ROUGHNESS EFFECT
//                 half3 noisePosition = IN.positionWS * _RoughnessScale;
//                 half roughnessNoise = SmoothNoise(noisePosition) * 2.0 - 1.0;
                
//                 // Calculate how "flat" the surface is (detect hard edges)
//                 // On cubes, neighboring pixels will have very different normals
//                 half normalVariation = length(fwidth(IN.normalWS));
                
//                 // Reduce roughness effect on hard edges to prevent artifacts
//                 half adaptiveRoughness = _Roughness * (1.0 - normalVariation * 0.5);
                
//                 // Apply roughness to normal (but more subtly on hard edges)
//                 half3 roughNormal = normalize(normal + roughnessNoise * adaptiveRoughness * _RoughnessEffect);
//                 half3 finalNormal = lerp(normal, roughNormal, adaptiveRoughness);
                
//                 // LIGHTING CALCULATIONS
//                 half NdotL = saturate(dot(finalNormal, mainLight.direction));
                
//                 // Matte effect
//                 NdotL = lerp(NdotL, pow(NdotL, 1.0 + _MatteEffect * 3.0), _MatteEffect);
//                 half3 diffuse = mainLight.color * NdotL * _DiffusePower;
                
//                 // SPECULAR - Reduced on rough surfaces
//                 half3 halfVec = normalize(mainLight.direction + viewDir);
//                 half NdotH = saturate(dot(finalNormal, halfVec));
                
//                 half smoothnessWithRoughness = _Smoothness * (1.0 - adaptiveRoughness * 0.7);
//                 half specular = pow(NdotH, _SpecularPower * smoothnessWithRoughness + 1.0);
                
//                 // Metallic effect
//                 half3 specularColor = lerp(half3(1,1,1), _BaseColor.rgb, _Metallic);
//                 half3 specularLight = specular * mainLight.color * specularColor;
                
//                 // FINAL COLOR
//                 half3 finalColor = _BaseColor.rgb * diffuse + specularLight;
//                 finalColor += unity_AmbientSky.rgb * _BaseColor.rgb * 0.5;
//                 finalColor = MixFog(finalColor, IN.fogCoord);
                
//                 return half4(finalColor, _BaseColor.a);
//             }
//             ENDHLSL
//         }
        
//         Pass
//         {
//             Name "ShadowCaster"
//             Tags{"LightMode" = "ShadowCaster"}

//             ZWrite On
//             ZTest LEqual
//             ColorMask 0

//             HLSLPROGRAM
//             #pragma vertex ShadowPassVertex
//             #pragma fragment ShadowPassFragment
//             #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
//             #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
//             ENDHLSL
//         }
//     }
// }
// // Shader "BasicLit/AdvancedSurface"
// // {
// //     Properties
// //     {
// //         _BaseColor ("Color", Color) = (1,1,1,1)
        
// //         [Header(Glossy Settings)]
// //         [Space(10)]
// //         _Metallic ("Metallic", Range(0,1)) = 0.0
// //         _Smoothness ("Smoothness", Range(0,1)) = 0.5
// //         _SpecularPower ("Specular Power", Range(1,100)) = 20
        
// //         [Header(Roughness Settings)]
// //         [Space(10)]
// //         _Roughness ("Roughness", Range(0,1)) = 0.5
// //         _RoughnessEffect ("Roughness Effect", Range(0,2)) = 1.0
        
// //         [Header(Matt Settings)]
// //         [Space(10)]
// //         _DiffusePower ("Diffuse Power", Range(0,2)) = 1.0
// //         _MatteEffect ("Matte Effect", Range(0,1)) = 0.0
// //     }
// //     SubShader
// //     {
// //         Tags { 
// //             "RenderPipeline"="UniversalPipeline" 
// //             "RenderType"="Opaque"
// //             "Queue"="Geometry"
// //         }

// //         LOD 100

// //         Pass
// //         {
// //             Name "ForwardLit"
// //             Tags { "LightMode"="UniversalForward" }

// //             HLSLPROGRAM
// //             #pragma vertex vert
// //             #pragma fragment frag
            
// //             #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
// //             #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
// //             #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
// //             #pragma multi_compile_fog
            
// //             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
// //             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// //             struct Attributes
// //             {
// //                 float3 positionOS : POSITION;
// //                 float3 normalOS : NORMAL;
// //             };

// //             struct Varyings
// //             {
// //                 float4 positionHCS : SV_POSITION;
// //                 float3 normalWS : NORMAL;
// //                 float3 positionWS : TEXCOORD0;
// //                 half fogCoord : TEXCOORD1;
// //             };

// //             CBUFFER_START(UnityPerMaterial)
// //                 half4 _BaseColor;
// //                 half _Metallic;
// //                 half _Smoothness;
// //                 half _SpecularPower;
// //                 half _Roughness;
// //                 half _RoughnessEffect;
// //                 half _DiffusePower;
// //                 half _MatteEffect;
// //             CBUFFER_END

// //             // Simple noise function for roughness effect
// //             half SimpleNoise(half2 uv)
// //             {
// //                 return frac(sin(dot(uv, half2(12.9898, 78.233))) * 43758.5453);
// //             }

// //             Varyings vert(Attributes IN)
// //             {
// //                 Varyings OUT;
                
// //                 VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
// //                 VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS);
                
// //                 OUT.positionHCS = vertexInput.positionCS;
// //                 OUT.positionWS = vertexInput.positionWS;
// //                 OUT.normalWS = normalInput.normalWS;
// //                 OUT.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                
// //                 return OUT;
// //             }

// //             half4 frag(Varyings IN) : SV_Target
// //             {
// //                 // Normalized normal
// //                 half3 normal = normalize(IN.normalWS);
// //                 half3 viewDir = normalize(_WorldSpaceCameraPos - IN.positionWS);
                
// //                 // Main light with shadows
// //                 float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
// //                 Light mainLight = GetMainLight(shadowCoord);
                
// //                 // ROUGHNESS EFFECT - Distort normal for rough surfaces
// //                 half2 noiseUV = IN.positionWS.xz * 0.1; // Scale
// //                 half roughnessNoise = SimpleNoise(noiseUV) * 2.0 - 1.0; // -1 to 1 range
                
// //                 // Roughness affects the normal
// //                 half3 roughNormal = normalize(normal + roughnessNoise * _Roughness * _RoughnessEffect);
                
// //                 // Choose which normal to use (use roughNormal if roughness is active)
// //                 half3 finalNormal = lerp(normal, roughNormal, _Roughness);
                
// //                 // LIGHTING CALCULATIONS
                
// //                 // Diffuse Lighting
// //                 half NdotL = saturate(dot(finalNormal, mainLight.direction));
                
// //                 // Matte effect - softens diffuse
// //                 NdotL = lerp(NdotL, pow(NdotL, 1.0 + _MatteEffect * 3.0), _MatteEffect);
// //                 half3 diffuse = mainLight.color * NdotL * _DiffusePower;
                
// //                 // SPECULAR (SHININESS) CALCULATION
// //                 half3 halfVec = normalize(mainLight.direction + viewDir);
// //                 half NdotH = saturate(dot(finalNormal, halfVec));
                
// //                 // Roughness also affects specular
// //                 half smoothnessWithRoughness = _Smoothness * (1.0 - _Roughness * 0.7);
// //                 half specular = pow(NdotH, _SpecularPower * smoothnessWithRoughness + 1.0);
                
// //                 // Metallic effect - specular color comes from base color
// //                 half3 specularColor = lerp(half3(1,1,1), _BaseColor.rgb, _Metallic);
// //                 half3 specularLight = specular * mainLight.color * specularColor;
                
// //                 // FINAL COLOR COMPOSITION
// //                 half3 finalColor = _BaseColor.rgb * diffuse + specularLight;
                
// //                 // Ambient Light
// //                 finalColor += unity_AmbientSky.rgb * _BaseColor.rgb * 0.5;
                
// //                 // Fog effect
// //                 finalColor = MixFog(finalColor, IN.fogCoord);
                
// //                 return half4(finalColor, _BaseColor.a);
// //             }
// //             ENDHLSL
// //         }
        
// //         // Shadow pass
// //         Pass
// //         {
// //             Name "ShadowCaster"
// //             Tags{"LightMode" = "ShadowCaster"}

// //             ZWrite On
// //             ZTest LEqual
// //             ColorMask 0

// //             HLSLPROGRAM
// //             #pragma vertex ShadowPassVertex
// //             #pragma fragment ShadowPassFragment
// //             #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
// //             #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
// //             ENDHLSL
// //         }
// //     }
// // }
