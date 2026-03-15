// OrbView.swift
// Health Bee — Home View
// Animated canvas orb using TimelineView

import SwiftUI
import UIKit

struct OrbView: View {
    @Environment(\.theme) var theme
    let mode: SessionMode
    let onTap: () -> Void

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let speed: Double = mode == .duo ? 1.2 : 1.5
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Core glow
                let coreRadius: CGFloat = 55
                let pulse = 5 * sin(t * speed * .pi)
                let coreGlow = Path(ellipseIn: CGRect(
                    x: center.x - coreRadius - pulse,
                    y: center.y - coreRadius - pulse,
                    width: (coreRadius + pulse) * 2,
                    height: (coreRadius + pulse) * 2
                ))
                ctx.fill(coreGlow, with: .color(theme.accent.opacity(0.15)))

                // Blobs
                let blobCount = mode == .duo ? 3 : 2
                let blobRadius: CGFloat = 35
                let orbitRadius: CGFloat = 15

                for i in 0..<blobCount {
                    let angle = t * speed + Double(i) * (2 * .pi / Double(blobCount))
                    let blobCenter = CGPoint(
                        x: center.x + orbitRadius * cos(angle),
                        y: center.y + orbitRadius * sin(angle)
                    )
                    let blobPath = Path(ellipseIn: CGRect(
                        x: blobCenter.x - blobRadius,
                        y: blobCenter.y - blobRadius,
                        width: blobRadius * 2,
                        height: blobRadius * 2
                    ))
                    ctx.fill(blobPath, with: .color(theme.accent.opacity(0.20)))
                }
            }
            .blur(radius: 25)
        }
        .frame(width: 180, height: 180)
        .contentShape(Circle())
        .onTapGesture {
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()
            onTap()
        }
    }
}
