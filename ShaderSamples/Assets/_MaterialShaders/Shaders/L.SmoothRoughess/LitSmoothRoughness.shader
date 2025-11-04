Shader "BasicLit/SmoothRoughness"
{
    Properties
    {
        _BaseColor ("Color", Color) = (1,1,1,1)
        
        [Header(Glossy Settings)]
        [Space(10)]
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        _SpecularPower ("Specular Power", Range(1,100)) = 20
        
        [Header(Roughness Settings)]
        [Space(10)]
        _Roughness ("Roughness", Range(0,1)) = 0.5
        _RoughnessScale ("Roughness Scale", Range(0.1,3.0)) = 1.0
        
        [Header(Matt Settings)]
        [Space(10)]
        _DiffusePower ("Diffuse Power", Range(0,2)) = 1.0
        _MatteEffect ("Matte Effect", Range(0,1)) = 0.0
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
                half _SpecularPower;
                half _Roughness;
                half _RoughnessScale;
                half _DiffusePower;
                half _MatteEffect;
            CBUFFER_END

            // Smooth noise function - no black dots
            half SmoothNoise(half3 position)
            {
                half3 f = frac(position);
                half3 i = position - f;
                
                // Bilinear interpolation
                half a = frac(sin(dot(i, half3(12.9898, 78.233, 45.543))) * 43758.5453);
                half b = frac(sin(dot(i + half3(1,0,0), half3(12.9898, 78.233, 45.543))) * 43758.5453);
                half c = frac(sin(dot(i + half3(0,1,0), half3(12.9898, 78.233, 45.543))) * 43758.5453);
                half d = frac(sin(dot(i + half3(1,1,0), half3(12.9898, 78.233, 45.543))) * 43758.5453);
                
                half ab = lerp(a, b, f.x);
                half cd = lerp(c, d, f.x);
                return lerp(ab, cd, f.y);
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
                
                // DIFFUSE - No roughness effect on diffuse
                half NdotL = saturate(dot(normal, mainLight.direction));
                NdotL = lerp(NdotL, pow(NdotL, 1.0 + _MatteEffect * 3.0), _MatteEffect);
                half3 diffuse = mainLight.color * NdotL * _DiffusePower;
                
                // SPECULAR with roughness effect
                half3 halfVec = normalize(mainLight.direction + viewDir);
                half NdotH = saturate(dot(normal, halfVec));
                
                // Roughness affects specular only
                half noise = SmoothNoise(IN.positionWS * _RoughnessScale);
                half roughnessVariation = noise * _Roughness;
                
                // Roughness makes specular wider and less intense
                half effectiveSmoothness = _Smoothness * (1.0 - _Roughness * 0.8);
                half effectiveSpecularPower = _SpecularPower * (1.0 - _Roughness * 0.6);
                
                // Add some variation to specular based on roughness
                half specular = pow(NdotH + roughnessVariation * 0.1, effectiveSpecularPower * effectiveSmoothness + 5.0);
                specular *= (1.0 - _Roughness * 0.5); // Reduce intensity with roughness
                
                half3 specularColor = lerp(half3(1,1,1), _BaseColor.rgb, _Metallic);
                half3 specularLight = specular * mainLight.color * specularColor;
                
                // FINAL COLOR
                half3 finalColor = _BaseColor.rgb * diffuse + specularLight;
                finalColor += unity_AmbientSky.rgb * _BaseColor.rgb * 0.3;
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
