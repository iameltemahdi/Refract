#include "Glass.h"
#include <algorithm>
#include <cmath>
#include <dispatch/dispatch.h>

using float2 = float __attribute__((ext_vector_type(2)));
using float4 = float __attribute__((ext_vector_type(4)));

static inline float2 make2(float v) { return { v, v }; }
static inline float2 make2(float x, float y) { return { x, y }; }
static inline float4 make4(float x, float y, float z, float w) { return { x, y, z, w }; }

using std::abs;
using std::atan2;
using std::cos;
using std::exp;
using std::floor;
using std::max;
using std::min;
using std::sin;
using std::pow;
using std::tanh;

static inline float squared(float x) { return x * x; }
static inline float fract(float x) { return x - floor(x); }
static inline float2 fract(float2 v) { return { fract(v.x), fract(v.y) }; }
static inline float2 floor(float2 v) { return { floor(v.x), floor(v.y) }; }
static inline float dot(float2 a, float2 b) { return a.x * b.x + a.y * b.y; }
static inline float length(float2 v) { return std::sqrt(dot(v, v)); }
static inline float2 normalize(float2 v) { return v / max(0.00001f, length(v)); }
static inline float sign(float x) { return (x > 0) - (x < 0); }
static inline float step(float edge, float x) { return x >= edge ? 1.0f : 0.0f; }
static inline float smoothstep(float a, float b, float x) {
    float v = std::clamp((x - a) / (b - a), 0.0f, 1.0f);
    return v * v * (3.0f - 2.0f * v);
}
template<typename V> static inline V mix(V a, V b, float t) { return a + (b - a) * t; }

constexpr float tau = 6.28318530718f;

float2 rotatePoint(float2 p, float angle) {
    float c = cos(angle), s = sin(angle);
    return make2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float hashCell(float2 p) {
    return fract(sin(dot(p, make2(127.1f, 311.7f))) * 43758.5453f);
}

float2 hashCenter(float2 p) {
    return make2(hashCell(p), hashCell(p + 17.39f));
}

float2 cellular(float2 x) {
    float2 id = floor(x), local = fract(x);
    float dist = 4.0f;
    float2 nearest = make2(0.0f);
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            float2 n = make2(i, j);
            float2 delta = local - n - (0.18f + 0.64f * hashCenter(id + n));
            float d = dot(delta, delta);
            if (d < dist) {
                dist = d;
                nearest = delta;
            }
        }
    }
    return nearest;
}

float4 gradientColor(float2 uv, float2 aspect, const GlassGradient &gradient) {
    float2 point = (uv - 0.5f) * aspect;
    float2 direction = make2(gradient.cosine, gradient.sine);
    float position;
    if (gradient.kind == 1) {
        position = length(point) * 2.0f / length(aspect);
    } else {
        float span = dot(make2(abs(direction.x), abs(direction.y)), aspect);
        position = 0.5f + dot(point, direction) / span;
    }
    float amount = std::clamp(position, 0.0f, 1.0f);
    const auto &a = gradient.start;
    const auto &b = gradient.end;
    return mix(make4(a.r, a.g, a.b, 1.0f), make4(b.r, b.g, b.b, 1.0f), amount);
}

