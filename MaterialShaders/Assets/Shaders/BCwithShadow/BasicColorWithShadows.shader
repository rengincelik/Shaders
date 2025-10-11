Shader "BasicLit/ColorWithShadows_Simple"
{
    Properties
    {
        _BaseColor ("Color", Color)=(1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "LightMode"="UniversalForward" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : NORMAL;
                float3 positionWS  : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normal = normalize(IN.normalWS);

                half3 lightDir = normalize(float3(0.5, 1.0, 0.3));
                half3 lightColor = float3(1,1,1);

                half NdotL = saturate(dot(normal, lightDir));

                half shadow = 0.5;

                half3 finalColor = _BaseColor.rgb * lightColor * NdotL * shadow;
                return half4(finalColor, _BaseColor.a);
            }

            ENDHLSL
        }
    }
}
