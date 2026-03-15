// SessionsListView.swift
// Health Bee — Tab 0 (Conversation History)

import SwiftUI

struct SessionsListView: View {
    @Environment(\.theme) var theme: AppTheme
    @EnvironmentObject var appState: AppState

    @State private var isEditing: Bool = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showDeleteConfirmation: Bool = false
    @State private var selectedSession: ChatSession? = nil
    @State private var showChatHistory: Bool = false
    @State private var chatHistoryOffset: CGFloat = UIScreen.main.bounds.width

    private var grouped: [(SessionDateGroup, [ChatSession])] {
        let groups: [SessionDateGroup] = [.today, .yesterday, .previous7Days, .older]
        return groups.compactMap { group in
            let sessions = appState.sessions.filter { $0.date.sessionGroup == group }
            return sessions.isEmpty ? nil : (group, sessions)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                List {
                    ForEach(grouped, id: \.0) { group, sessions in
                        Section {
                            ForEach(sessions) { session in
                                ZStack {
                                    if isEditing {
                                        editingRow(for: session)
                                    } else {
                                        SessionRow(
                                            session: session,
                                            onTap: {
                                                selectedSession = session
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    showChatHistory = true
                                                    chatHistoryOffset = 0
                                                }
                                            },
                                            onDelete: {
                                                appState.sessions.removeAll { $0.id == session.id }
                                            }
                                        )
                                    }
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(theme.background)
                                .listRowSeparator(.hidden)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(theme.borderSubtle)
                                        .frame(height: 0.5)
                                        .padding(.leading, 20)
                                }
                            }
                        } header: {
                            Text(group.rawValue)
                                .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                                .foregroundColor(theme.textSecondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                .padding(.bottom, 8)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(theme.background)
                .navigationTitle("Conversations")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditing.toggle()
                                if !isEditing { selectedIDs.removeAll() }
                            }
                        }
                        .font(.system(size: 13, weight: theme.labelWeight, design: theme.fontDesign))
                        .foregroundColor(theme.accent)
                    }
                }
                .toolbarBackground(theme.background, for: .navigationBar)
                .toolbarColorScheme(theme.colorScheme, for: .navigationBar)

                // Edit mode bottom bar
                if isEditing {
                    VStack {
                        Spacer()
                        editBottomBar
                    }
                }

                // Chat History overlay
                if showChatHistory, let session = selectedSession {
                    chatHistoryOverlay(session: session)
                }
            }
        }
        .confirmationDialog(
            "Delete \(selectedIDs.count) conversation\(selectedIDs.count == 1 ? "" : "s")?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                appState.sessions.removeAll { selectedIDs.contains($0.id) }
                selectedIDs.removeAll()
                isEditing = false
            }
        }
    }

    // MARK: - Edit Row

    @ViewBuilder
    private func editingRow(for session: ChatSession) -> some View {
        let isSelected = selectedIDs.contains(session.id)
        HStack {
            Button {
                if isSelected {
                    selectedIDs.remove(session.id)
                } else {
                    selectedIDs.insert(session.id)
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? theme.accent : theme.textSecondary)
                    .padding(.leading, 20)
            }
            .buttonStyle(.plain)

            SessionRow(
                session: session,
                onTap: {
                    if isSelected { selectedIDs.remove(session.id) }
                    else { selectedIDs.insert(session.id) }
                },
                onDelete: {}
            )
        }
    }

    // MARK: - Edit Bottom Bar

    private var editBottomBar: some View {
        HStack {
            Button("Select all") {
                selectedIDs = Set(appState.sessions.map { $0.id })
            }
            .font(.system(size: 15, weight: theme.bodyWeight, design: theme.fontDesign))
            .foregroundColor(theme.accent)

            Spacer()

            Button {
                if !selectedIDs.isEmpty { showDeleteConfirmation = true }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Delete (\(selectedIDs.count))")
                }
                .font(.system(size: 15, weight: theme.bodyWeight, design: theme.fontDesign))
                .foregroundColor(selectedIDs.isEmpty ? theme.textTertiary : theme.destructive)
            }
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)
        }
    }

    // MARK: - Chat History Overlay

    @ViewBuilder
    private func chatHistoryOverlay(session: ChatSession) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismissChatHistory() }

            HStack(spacing: 0) {
                Spacer()
                ChatHistoryView(session: session) {
                    dismissChatHistory()
                }
                .frame(width: screenWidth)
                .offset(x: chatHistoryOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                chatHistoryOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let threshold = screenWidth * 0.3
                            let predicted = value.predictedEndTranslation.width
                            if value.translation.width > threshold || predicted > screenWidth * 0.5 {
                                dismissChatHistory()
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    chatHistoryOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .transition(.opacity)
    }

    private func dismissChatHistory() {
        withAnimation(.easeOut(duration: 0.25)) {
            chatHistoryOffset = UIScreen.main.bounds.width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showChatHistory = false
            selectedSession = nil
            chatHistoryOffset = UIScreen.main.bounds.width
        }
    }
}
