varying vec3 WorldPos;
varying vec3 Normal;

// Textures
uniform sampler2D albedoMap;
uniform sampler2D normalMap;
uniform sampler2D metallicMap;
uniform sampler2D roughnessMap;
uniform sampler2D aoMap;
uniform sampler2D alphaMap;
uniform int useAlphaMap;
uniform int enableTransparency;
uniform sampler2D emissiveMap;
uniform float emissiveIntensity;
uniform int useEmissiveMap;
uniform int renderEmissiveOnly;
uniform int debugShowFaces;
uniform int debugShowNormals;

// lights
uniform vec3  lightPositions[4];
uniform vec3 lightColors[4];

uniform vec3 camPos;
// directional (single) light
uniform vec3 dirLightDir;
uniform vec3 dirLightColor;
uniform int useDirectionalLight;
// ambient intensity multiplier
uniform float ambientIntensity;
// NOTE (WORKAROUND): When rendering into a Canvas, LÖVE flips the Y
// coordinate. That flip changes the sign of dFdy/dFdx derivatives used
// to compute tangent/bitangent (T/B) from screen-space derivatives, which
// can invert the computed normal from normal maps. To compensate we expose
// `isCanvasEnabled` (set by the Canvas-rendering path) and invert the
// appropriate derivatives when it's set. This is a pragmatic workaround
// to match Canvas and direct-screen rendering behavior.
uniform int isCanvasEnabled;

const float PI = 3.14159265359;
// ----------------------------------------------------------------------------
vec3 getNormalFromMap(sampler2D normalMap, vec2 TexCoords)
{
    vec3 tangentNormal = Texel(normalMap, TexCoords).xyz * 2.0 - 1.0;

    vec3 Q1  = dFdx(WorldPos);
    vec3 Q2  = dFdy(WorldPos);
    vec2 st1 = dFdx(TexCoords);
    vec2 st2 = dFdy(TexCoords);

    // If rendering to a Canvas, LÖVE flips the Y coordinate in the
    // vertex stage; this reverses the sign of dFdy. Compensate here so
    // the TBN handedness remains consistent with direct-screen rendering.
    if (isCanvasEnabled == 1) {
        Q2 = -Q2;
        st2 = -st2;
    }

    vec3 N   = normalize(Normal);
    vec3 T  = normalize(Q1*st2.t - Q2*st1.t);
    vec3 B  = -normalize(cross(N, T));
    mat3 TBN = mat3(T, B, N);

    return normalize(TBN * tangentNormal);
}
// ----------------------------------------------------------------------------
float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness*roughness;
    float a2 = a*a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}
// ----------------------------------------------------------------------------

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    // // Force discard of back-facing fragments to avoid rendering reversed-triangle artifacts
    // if (!gl_FrontFacing) discard;
    vec3 albedo     = pow(Texel(albedoMap, texture_coords).rgb, vec3(2.2));
    float metallic  = Texel(metallicMap, texture_coords).r;
    float roughness = Texel(roughnessMap, texture_coords).r;
    float ao        = Texel(aoMap, texture_coords).r;

    float alpha = 1.0;
    if (enableTransparency == 1) {
        if (useAlphaMap == 1) {
            alpha = Texel(alphaMap, texture_coords).r;
        } else {
            alpha = Texel(albedoMap, texture_coords).a;
        }
        // Skip expensive lighting when fully transparent (alpha near 0)
        if (alpha < 0.01) {
            return vec4(0.0, 0.0, 0.0, 0.0);
        }
    }

    vec3 N = getNormalFromMap(normalMap,texture_coords);
    vec3 V = normalize(camPos - WorldPos);

    // Debug: if requested, visualize front/back faces or normals for any render mode
    if (debugShowFaces == 1) {
        if (gl_FrontFacing) {
            return vec4(1.0, 0.0, 0.0, 1.0);
        } else {
            return vec4(0.0, 0.0, 1.0, 1.0);
        }
    }
    if (debugShowNormals == 1) {
        vec3 nvis = normalize(N) * 0.5 + 0.5;
        return vec4(nvis, 1.0);
    }

    // Material base reflectance
    vec3 F0 = vec3(0.04); 
    F0 = mix(F0, albedo, metallic);

    // BRDF / reflection calculation
    vec3 Lo = vec3(0.0);
    for(int i = 0; i < 4; ++i) 
    {
        vec3 L = normalize(lightPositions[i] - WorldPos); // light direction
        vec3 H = normalize(V + L); // half vector
        float distance = length(lightPositions[i] - WorldPos);
        float attenuation = 1.0 / (distance * distance); // attenuation (inverse square)

        // BRDF: weight incoming radiance by surface properties
        float D = DistributionGGX(N, H, roughness);   
        vec3  F = fresnelSchlick(clamp(dot(H, V), 0.0, 1.0), F0);
        float G = GeometrySmith(N, V, L, roughness);      
        float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001; // +0.0001 prevent divide-by-zero
        vec3 specular = D * G * F / denominator;
        
        vec3 kS = F; // specular reflectance = Fresnel
        vec3 kD = vec3(1.0) - kS; // energy conservation: diffuse = 1 - specular
        kD *= 1.0 - metallic; // metals have no diffuse component

        vec3 radiance = lightColors[i] * attenuation; // incoming radiance
        float NdotL = max(dot(N, L), 0.0);
        // final composition
        Lo += (kD * albedo / PI + specular) * radiance * NdotL;
    }   
    // directional light contribution (no attenuation, single global direction)
    if (useDirectionalLight == 1) {
        vec3 L = normalize(-dirLightDir);
        vec3 H = normalize(V + L);
        float D = DistributionGGX(N, H, roughness);
        vec3  F = fresnelSchlick(clamp(dot(H, V), 0.0, 1.0), F0);
        float G = GeometrySmith(N, V, L, roughness);
        float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
        vec3 specular = D * G * F / denominator;
        vec3 kS = F;
        vec3 kD = vec3(1.0) - kS;
        kD *= 1.0 - metallic;
        vec3 radiance = dirLightColor;
        float NdotL = max(dot(N, L), 0.0);
        Lo += (kD * albedo / PI + specular) * radiance * NdotL;
    }
    
    vec3 ambient = vec3(ambientIntensity) * albedo * ao; // ambient light
    vec3 _color = ambient + Lo;
    // emissive contribution (in sRGB -> linear conversion consistent with albedo)
    vec3 emissive = vec3(0.0);
    if (useEmissiveMap == 1) {
        emissive = pow(Texel(emissiveMap, texture_coords).rgb, vec3(2.2));
    }
    emissive *= emissiveIntensity;
    if (renderEmissiveOnly == 1) {
        // Emissive-only: tonemap + gamma so capture matches final appearance
        vec3 em = emissive;
        vec3 em_mapped = em / (em + vec3(1.0));
        em_mapped = pow(em_mapped, vec3(1.0/2.2));
        float a = (length(emissive) > 0.0) ? 1.0 : 0.0;
        return vec4(em_mapped, a);
    }
    // Add emissive to final color and always tonemap+gamma (no toggle)
    _color += emissive;
    vec3 mapped = _color / (_color + vec3(1.0)); // HDR tone mapping
    mapped = pow(mapped, vec3(1.0/2.2)); // gamma correction
    return vec4(mapped, alpha);
}
