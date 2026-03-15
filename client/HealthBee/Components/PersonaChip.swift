// PersonaChip.swift
// Health Bee — Components

import SwiftUI

struct PersonaChip: View {
    @Environment(\.theme) var theme
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.system(size: 11, weight: theme.labelWeight, design: theme.fontDesign))
                .foregroundColor(isSelected ? theme.textOnAccent : theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? theme.accent : theme.surfaceSecondary)
                .cornerRadius(theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(isSelected ? theme.accent : theme.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onEdit {
                Button { onEdit() } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
