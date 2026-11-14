struct GlassEffect: Identifiable {
    let id: GlassSurface
    let name: String
    let detail: String
    let scale: Double
    let angle: Double
    let strength: Double

    static let all: [Self] = [
        .init(id: GlassFluted, name: "Fluted", detail: "Vertical ribs", scale: 9, angle: 0, strength: 0.98),
        .init(id: GlassBlinds, name: "Blinds", detail: "Horizontal slats", scale: 10, angle: 0, strength: 0.76),
        .init(id: GlassLiquid, name: "Liquid", detail: "Flowing ripples", scale: 21, angle: 0, strength: 0.96),
        .init(id: GlassPebbled, name: "Pebbled", detail: "Rounded cells", scale: 15, angle: 0, strength: 0.93),
        .init(id: GlassDiamond, name: "Diamond", detail: "Cut facets", scale: 11, angle: 44, strength: 0.82),
        .init(id: GlassShear, name: "Shear", detail: "Drawn glass", scale: 11, angle: -33, strength: 0.95),
        .init(id: GlassFrosted, name: "Frosted", detail: "Diffuse texture", scale: 30, angle: 0, strength: 0.78),
        .init(id: GlassConcentric, name: "Concentric", detail: "Optical rings", scale: 11, angle: 0, strength: 0.89),
        .init(id: GlassWoven, name: "Woven", detail: "Crossed ribs", scale: 18, angle: 28, strength: 0.85),
        .init(id: GlassShattered, name: "Shattered", detail: "Irregular facets", scale: 16, angle: -18, strength: 0.9),
        .init(id: GlassHoneycomb, name: "Honeycomb", detail: "Hexagonal lenses", scale: 12, angle: 0, strength: 0.93),
        .init(id: GlassRaindrop, name: "Raindrop", detail: "Staggered drops", scale: 10, angle: 0, strength: 1.05),
        .init(id: GlassChevron, name: "Chevron", detail: "Folded slats", scale: 11, angle: 0, strength: 0.95),
        .init(id: GlassPrism, name: "Prism", detail: "Stepped refraction", scale: 8, angle: 22, strength: 0.94),
        .init(id: GlassChecker, name: "Checker", detail: "Alternating facets", scale: 10, angle: 0, strength: 0.97),
        .init(id: GlassSpiral, name: "Spiral", detail: "Twisted rings", scale: 10, angle: 0, strength: 1.01),
        .init(id: GlassCrimped, name: "Crimped", detail: "Corrugated waves", scale: 11, angle: 0, strength: 0.96),
        .init(id: GlassFan, name: "Fan", detail: "Pressed arches", scale: 10, angle: 0, strength: 0.86),
    ]
}
