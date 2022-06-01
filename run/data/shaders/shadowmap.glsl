#if defined(SHADOWMAPPING)

vec4 shadowMapSingle(in sampler2D sampler, in vec2 shadowMapCoord, in float lightDistance)
{
    float shadowMapDistance = texture2D(sampler, shadowMapCoord).r;

    return (shadowMapCoord.x >= 0 &&
            shadowMapCoord.x <= 1 &&
            shadowMapCoord.y >= 0 &&
            shadowMapCoord.y <= 1 &&
            
            lightDistance >= shadowMapDistance &&
            shadowMapDistance != 1.0f) ? vec4(.3, 0.4, .5, 1) : vec4(1);
}

vec4 shadowMap(in sampler2D sampler, in vec4 lightSpacePos)
{
    vec2 shadowMapCoord = 0.5f * lightSpacePos.xy / lightSpacePos.w + vec2(0.5f, 0.5f);
    const float bias = -0.0008f; // avoid shadow aliasing by offseting the shadow a bit
    float lightDistance = 0.5f + bias + lightSpacePos.z / lightSpacePos.w * 0.5f;

    vec4 val = vec4(0, 0, 0, 1);
    const float o1 = 0.001f;
    const float o2 = 0.0005f;

#if SHADOWMAPPING_SAMPLES > 0
    val += shadowMapSingle(sampler, shadowMapCoord + vec2(-o1 + 0.0001, -o1), lightDistance);
#endif

#if SHADOWMAPPING_SAMPLES > 1
    val += shadowMapSingle(sampler, shadowMapCoord + vec2(o1, -o1 + 0.0001), lightDistance);
#endif
    
#if SHADOWMAPPING_SAMPLES > 2
    val += shadowMapSingle(sampler, shadowMapCoord + vec2(o1 - 0.0001, o1), lightDistance);
#endif

#if SHADOWMAPPING_SAMPLES > 3 
    val += shadowMapSingle(sampler, shadowMapCoord + vec2(-o1, o1 - 0.0001), lightDistance);
#endif

#if SHADOWMAPPING_SAMPLES > 4
    val += shadowMapSingle(sampler, shadowMapCoord + vec2(-o2, -o2 + 0.0001), lightDistance);
#endif

#if SHADOWMAPPING_SAMPLES > 5    
    val += shadowMapSingle(sampler, shadowMapCoord + vec2(o2 + 0.0001, -o2), lightDistance);
#endif
    
#if SHADOWMAPPING_SAMPLES > 6
    val += shadowMapSingle(sampler, shadowMapCoord + vec2(o2, o2 - 0.0001), lightDistance);
#endif

#if SHADOWMAPPING_SAMPLES > 7
    val += shadowMapSingle(sampler, shadowMapCoord + vec2(-o2 - 0.0001, o2), lightDistance);
#endif
    
    val /= SHADOWMAPPING_SAMPLES;
    return val;
}

#endif
