// TypewriterText.swift
// Health Bee — Components
// Character-by-character text reveal for AI responses

import SwiftUI

struct TypewriterText: View {
    @Environment(\.theme) var theme
    let fullText: String
    let font: Font
    let color: Color

    @State private var visibleCount: Int = 0
    @State private var isIdle: Bool = false
    @State private var idleTimer: Timer? = nil

    private var displayText: String {
        String(fullText.prefix(visibleCount))
    }

    var body: some View {
        Text(displayText)
            .font(font)
            .foregroundColor(color)
            .opacity(isIdle ? 0.86 : 1.0)
            .animation(isIdle ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .none, value: isIdle)
            .onChange(of: fullText) { oldVal, newVal in
                if newVal.hasPrefix(oldVal) {
                    // Append — typewriter mode
                    scheduleTypewriter(from: visibleCount, target: newVal.count)
                } else {
                    // Non-append change — instant reveal
                    visibleCount = newVal.count
                }
                resetIdleTimer()
            }
            .onAppear {
                visibleCount = fullText.count
            }
    }

    private func scheduleTypewriter(from start: Int, target: Int) {
        guard start < target else { return }
        let backlog = target - start

        let (charsPerTick, interval): (Int, TimeInterval) = {
            if backlog > 50 { return (5, 0.004) }
            if backlog > 20 { return (3, 0.008) }
            return (1, 0.020)
        }()

        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            let next = min(visibleCount + charsPerTick, target)
            visibleCount = next
            if next < target {
                scheduleTypewriter(from: next, target: target)
            }
        }
    }

    private func resetIdleTimer() {
        isIdle = false
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            isIdle = true
        }
    }
}
