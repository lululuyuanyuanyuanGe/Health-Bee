// PhoneAuthView.swift
// Health Bee — Phone Authentication (Login)

import SwiftUI
import UIKit

enum AuthStep {
    case phone
    case verification
    case displayName
    case restoring
}

struct PhoneAuthView: View {
    @Environment(\.theme) var theme

    @State private var step: AuthStep = .phone
    @State private var phoneNumber: String = ""
    @State private var countryCode: String = "+1"
    @State private var verificationCode: String = ""
    @State private var displayName: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Branding
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(theme.accent)

                    Text("Health Bee")
                        .font(.system(size: 34, weight: .bold, design: theme.fontDesign))
                        .foregroundColor(theme.textPrimary)
                }

                Spacer().frame(height: Spacing.lg)

                // Step content
                switch step {
                case .phone:
                    phoneStep
                case .verification:
                    verificationStep
                case .displayName:
                    displayNameStep
                case .restoring:
                    restoringStep
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Phone Step

    private var phoneStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Enter your phone number")
                .font(.system(size: 17, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)

            HStack(spacing: Spacing.sm) {
                // Country code
                Menu {
                    Button("+1 (US)") { countryCode = "+1" }
                    Button("+44 (UK)") { countryCode = "+44" }
                    Button("+33 (FR)") { countryCode = "+33" }
                    Button("+49 (DE)") { countryCode = "+49" }
                } label: {
                    HStack(spacing: 4) {
                        Text(countryCode)
                            .font(.system(size: 16, weight: .regular, design: theme.fontDesign).monospacedDigit())
                            .foregroundColor(theme.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(theme.surface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(theme.border, lineWidth: 0.5)
                    )
                }

                TextField("Phone number", text: $phoneNumber)
                    .font(.system(size: 16, weight: .regular, design: theme.fontDesign).monospacedDigit())
                    .foregroundColor(theme.textPrimary)
                    .keyboardType(.phonePad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(theme.surface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(theme.border, lineWidth: 0.5)
                    )
            }

            primaryButton(
                title: "Send Code",
                enabled: phoneNumber.count >= 7,
                isLoading: isLoading
            ) {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLoading = false
                    step = .verification
                }
            }

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12, weight: .regular, design: theme.fontDesign))
                    .foregroundColor(theme.destructive)
            }
        }
    }

    // MARK: - Verification Step

    private var verificationStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Enter verification code")
                .font(.system(size: 17, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)

            Text("Sent to \(countryCode) \(phoneNumber)")
                .font(.system(size: 14, weight: .regular, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            TextField("000000", text: $verificationCode)
                .font(.system(size: 28, weight: .regular, design: theme.fontDesign).monospacedDigit())
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(theme.surface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.border, lineWidth: 0.5)
                )

            primaryButton(
                title: "Verify",
                enabled: verificationCode.count == 6,
                isLoading: isLoading
            ) {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLoading = false
                    step = .displayName
                }
            }

            Button {
                step = .phone
            } label: {
                Text("← Change number")
                    .font(.system(size: 15, weight: .regular, design: theme.fontDesign))
                    .foregroundColor(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Display Name Step

    private var displayNameStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("What should we call you?")
                .font(.system(size: 17, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)

            TextField("Your name", text: $displayName)
                .font(.system(size: 16, weight: .regular, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(theme.surface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.border, lineWidth: 0.5)
                )

            primaryButton(
                title: "Get Started",
                enabled: displayName.count >= 1,
                isLoading: isLoading
            ) {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // sign in complete
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Restoring Step

    private var restoringStep: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .tint(theme.accent)
                .scaleEffect(1.5)

            Text("Signing you in...")
                .font(.system(size: 16, weight: .regular, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)
        }
    }

    // MARK: - Primary Button

    @ViewBuilder
    private func primaryButton(title: String, enabled: Bool, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(theme.textOnAccent)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: theme.fontDesign))
                        .foregroundColor(theme.textOnAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(enabled ? theme.accent : theme.textTertiary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || isLoading)
    }
}
