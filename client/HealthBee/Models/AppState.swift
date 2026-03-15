// AppState.swift
// Health Bee — Global App State

import Foundation
import SwiftUI

final class AppState: ObservableObject {
    // MARK: Navigation
    @Published var showActiveSession: Bool = false
    @Published var selectedTab: Int = 1

    // MARK: Session
    @Published var currentMode: SessionMode = .duo
    @Published var sessionState: SessionState = .recording
    @Published var activeSessionMessages: [ChatMessage] = []
    @Published var liveTranscript: String = ""

    // MARK: Personas
    @Published var personas: [Persona] = Persona.samplePersonas
    @Published var selectedPersonaID: UUID?

    var selectedPersona: Persona? {
        guard let id = selectedPersonaID else { return personas.first }
        return personas.first(where: { $0.id == id })
    }

    // MARK: Sessions History
    @Published var sessions: [ChatSession] = ChatSession.sampleSessions

    // MARK: Dashboard
    @Published var dashboardCards: [DashboardCard] = DashboardCard.sampleCards

    // MARK: Settings
    @Published var enrollmentStatus: EnrollmentStatus = .notEnrolled
    @Published var selectedLanguage: String = "English"

    init() {
        selectedPersonaID = personas.first?.id
    }
}

// MARK: - Sample Data

extension Persona {
    static let samplePersonas: [Persona] = [
        Persona(name: "General", description: "A helpful general-purpose assistant ready to tackle any topic.", systemPrompt: "You are a helpful assistant."),
        Persona(name: "Doctor", description: "A medical professional assistant for health-related questions and guidance.", systemPrompt: "You are a knowledgeable medical assistant."),
        Persona(name: "Coach", description: "A motivational life and wellness coach to help you reach your goals.", systemPrompt: "You are an encouraging wellness coach.")
    ]
}

extension ChatSession {
    static let sampleSessions: [ChatSession] = [
        ChatSession(
            title: "Morning health check",
            preview: "Discussed sleep quality and energy levels...",
            date: Date().addingTimeInterval(-180),
            messages: [
                ChatMessage(role: .user, content: "How can I improve my sleep quality?"),
                ChatMessage(role: .assistant, content: "Great question! Here are some evidence-based tips for better sleep: maintain a consistent sleep schedule, avoid screens an hour before bed, keep your room cool and dark, and limit caffeine after 2pm.")
            ]
        ),
        ChatSession(
            title: "Nutrition advice",
            preview: "Talked about balanced diet and meal planning...",
            date: Date().addingTimeInterval(-3600),
            messages: [
                ChatMessage(role: .user, content: "What should I eat for more energy?"),
                ChatMessage(role: .assistant, content: "Focus on complex carbohydrates, lean proteins, and healthy fats. Foods like oats, eggs, nuts, and leafy greens provide sustained energy throughout the day.")
            ]
        ),
        ChatSession(
            title: "Exercise routine",
            preview: "Created a weekly workout plan...",
            date: Date().addingTimeInterval(-86400),
            messages: [
                ChatMessage(role: .user, content: "Can you help me create a beginner workout plan?"),
                ChatMessage(role: .assistant, content: "Of course! For beginners, I recommend starting with 3 days per week: Monday (upper body), Wednesday (lower body), Friday (full body). Keep sessions to 30-45 minutes.")
            ]
        ),
        ChatSession(
            title: "Stress management",
            preview: "Explored mindfulness and breathing techniques...",
            date: Date().addingTimeInterval(-86400 * 2),
            messages: []
        ),
        ChatSession(
            title: "Hydration goals",
            preview: "Set daily water intake targets...",
            date: Date().addingTimeInterval(-86400 * 5),
            messages: []
        )
    ]
}

extension DashboardCard {
    static let sampleCards: [DashboardCard] = [
        DashboardCard(type: .reminder, content: "Take your daily vitamins — you set this reminder for 9 AM"),
        DashboardCard(type: .insight, content: "You've had 3 health conversations this week, up from last week"),
        DashboardCard(type: .tip, content: "Try a 5-minute breathing exercise before bed for better sleep"),
        DashboardCard(type: .social, content: "Your wellness streak is at 7 days — keep it up!")
    ]
}
