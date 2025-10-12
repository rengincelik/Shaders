Shader "Custom/URP/SilkSatinShader_Improved"
{
Properties
{
    [Header(Base Properties)]
    _BaseColor ("Base Color", Color) = (0.9, 0.9, 0.95, 1)
    _Metallic ("Metallic", Range(0, 1)) = 0.0
    
    [Header(Specular)]
    _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
    _Smoothness ("Smoothness", Range(0, 1)) = 0.95
    _SpecularIntensity ("Specular Intensity", Range(0, 2)) = 0.3
    
    [Header(Anisotropy)]
    _Anisotropy ("Anisotropy", Range(-1, 1)) = 0.7
    _AnisotropyRotation ("Anisotropy Rotation", Range(0, 1)) = 0
    
    [Header(Sheen)]
    _Sheen ("Sheen Intensity", Range(0, 3)) = 1.5
    _SheenTint ("Sheen Tint", Color) = (1, 0.98, 0.95, 1)
    _SheenRoughness ("Sheen Roughness", Range(0, 1)) = 0.15
    _SheenIntensityMultiplier ("Sheen Multiplier", Range(0, 2)) = 0.4
    
    [Header(Fresnel)]
    _FresnelPower ("Fresnel Power", Range(1, 10)) = 5
    _FresnelIntensity ("Fresnel Intensity", Range(0, 1)) = 0.1
    
    [Header(Iridescence)]
    _IridescenceStrength ("Iridescence Strength", Range(0, 1)) = 0.15
    _IridescenceThickness ("Film Thickness (nm)", Range(100, 1000)) = 380
    _IridescenceMultiplier ("Iridescence Multiplier", Range(0, 1)) = 0.15
    
    [Header(Surface Detail)]
    _MicroRoughness ("Micro Roughness", Range(0, 0.5)) = 0.05
    _MicroScale ("Micro Detail Scale", Range(1, 500)) = 200
    
    [Header(Lighting)]
    _DiffuseIntensity ("Diffuse Intensity", Range(0, 1)) = 0.15
    _AmbientIntensity ("Ambient Intensity", Range(0, 1)) = 0.05
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
            float4 _SpecularColor;
            float4 _SheenTint;
            float _Metallic;
            float _Smoothness;
            float _SpecularIntensity;
            float _Anisotropy;
            float _AnisotropyRotation;
            float _Sheen;
            float _SheenRoughness;
            float _SheenIntensityMultiplier;
            float _FresnelPower;
            float _FresnelIntensity;
            float _IridescenceStrength;
            float _IridescenceThickness;
            float _IridescenceMultiplier;
            float _MicroRoughness;
            float _MicroScale;
            float _DiffuseIntensity;
            float _AmbientIntensity;
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
        
        // Improved noise function with proper gradient
        float hash(float3 p)
        {
            p = frac(p * 0.3183099 + 0.1);
            p *= 17.0;
            return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
        }
        
        float noise(float3 x)
        {
            float3 p = floor(x);
            float3 f = frac(x);
            f = f * f * (3.0 - 2.0 * f);
            return lerp(lerp(lerp(hash(p + float3(0,0,0)), hash(p + float3(1,0,0)), f.x),
                            lerp(hash(p + float3(0,1,0)), hash(p + float3(1,1,0)), f.x), f.y),
                       lerp(lerp(hash(p + float3(0,0,1)), hash(p + float3(1,0,1)), f.x),
                            lerp(hash(p + float3(0,1,1)), hash(p + float3(1,1,1)), f.x), f.y), f.z);
        }
        
        // Proper noise-based normal perturbation
        float3 NoiseNormal(float3 pos, float scale, float strength)
        {
            float offset = 0.01;
            float center = noise(pos * scale);
            float dx = noise((pos + float3(offset, 0, 0)) * scale) - center;
            float dy = noise((pos + float3(0, offset, 0)) * scale) - center;
            float dz = noise((pos + float3(0, 0, offset)) * scale) - center;
            return float3(dx, dy, dz) * strength / offset;
        }
        
        // Anisotropic GGX with proper energy conservation
        float AnisotropicGGX(float3 N, float3 T, float3 B, float3 V, float3 L, float roughness, float anisotropy)
        {
            float3 H = normalize(V + L);
            float NdotH = saturate(dot(N, H));
            float TdotH = dot(T, H);
            float BdotH = dot(B, H);
            float NdotV = saturate(dot(N, V));
            float NdotL = saturate(dot(N, L));
            
            if (NdotL <= 0.0 || NdotV <= 0.0) return 0.0;
            
            // Aspect ratio based on anisotropy
            float aspect = sqrt(1.0 - anisotropy * 0.9);
            float ax = max(0.001, roughness / aspect);
            float ay = max(0.001, roughness * aspect);
            
            // Distribution (D)
            float denom = TdotH * TdotH / (ax * ax) + BdotH * BdotH / (ay * ay) + NdotH * NdotH;
            float D = 1.0 / (PI * ax * ay * denom * denom);
            
            // Geometry (G) - Smith GGX
            float k = roughness * roughness * 0.5;
            float G_V = NdotV / (NdotV * (1.0 - k) + k);
            float G_L = NdotL / (NdotL * (1.0 - k) + k);
            float G = G_V * G_L;
            
            return D * G / (4.0 * NdotV * NdotL + 0.0001);
        }
        
        // Fresnel Schlick
        float3 FresnelSchlick(float cosTheta, float3 F0)
        {
            return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
        }
        
        // Improved thin-film interference iridescence
        float3 ThinFilmIridescence(float NdotV, float thickness, float strength)
        {
            // Optical path difference
            float phase = 4.0 * PI * thickness * NdotV / 1000.0; // thickness in nm
            
            // RGB wavelengths (nm): Red ~700, Green ~546, Blue ~435
            float3 wavelengths = float3(700.0, 546.0, 435.0);
            float3 phases = phase * (1.0 / wavelengths);
            
            // Interference pattern
            float3 iridescence = 0.5 + 0.5 * cos(phases);
            
            // Modulate by viewing angle for realism
            float angleFactor = pow(1.0 - NdotV, 2.0);
            
            return iridescence * strength * angleFactor;
        }
        
        // Improved Sheen BRDF with grazing angle enhancement
        float3 SheenBRDF(float NdotV, float NdotL, float NdotH, float3 sheenColor, float intensity, float roughness)
        {
            // Charlie sheen distribution
            float invR = 1.0 / max(roughness, 0.001);
            float cos2h = NdotH * NdotH;
            float sin2h = max(1.0 - cos2h, 0.0001);
            float D = (2.0 + invR) * pow(sin2h, invR * 0.5) / (2.0 * PI);
            
            // Visibility term
            float V = 1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV));
            
            // Enhanced at grazing angles
            float fresnelSheen = pow(1.0 - NdotV, 5.0);
            
            return sheenColor * D * V * intensity * (1.0 + fresnelSheen * 2.0);
        }
        
        // Unpack normal from noise (procedural)
        float3 GenerateProceduralNormal(float3 worldPos, float scale, float strength)
        {
            float3 gradient = NoiseNormal(worldPos, scale, strength);
            float3 normal;
            normal.xy = gradient.xy;
            normal.z = sqrt(max(0.0001, 1.0 - dot(normal.xy, normal.xy)));
            return normalize(normal);
        }
        
        half4 frag(Varyings input) : SV_Target
        {
            // Base color (no texture)
            float3 baseColor = _BaseColor.rgb;
            
            // Build TBN matrix
            float3 T = normalize(input.tangentWS);
            float3 B = normalize(input.bitangentWS);
            float3 N = normalize(input.normalWS);
            
            // Procedural micro detail normal
            float3 microNormalTS = GenerateProceduralNormal(input.positionWS, _MicroScale, _MicroRoughness);
            float3x3 TBN = float3x3(T, B, N);
            float3 microNormal = normalize(mul(microNormalTS, TBN));
            
            // Use micro-perturbed normal
            N = microNormal;
            
            float3 V = normalize(input.viewDirWS);
            float NdotV = saturate(dot(N, V));
            
            // Rotate tangent for anisotropy
            float rotation = _AnisotropyRotation * TWO_PI;
            float3 rotatedTangent = T * cos(rotation) + B * sin(rotation);
            float3 rotatedBitangent = cross(N, rotatedTangent);
            
            // Main light
            Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
            float3 L = normalize(mainLight.direction);
            float3 H = normalize(V + L);
            float3 lightColor = mainLight.color * mainLight.shadowAttenuation;
            
            float NdotL = saturate(dot(N, L));
            float NdotH = saturate(dot(N, H));
            
            // Material properties
            float roughness = 1.0 - _Smoothness;
            float3 F0 = lerp(float3(0.04, 0.04, 0.04), _SpecularColor.rgb, _Metallic);
            
            // Fresnel
            float3 F = FresnelSchlick(NdotV, F0);
            
            // Energy conservation: kS + kD = 1
            float3 kS = F; // Specular contribution
            float3 kD = (1.0 - kS) * (1.0 - _Metallic); // Diffuse contribution
            
            // Diffuse (Lambert)
            float3 diffuse = kD * baseColor * lightColor * NdotL * _DiffuseIntensity;
            
            // Specular (Anisotropic GGX)
            float specular = AnisotropicGGX(N, rotatedTangent, rotatedBitangent, V, L, roughness, _Anisotropy);
            float3 specularColor = specular * kS * lightColor * _SpecularColor.rgb * _SpecularIntensity;
            
            // Sheen (fabric-like highlight at grazing angles)
            float3 sheen = SheenBRDF(NdotV, NdotL, NdotH, _SheenTint.rgb, _Sheen, _SheenRoughness) * lightColor * NdotL * _SheenIntensityMultiplier;
            
            // Fresnel rim light (eski shader gibi basit ama etkili)
            float fresnelRim = pow(1.0 - NdotV, _FresnelPower);
            float3 fresnelColor = fresnelRim * baseColor * _FresnelIntensity * NdotL * lightColor;
            
            // Iridescence (thin-film interference)
            float3 iridescence = ThinFilmIridescence(NdotV, _IridescenceThickness, _IridescenceStrength) * lightColor * _IridescenceMultiplier;
            
            // Ambient lighting (indirect)
            float3 ambient = SampleSH(N) * baseColor * kD * _AmbientIntensity;
            
            // Ambient specular
            float3 R = reflect(-V, N);
            float3 ambientSpec = SampleSH(R) * kS * _SpecularColor.rgb * _Smoothness * _AmbientIntensity * 0.5;
            
            // Additional lights
            float3 additionalLighting = 0;
            #ifdef _ADDITIONAL_LIGHTS
            uint pixelLightCount = GetAdditionalLightsCount();
            for (uint i = 0; i < pixelLightCount; ++i)
            {
                Light light = GetAdditionalLight(i, input.positionWS);
                float3 attenuatedLightColor = light.color * light.distanceAttenuation * light.shadowAttenuation;
                float3 lightDir = normalize(light.direction);
                float addNdotL = saturate(dot(N, lightDir));
                
                // Specular
                float addSpec = AnisotropicGGX(N, rotatedTangent, rotatedBitangent, V, lightDir, roughness, _Anisotropy);
                additionalLighting += addSpec * kS * _SpecularColor.rgb * attenuatedLightColor * _SpecularIntensity;
                
                // Diffuse
                additionalLighting += kD * baseColor * attenuatedLightColor * addNdotL * _DiffuseIntensity;
            }
            #endif
            
            // Final color composition with proper energy conservation
            float3 finalColor = diffuse + specularColor + sheen + fresnelColor + 
                               iridescence + ambient + ambientSpec + additionalLighting;
            
            // Optional tone mapping for HDR control
            finalColor = saturate(finalColor);
            
            return half4(finalColor, _BaseColor.a);
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
        
        struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
        struct Varyings { float4 positionCS : SV_POSITION; };
        float3 _LightDirection;
        
        Varyings ShadowPassVertex(Attributes input)
        {
            Varyings output;
            float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
            float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
            output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
            return output;
        }
        
        half4 ShadowPassFragment(Varyings input) : SV_Target { return 0; }
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
        
        struct Attributes { float4 position : POSITION; };
        struct Varyings { float4 positionCS : SV_POSITION; };
        
        Varyings DepthOnlyVertex(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.position.xyz);
            return output;
        }
        
        half4 DepthOnlyFragment(Varyings input) : SV_Target { return 0; }
        ENDHLSL
    }
}

FallBack "Universal Render Pipeline/Lit"
}
