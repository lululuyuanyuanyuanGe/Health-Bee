// PromptsListView.swift
// Health Bee — Persona Management Sheet

import SwiftUI
import UIKit

struct PromptsListView: View {
    @Environment(\.theme) var theme: AppTheme
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var showEditSheet: Bool = false
    @State private var editingPersona: Persona? = nil
    @State private var showNewPersona: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(theme.labels.selectPersona)
                        .font(.system(size: 24, weight: theme.headingWeight, design: theme.fontDesign))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

                // Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(appState.personas) { persona in
                            PromptCard(
                                persona: persona,
                                isSelected: appState.selectedPersonaID == persona.id,
                                onTap: {
                                    let gen = UIImpactFeedbackGenerator(style: .heavy)
                                    gen.impactOccurred()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        appState.selectedPersonaID = persona.id
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        dismiss()
                                    }
                                },
                                onEdit: {
                                    editingPersona = persona
                                    showEditSheet = true
                                },
                                onDelete: {
                                    appState.personas.removeAll { $0.id == persona.id }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xxl)
                }

                // Bottom action bar
                HStack(spacing: Spacing.md) {
                    Button {
                        if let id = appState.selectedPersonaID,
                           let persona = appState.personas.first(where: { $0.id == id }) {
                            editingPersona = persona
                            showEditSheet = true
                        }
                    } label: {
                        Text("Edit current")
                            .font(.system(size: 14, weight: theme.bodyWeight, design: theme.fontDesign))
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                Rectangle()
                                    .stroke(theme.textSecondary, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showNewPersona = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("New assistant")
                            Image(systemName: "plus")
                        }
                        .font(.system(size: 14, weight: theme.bodyWeight, design: theme.fontDesign))
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            Rectangle()
                                .stroke(theme.accent, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(theme.background)
                .overlay(alignment: .top) {
                    Rectangle().fill(theme.border).frame(height: 0.5)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let persona = editingPersona {
                EditPersonaView(persona: persona) { updated in
                    if let idx = appState.personas.firstIndex(where: { $0.id == persona.id }) {
                        appState.personas[idx] = updated
                    }
                }
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showNewPersona) {
            EditPersonaView(persona: Persona(name: "", description: "", systemPrompt: "")) { newPersona in
                appState.personas.append(newPersona)
                appState.selectedPersonaID = newPersona.id
            }
            .environmentObject(appState)
        }
    }
}

// MARK: - PromptCard

struct PromptCard: View {
    @Environment(\.theme) var theme: AppTheme
    let persona: Persona
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(theme.surfaceSecondary)
                        .frame(width: 40, height: 40)
                    Image(systemName: "face.dashed")
                        .font(.system(size: 20))
                        .foregroundColor(theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(persona.name)
                        .font(.system(size: 14, weight: .black, design: theme.fontDesign))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    Text(persona.description.isEmpty ? "No description" : persona.description)
                        .font(.system(size: 11, weight: .regular, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Text(theme.labels.activeBadge)
                        .font(.system(size: 10, weight: theme.labelWeight, design: theme.fontDesign))
                        .foregroundColor(theme.textOnAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accent)
                        .cornerRadius(theme.cornerRadius)
                }
            }
            .padding(Spacing.md)
            .frame(minHeight: 200, alignment: .topLeading)
            .background(theme.surface)
            .cornerRadius(theme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(isSelected ? theme.accent : theme.border, lineWidth: isSelected ? 2 : 0.5)
            )
            .shadow(
                color: isSelected ? theme.accent.opacity(0.3) : .clear,
                radius: isSelected ? 20 : 0,
                x: 0, y: 0
            )
            .opacity(isSelected ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Edit Persona View

struct EditPersonaView: View {
    @Environment(\.theme) var theme: AppTheme
    @Environment(\.dismiss) var dismiss

    @State private var persona: Persona
    let onSave: (Persona) -> Void

    init(persona: Persona, onSave: @escaping (Persona) -> Void) {
        _persona = State(initialValue: persona)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }

                Form {
                    Section("Name") {
                        TextField("Assistant name", text: $persona.name)
                            .foregroundColor(theme.textPrimary)
                    }
                    .listRowBackground(theme.surface)

                    Section("Description") {
                        TextField("Short description", text: $persona.description, axis: .vertical)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(3...5)
                    }
                    .listRowBackground(theme.surface)

                    Section("System Prompt") {
                        TextField("You are a helpful assistant...", text: $persona.systemPrompt, axis: .vertical)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(5...10)
                    }
                    .listRowBackground(theme.surface)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(persona.name.isEmpty ? "New Assistant" : persona.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(theme.accent)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(persona)
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(persona.name.isEmpty ? theme.textTertiary : theme.accent)
                        .disabled(persona.name.isEmpty)
                    }
                }
                .toolbarBackground(theme.background, for: .navigationBar)
            }
        }
    }
}
