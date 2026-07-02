import SwiftUI

/// SwiftUI-side wrappers for the two Metal shaders. Both degrade to plain
/// fills when accessibility settings ask for less motion/transparency —
/// the shaders are polish, never structure.

/// Subtle animated paper grain for the Today briefing card.
struct CalmGrain: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceMotion || reduceTransparency {
            content
        } else {
            TimelineView(.animation(minimumInterval: 0.4)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                content.colorEffect(
                    ShaderLibrary.calmGrain(.float(Float(time)), .float(0.03))
                )
            }
        }
    }
}

/// Soft radial wash behind an Eisenhower quadrant.
struct QuadrantWash: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let tint: Color

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
        } else {
            content.visualEffect { view, proxy in
                view.colorEffect(
                    ShaderLibrary.quadrantWash(
                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                        .color(tint.opacity(0.10))
                    )
                )
            }
        }
    }
}

extension View {
    func calmGrain() -> some View {
        modifier(CalmGrain())
    }

    func quadrantWash(_ tint: Color) -> some View {
        modifier(QuadrantWash(tint: tint))
    }
}
