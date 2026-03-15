// ModeSegmentedControl.swift
// Health Bee — Components
// Custom capsule-based Duo/Solo segmented control

import SwiftUI
import UIKit

struct ModeSegmentedControl: View {
    @Environment(\.theme) var theme: AppTheme
    @Binding var selected: SessionMode

    private let options: [SessionMode] = [.duo, .solo]
    private let width: CGFloat = 200
    private let height: CGFloat = 32

    var body: some View {
        ZStack(alignment: .leading) {
            // Track
            Capsule()
                .fill(theme.surfaceSecondary)
                .overlay(
                    Capsule().stroke(theme.border, lineWidth: 0.5)
                )
                .frame(width: width, height: height)

            // Sliding pill
            let pillWidth = width / CGFloat(options.count)
            let pillIndex = options.firstIndex(of: selected) ?? 0

            Capsule()
                .fill(theme.accent)
                .frame(width: pillWidth, height: height - 2)
                .offset(x: CGFloat(pillIndex) * pillWidth + 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selected)

            // Labels
            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        if selected != option {
                            let gen = UISelectionFeedbackGenerator()
                            gen.selectionChanged()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selected = option
                            }
                        }
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 10, weight: theme.headingWeight, design: theme.fontDesign))
                            .foregroundColor(selected == option ? theme.textOnAccent : theme.textSecondary)
                            .frame(width: pillWidth, height: height)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: width, height: height)
    }
}
