Shader "Custom/URP/SilkSatinShader"
{
Properties
{
_BaseColor ("Base Color", Color) = (0.9, 0.9, 0.95, 1)
_SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
_Smoothness ("Smoothness", Range(0, 1)) = 0.95
_Anisotropy ("Anisotropy", Range(-1, 1)) = 0.7
_AnisotropyRotation ("Anisotropy Rotation", Range(0, 1)) = 0
_Sheen ("Sheen Intensity", Range(0, 3)) = 1.5
_SheenTint ("Sheen Tint", Color) = (1, 0.98, 0.95, 1)
_FresnelPower ("Fresnel Power", Range(1, 10)) = 5
_IridescenceStrength ("Iridescence", Range(0, 1)) = 0.15
_MicroRoughness ("Micro Roughness", Range(0, 0.5)) = 0.05
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
            float _Smoothness;
            float _Anisotropy;
            float _AnisotropyRotation;
            float _Sheen;
            float _FresnelPower;
            float _IridescenceStrength;
            float _MicroRoughness;
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
        
        float AnisotropicGGX(float3 N, float3 T, float3 V, float3 L, float roughness, float anisotropy)
        {
            float3 H = normalize(V + L);
            float3 B = cross(N, T);
            float NdotH = saturate(dot(N, H));
            float TdotH = dot(T, H);
            float BdotH = dot(B, H);
            float NdotV = saturate(dot(N, V));
            float NdotL = saturate(dot(N, L));
            float aspect = sqrt(1.0 - anisotropy * 0.9);
            float ax = max(0.001, roughness / aspect);
            float ay = max(0.001, roughness * aspect);
            float denom = TdotH * TdotH / (ax * ax) + BdotH * BdotH / (ay * ay) + NdotH * NdotH;
            float D = 1.0 / (3.14159 * ax * ay * denom * denom);
            float k = roughness * roughness * 0.5;
            float G_V = NdotV / (NdotV * (1.0 - k) + k);
            float G_L = NdotL / (NdotL * (1.0 - k) + k);
            float G = G_V * G_L;
            return D * G / (4.0 * NdotV * NdotL + 0.001);
        }
        
        float3 FresnelSchlick(float cosTheta, float3 F0)
        {
            return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
        }
        
        float3 Iridescence(float NdotV, float strength)
        {
            float iridescence = pow(1.0 - NdotV, 3.0);
            float3 color = float3(
                sin(iridescence * 3.14159 * 2.0) * 0.5 + 0.5,
                sin(iridescence * 3.14159 * 2.5) * 0.5 + 0.5,
                sin(iridescence * 3.14159 * 3.0) * 0.5 + 0.5
            );
            return color * strength;
        }
        
        float SheenBRDF(float NdotV, float NdotL, float NdotH, float3 sheenColor, float intensity)
        {
            float invR = 1.0 / 0.15;
            float cos2h = NdotH * NdotH;
            float sin2h = max(1.0 - cos2h, 0.001);
            float D = (2.0 + invR) * pow(sin2h, invR * 0.5) / (2.0 * 3.14159);
            float V = 1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV));
            return D * V * intensity;
        }
        
        half4 frag(Varyings input) : SV_Target
        {
            float3 N = normalize(input.normalWS);
            float3 V = normalize(input.viewDirWS);
            float3 T = normalize(input.tangentWS);
            float microNoise = noise(input.positionWS * 200.0) * _MicroRoughness;
            float3 microNormal = normalize(N + float3(microNoise, microNoise * 0.5, microNoise) * 0.1);
            float rotation = _AnisotropyRotation * 3.14159 * 2.0;
            float3 rotatedTangent = T * cos(rotation) + cross(N, T) * sin(rotation);
            Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
            float3 L = normalize(mainLight.direction);
            float3 H = normalize(V + L);
            float3 lightColor = mainLight.color * mainLight.shadowAttenuation;
            float NdotV = saturate(dot(microNormal, V));
            float NdotL = saturate(dot(microNormal, L));
            float NdotH = saturate(dot(microNormal, H));
            float3 diffuse = _BaseColor.rgb * lightColor * NdotL * 0.15;
            float roughness = 1.0 - _Smoothness;
            float specular = AnisotropicGGX(microNormal, rotatedTangent, V, L, roughness, _Anisotropy);
            float3 F = FresnelSchlick(NdotV, _SpecularColor.rgb * 0.04);
            float3 specularColor = specular * F * lightColor * _SpecularColor.rgb * 0.3;
            float sheenTerm = SheenBRDF(NdotV, NdotL, NdotH, _SheenTint.rgb, _Sheen);
            float3 sheen = sheenTerm * _SheenTint.rgb * lightColor * NdotL * 0.4;
            float fresnel = pow(1.0 - NdotV, _FresnelPower);
            float3 fresnelColor = fresnel * _BaseColor.rgb * 0.1 * NdotL;
            float3 iridescence = Iridescence(NdotV, _IridescenceStrength) * lightColor * 0.15;
            float3 ambient = SampleSH(N) * _BaseColor.rgb * 0.05;
            float3 R = reflect(-V, N);
            float3 ambientSpec = SampleSH(R) * _SpecularColor.rgb * _Smoothness * 0.05;
            float3 additionalLighting = 0;
            #ifdef _ADDITIONAL_LIGHTS
            uint pixelLightCount = GetAdditionalLightsCount();
            for (uint i = 0; i < pixelLightCount; ++i)
            {
                Light light = GetAdditionalLight(i, input.positionWS);
                float3 attenuatedLightColor = light.color * light.distanceAttenuation * light.shadowAttenuation;
                float3 lightDir = normalize(light.direction);
                float addNdotL = saturate(dot(N, lightDir));
                float addSpec = AnisotropicGGX(microNormal, rotatedTangent, V, lightDir, roughness, _Anisotropy);
                additionalLighting += addSpec * _SpecularColor.rgb * attenuatedLightColor * 0.3;
                additionalLighting += _BaseColor.rgb * attenuatedLightColor * addNdotL * 0.15;
            }
            #endif
            float3 finalColor = diffuse + specularColor + sheen + fresnelColor + 
                               iridescence + ambient + ambientSpec + additionalLighting;
            finalColor = saturate(finalColor);
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