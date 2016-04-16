// effects from http://www.slickentertainment.com/tech/dev-blog-208-cinematic-effects/

#ifdef GL_ES
precision mediump float;
#endif

float VignetteRadius = 0.65;
float VignetteSoftness = 0.5;
float VignetteOpacity = 0.4;

float FilmGrainAmount = 0.05;
float FilmGrainSeed = 8.42;

uniform sampler2D tex0;
varying vec2 tcoord;
uniform float time;
uniform vec2 resolution;

// inputColor is the color of the final image for the pixel
// texCoord is the coordinate of the pixel on screen, in the range [0,1].
vec4 CalculateVignette(vec4 inputColor, vec2 texCoord) {
    vec2 dist = (texCoord - 0.5);
    float len = length(dist);
    float vignette = smoothstep(VignetteRadius, VignetteRadius-VignetteSoftness, len);

    vec4 result;
    result.xyz = mix(inputColor.xyz, inputColor.xyz * vignette, VignetteOpacity);
    result.w = inputColor.w;
    return result;
}

vec3 Random3D(vec2 uv) {
    float noiseX = fract(sin(dot(uv, vec2(12.9898,78.233) + FilmGrainSeed)) * 43758.5453);
    float noiseY = fract(sin(dot(uv, vec2(12.9898,78.233) * 1.2345 + FilmGrainSeed)) * 43758.5453);
    float noiseZ = fract(sin(dot(uv, vec2(12.9898,78.233) * 2.1314 + FilmGrainSeed)) * 43758.5453);
    return vec3(noiseX, noiseY, noiseZ);
}

// inputColor is the color of the final image for the pixel the vignette is calculated for
// texCoord is the coordinate of the pixel on screen, in the range [0,1] for both x and y.
vec4 CalculateFilmGrain(vec4 inputColor, vec2 texCoord) {
	float luminance = dot(inputColor, vec4(0.299,0.587,0.114,0.0));
	float lum = luminance + smoothstep(0.2,0.0,luminance);
	vec4 noise = vec4(mix((Random3D(texCoord) - 0.5),vec3(0.0), pow(lum,4.0)), 0.0);
	return inputColor + (noise * FilmGrainAmount);
}

float ChromaticAberrationInnerAmount = 3.0;
float ChromaticAberrationOuterAmount = 9.0;
float ChromaticAberrationCurvePower = 0.4;

vec4 CalculateChromaticAberration(sampler2D textureSampler, vec2 texCoord) {
    vec2 dist = (texCoord - 0.5);
    float len = length(dist);

    float power = pow(smoothstep(0.707, 0.0, len), ChromaticAberrationCurvePower);  // [0-1]
    float aberrationAmount = mix(ChromaticAberrationOuterAmount, ChromaticAberrationInnerAmount, power) * 0.001;

    vec4 r = texture2D(textureSampler, texCoord + vec2(aberrationAmount, 0.0));
    vec4 g = texture2D(textureSampler, texCoord + vec2(0.0, 0.0));
    vec4 b = texture2D(textureSampler, texCoord + vec2(-aberrationAmount, 0.0));

    return vec4(r.x, g.y, b.z, 1.0);
}

// Bloom:
const int samples = 3; // pixels per axis; higher = bigger glow, worse performance
const float quality = 2.5; // lower = smaller glow, better quality
const float bloomAmount = 0.5;

vec4 Bloom(sampler2D textureSampler, vec2 texCoord) {
    vec4 source = texture2D(textureSampler, texCoord);
    vec4 sum = vec4(0);
    const int diff = (samples - 1) / 2;
    vec2 sizeFactor = vec2(1) / resolution.xy * quality;

    for (int x = -diff; x <= diff; x++) {
        for (int y = -diff; y <= diff; y++) {
            vec2 offset = vec2(x, y) * sizeFactor;
            sum += texture2D(tex0, tcoord + offset);
        }
    }

    return ((sum / float(samples * samples)) * bloomAmount + source);
}

const float bluramount  = 0.8;
const float center      = 1.1;
const float stepSize    = 0.004;
const float steps       = 3.0;

const float minOffs     = (float(steps-1.0)) / -2.0;
const float maxOffs     = (float(steps-1.0)) / +2.0;

vec4 TiltShift(sampler2D textureSampler, vec2 texCoord) {
    float amount;
    vec4 blurred;

        //Work out how much to blur based on the mid point
    amount = pow((tcoord.y * center) * 2.0 - 1.0, 2.0) * bluramount;

        //This is the accumulation of color from the surrounding pixels in the texture
    blurred = vec4(0.0, 0.0, 0.0, 1.0);

        //From minimum offset to maximum offset
    for (float offsX = minOffs; offsX <= maxOffs; ++offsX) {
        for (float offsY = minOffs; offsY <= maxOffs; ++offsY) {

                //copy the coord so we can mess with it
            vec2 temp_tcoord = texCoord.xy;

                //work out which uv we want to sample now
            temp_tcoord.x += offsX * amount * stepSize;
            temp_tcoord.y += offsY * amount * stepSize;

                //accumulate the sample
            blurred += texture2D(textureSampler, temp_tcoord);

        } //for y
    } //for x

        //because we are doing an average, we divide by the amount (x AND y, hence steps * steps)
    blurred /= float(steps * steps);

        //return the final blurred color
    return blurred;
}

uniform float chroma;

void main() {
	vec2 uv = tcoord.xy;
    //vec4 color = texture2D(tex0, uv);
    //ChromaticAberrationInnerAmount = sin(time) * 15.0;
    //ChromaticAberrationOuterAmount = sin(time) * 30.0;
    //ChromaticAberrationCurvePower = cos(time);
    //vec4 rawColor = CalculateChromaticAberration(tex0, uv);
	//gl_FragColor = CalculateFilmGrain(CalculateVignette(rawColor, uv), uv);

    vec4 rawColor = Bloom(tex0, uv) * 0.8 + TiltShift(tex0, uv) * 0.4 + CalculateChromaticAberration(tex0, uv) * chroma;
    gl_FragColor = CalculateFilmGrain(CalculateVignette(rawColor, uv), uv); //CalculateVignette(rawColor, uv);
}
