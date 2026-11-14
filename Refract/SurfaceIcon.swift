import SwiftUI

struct SurfaceIcon: View {
    let surface: GlassSurface
    let selected: Bool

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2,
                              width: side, height: side)
            let tile = Path(roundedRect: rect, cornerRadius: 6)
            context.fill(tile, with: .color(.primary.opacity(selected ? 0.13 : 0.06)))

            var mark = Path()
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + (x + 4) * side / 32, y: rect.minY + (y + 4) * side / 32)
            }
            func line(_ vertices: [(CGFloat, CGFloat)], closed: Bool = false) {
                guard let first = vertices.first else { return }
                mark.move(to: point(first.0, first.1))
                for (x, y) in vertices.dropFirst() { mark.addLine(to: point(x, y)) }
                if closed { mark.closeSubpath() }
            }
            func ring(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) {
                let corner = point(x - radius, y - radius)
                mark.addEllipse(in: CGRect(origin: corner, size: CGSize(width: radius * side / 16, height: radius * side / 16)))
            }
            func wave(_ y: CGFloat, amplitude: CGFloat, cycles: CGFloat) {
                line((0...24).map { step in
                    let x = CGFloat(step) / 24
                    return (3 + x * 18, y + sin(x * .pi * 2 * cycles) * amplitude)
                })
            }

            switch surface {
            case GlassFluted:
                for x: CGFloat in [5, 10, 15, 20] {
                    mark.move(to: point(x, 3))
                    mark.addQuadCurve(to: point(x, 21), control: point(x - 3, 12))
                }
            case GlassBlinds:
                for y: CGFloat in [5, 12, 19] { line([(3, y), (21, y)]) }
            case GlassLiquid:
                for y: CGFloat in [5, 12, 19] { wave(y, amplitude: 2.2, cycles: 1) }
            case GlassPebbled:
                ring(7, 7, 3.4)
                ring(17, 8, 4)
                ring(9, 17, 4.2)
                ring(18.5, 18, 2.7)
            case GlassDiamond:
                line([(12, 2), (22, 12), (12, 22), (2, 12)], closed: true)
                line([(2, 12), (22, 12)])
                line([(12, 2), (12, 22)])
            case GlassShear:
                line([(3, 13), (12, 4)])
                line([(4, 20), (20, 4)])
                line([(12, 20), (21, 11)])
            case GlassFrosted:
                for (x, y) in [(5.0, 6.0), (13, 4), (19, 8), (9, 12), (5, 19), (15, 16), (20, 20)] {
                    ring(x, y, 0.55)
                }
            case GlassConcentric:
                ring(12, 12, 3)
                ring(12, 12, 6.5)
                ring(12, 12, 10)
            case GlassWoven:
                line([(6, 3), (6, 7), (18, 7), (18, 21)])
                line([(12, 3), (12, 14), (6, 14), (6, 21)])
                line([(3, 11), (8, 11)])
                line([(15, 11), (21, 11)])
                line([(3, 18), (15, 18)])
            case GlassShattered:
                line([(3, 3), (11, 8), (8, 13), (16, 16), (21, 21)])
                line([(11, 8), (20, 3)])
                line([(8, 13), (3, 18)])
                line([(16, 16), (21, 10)])
                line([(16, 16), (13, 21)])
            case GlassHoneycomb:
                line([(8, 3), (15, 3), (19, 9), (15, 15), (8, 15), (4, 9)], closed: true)
                line([(19, 9), (22, 9)])
                line([(15, 15), (19, 21)])
                line([(8, 15), (4, 21)])
            case GlassRaindrop:
                mark.move(to: point(10, 3))
                mark.addQuadCurve(to: point(15, 11), control: point(15, 8))
                mark.addQuadCurve(to: point(5, 11), control: point(10, 19))
                mark.addQuadCurve(to: point(10, 3), control: point(5, 8))
                mark.closeSubpath()
                ring(17, 18, 2.6)
            case GlassChevron:
                for y: CGFloat in [3, 9, 15] { line([(3, y + 4), (12, y), (21, y + 4)]) }
            case GlassPrism:
                line([(4, 19), (12, 4), (20, 19)], closed: true)
                line([(3, 10), (9, 12)])
                line([(16, 12), (22, 9)])
                line([(17, 15), (22, 15)])
            case GlassChecker:
                line([(4, 4), (20, 4), (20, 20), (4, 20)], closed: true)
                line([(12, 4), (12, 20)])
                line([(4, 12), (20, 12)])
                line([(5, 10), (10, 5)])
                line([(14, 19), (19, 14)])
            case GlassSpiral:
                line((0...72).map { step in
                    let t = CGFloat(step) / 72
                    let angle = t * .pi * 3.6
                    return (12 + cos(angle) * t * 10, 12 + sin(angle) * t * 10)
                })
            case GlassCrimped:
                for y: CGFloat in [6, 12, 18] { wave(y, amplitude: 2.8, cycles: 1.75) }
            case GlassFan:
                line([(12, 21), (3, 9), (8, 5), (16, 5), (21, 9)], closed: true)
                line([(8, 5), (12, 21), (16, 5)])
            default:
                ring(12, 12, 8)
            }

            context.stroke(mark, with: .color(selected ? .primary : .secondary),
                           style: StrokeStyle(lineWidth: side * 0.05, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 31, height: 31)
        .accessibilityHidden(true)
    }
}