float2 relief(float2 p, GlassSurface effect, float phase, float &rim) {
    float x = p.x, y = p.y;
    rim = 0.0f;
    switch (effect) {
        case GlassFluted: { // Fluted glass: variable cylindrical flutes with thin seams.
            float groove = x + 0.13f * sin(y * 0.69f + phase) + 0.13f * sin(x * 0.84f);
            float t = fract(groove) - 0.5f;
            float edge = smoothstep(0.34f, 0.50f, abs(t));
            rim = 0.8f * exp(-squared((abs(t) - 0.468f) * 32.0f)) - 0.28f * edge;
            return make2(1.12f * sin(t * 3.14159f) * (1.0f - edge * 0.33f),
                          0.13f * sin(groove * tau + y * 0.32f) + 0.16f * sin(y * 0.70f + x * 0.4f));
        }
        case GlassBlinds: { // Blinds refract perpendicular to densely packed horizontal slats.
            float t = fract(y + 0.035f * sin(x * 0.6f) + phase * 0.13f);
            rim = 0.55f * exp(-squared((t - 0.09f) * 23.0f)) - 0.34f * exp(-squared((t - 0.02f) * 20.0f));
            return make2(0.34f * sin(t * tau) + 0.20f * sin(y * 2.18f), 1.26f * tanh((t - 0.45f) * 3.2f));
        }
        case GlassLiquid: { // Rippled liquid glass.
            float a = sin(x * 2.83f + 1.65f * sin(y * 1.43f + phase));
            float b = cos(y * 3.14f - 1.8f * cos(x * 1.27f + phase));
            rim = 0.40f * pow(max(a * b, 0.0f), 5.0f) - 0.13f;
            return make2(a + b * 0.30f, b + a * 0.31f) * 0.60f;
        }
        case GlassPebbled: { // Rounded pebble cells with irregular centers.
            float2 cell = cellular(p * 0.95f);
            float r = length(cell);
            rim = 0.51f * exp(-squared((r - 0.39f) * 12.0f)) * dot(normalize(cell + 0.0001f), make2(-0.6f, -0.8f));
            return cell * (3.9f - 3.8f * r);
        }
        case GlassDiamond: { // Diamond-cut facets with diagonal edges.
            float2 f = fract(p * 0.86f) - 0.5f;
            float turn = abs(f.x) > abs(f.y) ? 1.0f : 0.0f;
            float2 facet = mix(make2(0.0f, sign(f.y)), make2(sign(f.x), 0.0f), turn);
            float join = abs(abs(f.x) - abs(f.y));
            rim = 0.75f * exp(-join * 28.0f) + 0.34f * exp(-(0.5f - max(abs(f.x), abs(f.y))) * 25.0f);
            return facet * (0.48f + 0.67f * smoothstep(0.0f, 0.29f, join)) + f * 0.85f;
        }
        case GlassShear: { // Vertically drawn optical shear.
            float t = fract(x + 0.22f * sin(y * 0.39f + phase)) - 0.5f;
            float sharp = sin(t * tau);
            rim = 0.69f * pow(abs(sharp), 17.0f) - 0.25f;
            return make2(0.34f * sharp, 1.49f * sin(t * tau + 0.81f) + 0.39f * sin(x * 1.11f + y * 0.67f));
        }
        case GlassFrosted: { // Soft frost with multi-scale surface ripples.
            float2 fine = make2(sin(x * 7.0f + y * 3.0f), cos(y * 8.0f - x * 2.0f));
            float2 medium = make2(cos(x * 3.0f - y * 1.4f + phase), sin(y * 3.5f + x * 1.3f));
            rim = 0.22f * (fine.x + medium.y);
            return fine * 0.29f + medium * 0.48f;
        }
        case GlassConcentric: { // Concentrically pressed glass.
            float r = length(p);
            float t = r * 4.95f + 0.36f * sin(atan2(y, x) * 4.0f + phase);
            rim = 0.45f * pow(max(sin(t + 0.6f), 0.0f), 9.0f) - 0.14f;
            return (p / max(r, 0.001f)) * (0.88f * sin(t) + 0.12f * sin(t * 2.0f));
        }
        case GlassWoven: { // Woven, cross-pressed ridges.
            float a = sin(x * tau + 0.42f * sin(y * tau));
            float b = sin(y * tau - 0.42f * sin(x * tau));
            rim = 0.62f * pow(max(a * b, 0.0f), 5.0f) - 0.14f;
            return make2(a * (0.60f + 0.30f * b), b * (0.60f - 0.30f * a));
        }
        case GlassShattered: { // Broken-ice facets.
            float2 q = p * 0.69f + 0.17f * make2(sin(y + phase), cos(x));
            float2 facet = cellular(q);
            float r = length(facet);
            float seam = abs(facet.y + facet.x * 0.72f);
            rim = 0.66f * exp(-seam * 16.0f) - 0.15f;
            return (facet + make2(sign(facet.x), sign(facet.y)) * 0.22f) * (2.0f - r);
        }
        case GlassHoneycomb: {
            // Two offset rectangular grids form one triangular lattice.
            float2 spacing = make2(1.0f, 1.73205f);
            float2 a = (fract(p / spacing + 0.5f) - 0.5f) * spacing;
            float2 b = (fract(p / spacing) - 0.5f) * spacing;
            float2 cell = dot(a, a) < dot(b, b) ? a : b;
            float edge = max(abs(cell.x), 0.5f * abs(cell.x) + 0.866025f * abs(cell.y));
            rim = 0.68f * exp(-squared((edge - 0.48f) * 35.0f));
            return cell * (1.5f + 1.65f * smoothstep(0.22f, 0.50f, edge));
        }
        case GlassRaindrop: {
            float row = floor(y * 0.75f);
            float offset = (static_cast<int>(row) & 1) * 0.5f;
            float2 cell = make2(fract(x + offset) - 0.5f, fract(y * 0.75f) - 0.48f);
            float2 lens = make2(cell.x * 1.35f, cell.y * 0.84f);
            float radius = length(lens);
            float dome = 1.0f - smoothstep(0.27f, 0.43f, radius);
            rim = 0.66f * exp(-squared((radius - 0.32f) * 24.0f)) * (0.22f - lens.y);
            return lens * (2.8f * dome) + make2(0.06f * sin(y * 2.0f), 0.12f * sin(x * tau));
        }
        case GlassChevron: {
            float fold = abs(fract(x * 0.5f) - 0.5f) * 2.0f;
            float slat = y + fold * 1.15f;
            float t = fract(slat) - 0.5f;
            float side = sign(fract(x * 0.5f) - 0.5f);
            rim = 0.75f * exp(-squared((abs(t) - 0.45f) * 31.0f)) - 0.2f;
            return make2(side * 0.58f, 1.0f) * sin(t * 3.14159f) * 1.3f;
        }
        case GlassPrism: {
            float u = fract(x);
            float cut = floor(u * 3.0f) - 1.0f;
            float seam = abs(fract(u * 3.0f) - 0.5f);
            rim = 0.75f * smoothstep(0.36f, 0.50f, seam) - 0.20f;
            return make2(cut * 0.97f + 0.16f * sin(y * 1.3f), -cut * 0.54f + (u - 0.5f) * 0.41f);
        }
        case GlassChecker: {
            float2 cell = fract(p) - 0.5f;
            int tile = static_cast<int>(floor(x)) + static_cast<int>(floor(y));
            float flip = (tile & 1) ? 1.0f : -1.0f;
            float edge = max(abs(cell.x), abs(cell.y));
            rim = 0.73f * exp(-squared((edge - 0.46f) * 30.0f)) * flip;
            return cell * (1.75f * flip) + make2(0.33f, -0.22f) * flip;
        }
        case GlassSpiral: {
            float radius = length(p);
            float2 radial = p / max(radius, 0.001f);
            float coil = radius * 4.25f + atan2(y, x) * 2.0f;
            float width = min(radius, 1.0f);
            rim = width * (0.67f * pow(max(cos(coil), 0.0f), 14.0f) - 0.15f);
            return make2(-radial.y, radial.x) * sin(coil) * (1.28f * width)
                 + radial * cos(coil) * (0.50f * width);
        }
        case GlassCrimped: {
            float wave = y + 0.29f * sin(x * 3.4f) + 0.08f * sin(x * 7.0f + y * 1.2f);
            float groove = sin(wave * tau);
            rim = 0.59f * pow(max(groove, 0.0f), 10.0f) - 0.18f;
            return make2(0.44f * cos(x * 3.4f), 1.18f) * groove;
        }
        case GlassFan: {
            float row = floor(y * 0.79f);
            float offset = (static_cast<int>(row) & 1) * 0.5f;
            float2 arch = make2(fract(x + offset) - 0.5f, fract(y * 0.79f) + 0.14f);
            float ray = atan2(arch.x, arch.y) * 7.0f;
            float arc = cos(length(arch) * 10.0f);
            rim = 0.51f * pow(max(cos(ray), 0.0f), 9.0f) + 0.16f * arc;
            return normalize(arch) * (0.50f * arc) + make2(arch.y, -arch.x) * (0.87f * sin(ray));
        }
    }
    return make2(0.0f);
}

