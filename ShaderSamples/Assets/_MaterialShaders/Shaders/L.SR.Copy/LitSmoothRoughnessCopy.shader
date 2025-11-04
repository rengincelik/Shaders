Shader "BasicLit/VisibleRoughness"
{
    Properties
    {
        _BaseColor ("Color", Color) = (1,1,1,1)
        
        [Header(Glossy Settings)]
        [Space(10)]
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        
        [Header(Roughness Settings)]
        [Space(10)]
        _Roughness ("Roughness Intensity", Range(0,1)) = 0.5
        _RoughnessScale ("Roughness Scale", Range(0.5,3.0)) = 1.5
        _RoughnessContrast ("Roughness Contrast", Range(0.5,3.0)) = 1.5
        
        [Header(Matt Settings)]
        [Space(10)]
        _DiffusePower ("Diffuse Power", Range(0,2)) = 1.0
    }

    SubShader
    {
        Tags { 
            "RenderPipeline"="UniversalPipeline" 
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

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
                half _Roughness;
                half _RoughnessScale;
                half _RoughnessContrast;
                half _DiffusePower;
            CBUFFER_END

            // Better noise function - more visible patterns
            half VisibleNoise(half3 position)
            {
                half3 p = position * 0.5;
                half n = sin(p.x * 12.9898 + p.y * 78.233 + p.z * 45.543);
                n = frac(n * 43758.5453);
                n = n * n * _RoughnessContrast; // Increase contrast
                return n * 2.0 - 1.0;
            }

            // Multi-layer noise for strong visible effect
            half StrongNoise(half3 position)
            {
                half noise = 0.0;
                half scale = _RoughnessScale;
                half amplitude = 1.0;
                
                // 2 layers of strong noise
                for (int i = 0; i < 2; i++)
                {
                    noise += VisibleNoise(position * scale) * amplitude;
                    scale *= 2.0;
                    amplitude *= 0.5;
                }
                
                return noise;
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
                half3 normal = normalize(IN.normalWS);
                half3 viewDir = normalize(IN.viewDirWS);
                
                // Main light
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                // STRONG ROUGHNESS EFFECT - VERY VISIBLE
                half3 noisePosition = IN.positionWS * _RoughnessScale;
                half roughnessNoise = StrongNoise(noisePosition) * _Roughness;
                
                // Apply roughness to normal - STRONG EFFECT
                half3 roughNormal = normalize(normal + roughnessNoise * 0.8);
                half3 finalNormal = lerp(normal, roughNormal, _Roughness);
                
                // DIFFUSE with rough normal
                half NdotL = saturate(dot(finalNormal, mainLight.direction));
                half3 diffuse = mainLight.color * NdotL * _DiffusePower;
                
                // SPECULAR with strong roughness effect
                half3 halfVec = normalize(mainLight.direction + viewDir);
                half NdotH = saturate(dot(finalNormal, halfVec));
                
                // Roughness strongly affects specular
                half effectiveSmoothness = _Smoothness * (1.0 - _Roughness * 0.9);
                half specularPower = 50.0 * effectiveSmoothness + 5.0;
                
                half specular = pow(NdotH, specularPower);
                specular *= (1.0 - _Roughness * 0.7); // Reduce intensity
                
                // Add some noise to specular for more visible roughness
                specular *= (1.0 + roughnessNoise * 0.3);
                
                half3 specularColor = lerp(half3(1,1,1), _BaseColor.rgb, _Metallic);
                half3 specularLight = specular * mainLight.color * specularColor;
                
                // FINAL COLOR with visible roughness
                half3 finalColor = _BaseColor.rgb * diffuse + specularLight;
                
                // Add some ambient with roughness variation
                half ambient = 0.3 + roughnessNoise * 0.1;
                finalColor += unity_AmbientSky.rgb * _BaseColor.rgb * ambient;
                
                finalColor = MixFog(finalColor, IN.fogCoord);
                
                return half4(finalColor, _BaseColor.a);
            }
            ENDHLSL
        }
        
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
}
