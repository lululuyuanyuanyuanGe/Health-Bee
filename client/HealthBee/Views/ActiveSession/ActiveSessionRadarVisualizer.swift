// ActiveSessionRadarVisualizer.swift
// Health Bee — Active Session
// Decorative background radar visualization

import SwiftUI

struct ActiveSessionRadarVisualizer: View {
    @Environment(\.theme) var theme: AppTheme
    let sessionState: SessionState

    @State private var phase: Double = 0

    var animationSpeed: Double {
        switch sessionState {
        case .recording: return 1.0
        case .processing: return 2.0
        case .speaking: return 1.5
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxR: CGFloat = min(size.width, size.height) / 2

                for i in 0..<4 {
                    let rFraction = (Double(i) / 4.0 + t * 0.15 * animationSpeed).truncatingRemainder(dividingBy: 1.0)
                    let r = maxR * CGFloat(rFraction)
                    let opacity = (1.0 - rFraction) * 0.12

                    let ring = Path(ellipseIn: CGRect(
                        x: center.x - r,
                        y: center.y - r,
                        width: r * 2,
                        height: r * 2
                    ))
                    ctx.stroke(ring, with: .color(theme.accent.opacity(opacity)), lineWidth: 1)
                }
            }
        }
        .frame(width: 280, height: 280)
    }
}
