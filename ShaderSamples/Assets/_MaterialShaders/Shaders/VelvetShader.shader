Shader "BasicURP/VelvetShader"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.5, 0.1, 0.1, 1)
        
        [Header(Velvet Properties)]
        _VelvetColor ("Velvet Rim Color", Color) = (1, 0.3, 0.3, 1)
        _VelvetStrength ("Velvet Strength", Range(0, 5)) = 2.5
        _VelvetPower ("Velvet Power", Range(0.1, 10)) = 3.5
        _FuzzScatter ("Fuzz Scatter", Range(0, 1)) = 0.6
        
        [Header(Surface)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.25
        _Metallic ("Metallic", Range(0, 1)) = 0
        
        [Header(Advanced)]
        _Anisotropy ("Anisotropy", Range(-1, 1)) = 0.4
        _SubsurfaceScatter ("Subsurface Scatter", Range(0, 1)) = 0.3
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        LOD 300
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float3 viewDirWS : TEXCOORD4;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _VelvetColor;
                float _VelvetStrength;
                float _VelvetPower;
                float _FuzzScatter;
                float _Smoothness;
                float _Metallic;
                float _Anisotropy;
                float _SubsurfaceScatter;
            CBUFFER_END
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                
                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = normalInputs.tangentWS;
                output.bitangentWS = normalInputs.bitangentWS;
                output.viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
                
                return output;
            }
            
            float3 VelvetBRDF(float3 normal, float3 viewDir, float3 lightDir, float3 velvetColor, float strength, float power, float scatter)
            {
                float NdotV = saturate(dot(normal, viewDir));
                float NdotL = saturate(dot(normal, lightDir));
                
                float rim = pow(1.0 - NdotV, power) * strength;
                
                float backScatter = saturate(dot(viewDir, -lightDir));
                float fuzzTerm = pow(backScatter, 3) * scatter;
                
                float sideScatter = pow(saturate(1.0 - abs(dot(normal, lightDir))), 2) * scatter * 0.5;
                
                float velvetTerm = rim + fuzzTerm + sideScatter;
                
                return velvetColor * velvetTerm * saturate(NdotL + 0.2);
            }
            
            float AnisotropicSpecular(float3 normal, float3 tangent, float3 viewDir, float3 lightDir, float anisotropy, float smoothness)
            {
                float3 halfDir = normalize(lightDir + viewDir);
                float3 bitangent = cross(normal, tangent);
                
                float NdotH = saturate(dot(normal, halfDir));
                float TdotH = dot(tangent, halfDir);
                float BdotH = dot(bitangent, halfDir);
                
                float roughnessX = max(0.001, 1.0 - smoothness);
                float roughnessY = max(0.001, (1.0 - smoothness) * (1.0 + anisotropy));
                
                float denom = TdotH * TdotH / (roughnessX * roughnessX) + 
                              BdotH * BdotH / (roughnessY * roughnessY) + 
                              NdotH * NdotH;
                
                float spec = 1.0 / (3.14159 * roughnessX * roughnessY * denom * denom + 0.001);
                
                return spec * 0.15;
            }
            
            float3 SubsurfaceScattering(float3 normal, float3 viewDir, float3 lightDir, float3 color, float amount)
            {
                float backLight = saturate(dot(viewDir, -lightDir + normal * 0.5));
                float scatter = pow(backLight, 2) * amount;
                return color * scatter;
            }
            
            float noise(float3 pos)
            {
                float3 p = floor(pos);
                float3 f = frac(pos);
                f = f * f * (3.0 - 2.0 * f);
                
                float n = p.x + p.y * 57.0 + p.z * 113.0;
                return lerp(
                    lerp(lerp(frac(sin(n) * 43758.5), frac(sin(n + 1.0) * 43758.5), f.x),
                         lerp(frac(sin(n + 57.0) * 43758.5), frac(sin(n + 58.0) * 43758.5), f.x), f.y),
                    lerp(lerp(frac(sin(n + 113.0) * 43758.5), frac(sin(n + 114.0) * 43758.5), f.x),
                         lerp(frac(sin(n + 170.0) * 43758.5), frac(sin(n + 171.0) * 43758.5), f.x), f.y),
                    f.z);
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                float3 normalWS = normalize(input.normalWS);
                float3 viewDirWS = normalize(input.viewDirWS);
                
                float microDetail = noise(input.positionWS * 50.0) * 0.1;
                float3 perturbedNormal = normalize(normalWS + float3(microDetail, microDetail, microDetail) * 0.2);
                
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                float3 lightDir = normalize(mainLight.direction);
                float3 lightColor = mainLight.color * mainLight.shadowAttenuation;
                
                float NdotL = saturate(dot(perturbedNormal, lightDir));
                float3 diffuse = _BaseColor.rgb * lightColor * (NdotL * 0.7 + 0.3);
                
                float3 velvet = VelvetBRDF(perturbedNormal, viewDirWS, lightDir, _VelvetColor.rgb, 
                                          _VelvetStrength, _VelvetPower, _FuzzScatter);
                velvet *= lightColor;
                
                float anisoSpec = AnisotropicSpecular(perturbedNormal, input.tangentWS, viewDirWS, 
                                                     lightDir, _Anisotropy, _Smoothness);
                anisoSpec *= lightColor.r;
                
                float3 sss = SubsurfaceScattering(normalWS, viewDirWS, lightDir, 
                                                 _BaseColor.rgb, _SubsurfaceScatter);
                sss *= lightColor;
                
                float3 ambient = SampleSH(normalWS) * _BaseColor.rgb * 0.4;
                
                float3 additionalLighting = 0;
                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint i = 0; i < pixelLightCount; ++i)
                {
                    Light light = GetAdditionalLight(i, input.positionWS);
                    float3 attenuatedLightColor = light.color * light.distanceAttenuation * light.shadowAttenuation;
                    float addNdotL = saturate(dot(normalWS, light.direction));
                    additionalLighting += _BaseColor.rgb * attenuatedLightColor * addNdotL;
                }
                #endif
                
                float3 finalColor = diffuse + velvet + anisoSpec + sss + ambient + additionalLighting;
                
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };
            
            float3 _LightDirection;
            
            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                return output;
            }
            
            half4 ShadowPassFragment(Varyings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 position : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.position.xyz);
                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Lit"
}

