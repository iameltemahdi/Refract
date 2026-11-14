#ifndef REFRACT_GLASS_H
#define REFRACT_GLASS_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef enum GlassSurface : uint32_t {
    GlassFluted,
    GlassBlinds,
    GlassLiquid,
    GlassPebbled,
    GlassDiamond,
    GlassShear,
    GlassFrosted,
    GlassConcentric,
    GlassWoven,
    GlassShattered,
    GlassHoneycomb,
    GlassRaindrop,
    GlassChevron,
    GlassPrism,
    GlassChecker,
    GlassSpiral,
    GlassCrimped,
    GlassFan,
} GlassSurface;

typedef struct { float r, g, b; } GlassColor;

typedef struct {
    GlassColor start, end;
    float cosine, sine;
    uint32_t kind;
} GlassGradient;

typedef struct {
    float strength, scale, angle, dispersion;
    float light, lensStrength, lensDensity, feather;
    GlassSurface effect, secondSurface;
    float blend, secondDensity, secondAngle, phase, stretch;
    uint32_t source, region;
    GlassGradient gradient;
} GlassOptions;

void glassRender(const uint8_t *source, uint32_t sourceWidth, uint32_t sourceHeight,
                 uint8_t *output, uint32_t width, uint32_t height, GlassOptions options);
#ifdef __cplusplus
}
#endif

#endif
