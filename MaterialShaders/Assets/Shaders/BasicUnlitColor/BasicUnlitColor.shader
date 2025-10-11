Shader "BasicUnlit/Color"
{
    Properties
    {
        _BaseColor ("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 position : POSITION;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
            CBUFFER_END

            v2f vert(appdata IN)
            {
                v2f OUT;
                OUT.position = TransformObjectToHClip(IN.position.xyz);
                return OUT;
            }

            half4 frag(v2f IN) : SV_Target
            {
                return _BaseColor; 
            }

            ENDHLSL
        }
    }
}

