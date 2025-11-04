Shader "Custom/WaterReflection"
{
    Properties
    {
        _MainTex ("Reflection Texture", 2D) = "white" {}
        _WaveAmplitude ("Wave Amplitude", Float) = 0.02
        _WaveFrequency ("Wave Frequency", Float) = 10
        _StripeIntensity ("Stripe Intensity", Float) = 0.2
        _WaveSpeed ("Wave Speed", Float)=0.2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float _WaveAmplitude;
            float _WaveFrequency;
            float _StripeIntensity;
            float _WaveSpeed;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;

                // Dalga efekti: x ekseninde şekil, zamanla y ekseninde ilerleme
                uv.y += sin(uv.x * _WaveFrequency + _Time.y * _WaveSpeed) * _WaveAmplitude;

                fixed4 col = tex2D(_MainTex, uv);

                // Beyaz çizgiler (highlight)
                float stripes = step(0.95, frac(sin(uv.y * 50 + _Time.y * 0.2)));
                col.rgb += stripes * _StripeIntensity;

                return col;


            }
            ENDCG
        }
    }
}