float regionCoverage(float2 uv, unsigned region, float softness) {
    if (region == 0) return 1.0f;
    float d = (region < 3 ? uv.y : uv.x) - 0.5f;
    if (region == 1 || region == 3) d = -d;
    if (softness < 0.0005f) return step(0.0f, d);
    return smoothstep(-softness, softness, d);
}

static inline float mirror(float x) {
    return 1.0f - abs(fract(x * 0.5f) * 2.0f - 1.0f);
}

static inline float4 decode(const uint8_t *p) {
    return make4(p[0], p[1], p[2], p[3]) * (1.0f / 255.0f);
}

struct Plate {
    const uint8_t *data;
    unsigned width, height;

    float4 sample(float2 uv, const GlassOptions &settings, float2 aspect) const {
        float2 mirrored = make2(mirror(uv.x), mirror(uv.y));
        if (settings.source == 1) return gradientColor(mirrored, aspect, settings.gradient);
        float x = std::clamp(mirrored.x * width - 0.5f, 0.0f, float(width - 1));
        float y = std::clamp(mirrored.y * height - 0.5f, 0.0f, float(height - 1));
        unsigned x0 = unsigned(x), y0 = unsigned(y);
        unsigned x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1);
        const uint8_t *row0 = data + size_t(y0) * width * 4;
        const uint8_t *row1 = data + size_t(y1) * width * 4;
        float4 a = mix(decode(row0 + x0 * 4), decode(row0 + x1 * 4), x - x0);
        float4 b = mix(decode(row1 + x0 * 4), decode(row1 + x1 * 4), x - x0);
        return mix(a, b, y - y0);
    }
};

struct Render {
    Plate source;
    uint8_t *output;
    unsigned width, height;
    GlassOptions settings;
    float2 aspect;
    float cosine, sine;
    float secondCosine, secondSine;

    float2 rotate(float2 p) const {
        return make2(cosine * p.x - sine * p.y, sine * p.x + cosine * p.y);
    }
    float2 unrotate(float2 p) const {
        return make2(cosine * p.x + sine * p.y, -sine * p.x + cosine * p.y);
    }

