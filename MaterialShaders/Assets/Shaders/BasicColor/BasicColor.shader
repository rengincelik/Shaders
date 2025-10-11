
Shader "BasicLit/Color"
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


            struct Attributes{
                float3 positionOS:POSITION;
                float3 normalOS:NORMAL;
            };

            struct Varyings{
                float4 positionHCS : SV_POSITION;
                float3 normalWS : NORMAL;
                float3 positionWS:TEXCOORD0;
            };
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS=TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS=TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS=TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            };

            half4 frag (Varyings IN) : SV_Target
            {
                half3 normal =normalize(IN.normalWS);
                Light mainLight =GetMainLight();
                half diffuseTerm=saturate(dot(normal,mainLight.direction));
                half3 lightColor=mainLight.color*diffuseTerm;
                half3 finalColor=_BaseColor.rgb*lightColor;
                return half4(finalColor, _BaseColor.a);

            };
            ENDHLSL
        }
    }
}
