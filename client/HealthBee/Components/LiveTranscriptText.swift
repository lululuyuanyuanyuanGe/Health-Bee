// LiveTranscriptText.swift
// Health Bee — Components
// Streaming text for live speech transcript

import SwiftUI

struct LiveTranscriptText: View {
    let text: String
    let font: Font
    let color: Color

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .animation(.easeIn(duration: 0.15), value: text)
    }
}
