// AppModels.swift
// Health Bee — Data Models

import Foundation

// MARK: - Session Mode

enum SessionMode: String, CaseIterable {
    case duo = "Duo"
    case solo = "Solo"
}

// MARK: - Session State

enum SessionState {
    case recording
    case processing
    case speaking
}

// MARK: - Chat Session

struct ChatSession: Identifiable {
    let id: UUID
    var title: String
    var preview: String
    var date: Date
    var messages: [ChatMessage]

    init(id: UUID = UUID(), title: String, preview: String = "", date: Date = Date(), messages: [ChatMessage] = []) {
        self.id = id
        self.title = title
        self.preview = preview
        self.date = date
        self.messages = messages
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole {
    case user
    case assistant
}

// MARK: - Persona (Prompt)

struct Persona: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var systemPrompt: String

    init(id: UUID = UUID(), name: String, description: String = "", systemPrompt: String = "") {
        self.id = id
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
    }
}

// MARK: - Dashboard Card

enum DashboardCardType {
    case reminder
    case social
    case insight
    case discover
    case tip
}

struct DashboardCard: Identifiable {
    let id: UUID
    var type: DashboardCardType
    var content: String

    init(id: UUID = UUID(), type: DashboardCardType, content: String) {
        self.id = id
        self.type = type
        self.content = content
    }
}

// MARK: - Insight

enum InsightType {
    case todo
    case routine
    case note
    case reminder
}

struct Insight: Identifiable {
    let id: UUID
    var type: InsightType
    var content: String
    var isCompleted: Bool

    init(id: UUID = UUID(), type: InsightType, content: String, isCompleted: Bool = false) {
        self.id = id
        self.type = type
        self.content = content
        self.isCompleted = isCompleted
    }
}

// MARK: - Enrollment Status

enum EnrollmentStatus {
    case notEnrolled
    case recording
    case enrolled
}

// MARK: - Date Grouping

enum SessionDateGroup: String {
    case today = "Today"
    case yesterday = "Yesterday"
    case previous7Days = "Previous 7 days"
    case older = "Older"
}

extension Date {
    var sessionGroup: SessionDateGroup {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return .today }
        if calendar.isDateInYesterday(self) { return .yesterday }
        if let diff = calendar.dateComponents([.day], from: self, to: Date()).day, diff <= 7 { return .previous7Days }
        return .older
    }

    func relativeShortString() -> String {
        let diff = Date().timeIntervalSince(self)
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        return "\(Int(diff / 86400))d"
    }
}