    float4 pixel(float2 uv) const {
        float coverage = regionCoverage(uv, settings.region, settings.feather);
        float strength = settings.strength * coverage;
        if (strength < 0.00001f) return source.sample(uv, settings, aspect);

        float cells = settings.scale;
        float2 plane = rotate((uv - 0.5f) * aspect);
        float2 stretch = make2(settings.stretch, 1.0f);
        float2 origin = make2(0.37f + settings.phase, 0.11f + settings.phase * 0.61f);
        float rim;
        float2 tangent = relief(plane / stretch * cells + origin, settings.effect, 0.36f, rim);
        tangent *= stretch;
        if (settings.blend > 0.0f) {
            float2 turned = make2(secondCosine * plane.x - secondSine * plane.y,
                                  secondSine * plane.x + secondCosine * plane.y);
            float secondRim;
            float2 second = relief(turned * (cells * settings.secondDensity) + origin,
                                   settings.secondSurface, 0.36f, secondRim);
            second = make2(secondCosine * second.x + secondSine * second.y,
                          -secondSine * second.x + secondCosine * second.y);
            tangent = mix(tangent, second / settings.secondDensity, settings.blend);
            rim = mix(rim, secondRim, settings.blend);
        }
        float2 shift = unrotate(tangent) * (strength * 0.69f / cells) / aspect;
        float2 sampleUV = uv + shift;
        float micro = settings.lensStrength * coverage;
        if (micro > 0.0f) {
            float density = settings.lensDensity;
            float2 lattice = plane * density + make2(0.28f, 0.61f) + tangent * 0.44f;
            lattice.x += (static_cast<int>(floor(lattice.y)) & 1) * 0.5f;
            float2 lens = fract(lattice) - 0.5f;
            float r = length(lens);
            float envelope = 1.0f - smoothstep(0.33f, 0.53f, r);
            float2 bend = unrotate(lens * (1.45f - r) * envelope);
            sampleUV += bend * (micro * min(strength * 3.5f, 1.0f) / density) / aspect;
            rim += micro * (0.74f * exp(-squared((r - 0.37f) * 15.0f))
                            * dot(lens * 2.0f, make2(-0.65f, -0.76f)) - 0.19f * envelope);
        }

        float4 color = source.sample(sampleUV, settings, aspect);
        if (settings.dispersion > 0.0001f) {
            float2 chroma = (shift + (sampleUV - uv - shift) * 0.55f) * settings.dispersion * 0.29f;
            float4 red = source.sample(sampleUV - chroma, settings, aspect);
            float4 blue = source.sample(sampleUV + chroma, settings, aspect);
            color = make4(red.r, color.g, blue.b, max(color.a, max(red.a, blue.a)));
        }
        if (settings.effect == GlassFrosted) {
            float radius = 0.0034f * strength;
            float4 a = source.sample(sampleUV + make2(radius, -radius), settings, aspect);
            float4 b = source.sample(sampleUV - make2(radius, -radius), settings, aspect);
            color = mix(color, (a + b) * 0.5f, 0.60f * min(strength, 1.0f));
        }
        float glow = rim * settings.light * min(strength, 1.0f);
        for (int channel = 0; channel < 3; ++channel) {
            color[channel] = std::clamp(color[channel] * (1.0f + glow * 0.36f)
                                      + glow * 0.105f * color.a, 0.0f, color.a);
        }
        return color;
    }

    void drawStripe(size_t stripe) const {
        constexpr unsigned rowsPerStripe = 16;
        unsigned first = unsigned(stripe) * rowsPerStripe;
        unsigned last = min(first + rowsPerStripe, height);
        for (unsigned y = first; y < last; ++y) {
            uint8_t *row = output + size_t(y) * width * 4;
            float py = (y + 0.5f) / height;
            for (unsigned x = 0; x < width; ++x) {
                float4 color = pixel(make2((x + 0.5f) / width, py));
                for (int channel = 0; channel < 4; ++channel) {
                    row[x * 4 + channel] = uint8_t(color[channel] * 255.0f + 0.5f);
                }
            }
        }
    }
};

void glassRender(const uint8_t *source, uint32_t sourceWidth, uint32_t sourceHeight,
                 uint8_t *output, uint32_t width, uint32_t height, GlassOptions options) {
    float shortSide = float(min(width, height));
    Render render { { source, sourceWidth, sourceHeight }, output, width, height, options,
                    make2(width / shortSide, height / shortSide), cos(options.angle), sin(options.angle),
                    cos(options.secondAngle), sin(options.secondAngle) };
    dispatch_apply_f((height + 15) / 16, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                     &render, [](void *context, size_t index) {
        static_cast<const Render *>(context)->drawStripe(index);
    });
}
