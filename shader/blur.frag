// Separable blur fragment shader.
// direction: vec2(1,0) for horizontal, vec2(0,1) for vertical
// radius: blur radius in pixels (controls sample spacing)
// texelSize: vec2(1.0/width, 1.0/height)

uniform vec2 direction;
uniform float radius;
uniform vec2 texelSize;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
    // Use a wider symmetric kernel and compute gaussian weights.
    // To make `radius` control the blur extent while keeping sampling dense,
    // we compute a sampling `step` that divides the target radius into N steps.
    const int N = 8; // results in 17 taps
    float sigma = max(1.0, radius * 0.5);
    float twoSigma2 = 2.0 * sigma * sigma;
    float step = max(1.0, radius / float(N));
    vec4 sum = vec4(0.0);
    float wsum = 0.0;
    for (int i = -N; i <= N; ++i) {
        float fi = float(i);
        float pos = fi * step; // distance in texels
        float weight = exp(-(pos*pos) / twoSigma2);
        vec2 off = direction * (pos) * texelSize;
        sum += Texel(tex, tc + off) * weight;
        wsum += weight;
    }
    return sum / wsum;
}
