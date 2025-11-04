Shader "Custom/URPToonColorOnly_Simple"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _ShadeSteps ("Shade Steps", Range(1,5)) = 3
        _LightDir ("Light Direction", Vector) = (0,1,0,0)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        LOD 200

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : NORMAL;
            };

            float4 _BaseColor;
            int _ShadeSteps;
            float3 _LightDir;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS);
                OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float NdotL = dot(IN.normalWS, normalize(_LightDir));
                float shade = ceil(NdotL * _ShadeSteps) / _ShadeSteps;
                shade = saturate(shade);
                return _BaseColor * shade;
            }
            ENDHLSL
        }
    }
}
