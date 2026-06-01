//
//  OnboardingView.swift
//  Iconic
//
//  First-launch onboarding sheet for Gemini API key setup.
//

import SwiftUI

struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsVM = SettingsViewModel()
    @State private var selectedMode: MatchingMode = .local
    @State private var selectedStyle: IconStyle = IconStyleStore.current

    enum MatchingMode {
        case ai, local
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Welcome to Iconic")
                .font(.title)
                .fontWeight(.bold)

            Text("Automatically assign beautiful SF Symbol icons to your folders.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Before")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.blue)
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .offset(y: 4)
                        }
                        Text("After")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Text("Iconic gives your folders custom icons based on their names. Icons appear in Finder and are fully reversible.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Icon Style")
                        .font(.headline)
                    Text("Pick how folder icons should look. You can change this later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    styleOption(
                        style: .sfSymbol,
                        title: "SF Symbols",
                        description: "Apple's clean monochrome icons. Adopts your color choices.",
                        previewSymbol: "music.note",
                        useEmojiPreview: false
                    )

                    styleOption(
                        style: .emoji,
                        title: "Emoji",
                        description: "Familiar full-color emoji. Lots of variety, no color picking needed.",
                        previewSymbol: "🎵",
                        useEmojiPreview: true
                    )
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Get Started")
                        .font(.headline)
                    Text("Recommended: Start with Local Matching - works offline, no setup needed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    modeOption(
                        mode: .local,
                        icon: "book.closed",
                        title: "Local Matching",
                        description: "350+ built-in keyword mappings. Fast, private, works offline.",
                        color: .blue
                    )

                    modeOption(
                        mode: .ai,
                        icon: "sparkles",
                        title: "AI Matching (Gemini)",
                        description: "Smarter matching using Google's Gemini AI. Requires free API key.",
                        color: .purple
                    )
                }

                Text("You can enable AI matching anytime in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            if selectedMode == .ai {
                aiKeySection
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Skip for Now") {
                    dismiss()
                }

                Button(selectedMode == .ai && settingsVM.apiKeyInput.isEmpty ? "Continue without AI" : "Get Started") {
                    if selectedMode == .ai && !settingsVM.apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        settingsVM.saveAPIKey()
                        settingsVM.toggleAI(true)
                    } else {
                        settingsVM.toggleAI(false)
                    }
                    IconStyleStore.current = selectedStyle
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 540, height: selectedMode == .ai ? 1020 : 860)
        .animation(.easeInOut(duration: 0.2), value: selectedMode)
    }

    private func modeOption(mode: MatchingMode, icon: String, title: String, description: String, color: Color) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if selectedMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(12)
            .background(selectedMode == mode ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedMode == mode ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: selectedMode == mode ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func styleOption(style: IconStyle,
                             title: String,
                             description: String,
                             previewSymbol: String,
                             useEmojiPreview: Bool) -> some View {
        Button {
            selectedStyle = style
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    if useEmojiPreview {
                        Text(previewSymbol)
                            .font(.system(size: 22))
                            .offset(y: 2)
                    } else {
                        Image(systemName: previewSymbol)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .offset(y: 4)
                    }
                }

                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(selectedStyle == style ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedStyle == style ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: selectedStyle == style ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var aiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gemini API Key")
                .font(.headline)

            Text("Get a free API key from Google AI Studio. You can always add this later in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("Paste your API key here (optional)", text: $settingsVM.apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if !settingsVM.apiKeyInput.isEmpty {
                        settingsVM.saveAPIKey()
                        settingsVM.toggleAI(true)
                    }
                }

            HStack(spacing: 8) {
                Button {
                    settingsVM.testAPIKey()
                } label: {
                    if settingsVM.isTesting {
                        ProgressView().controlSize(.small)
                        Text("Testing...")
                    } else {
                        Text("Test Key")
                    }
                }
                .disabled(settingsVM.apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty || settingsVM.isTesting)

                if let result = settingsVM.testResult {
                    switch result {
                    case .success:
                        Label("Valid", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .failure(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            Link("Get a free API key from Google AI Studio →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                .font(.caption)
        }
        .padding(16)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(10)
    }
}

#Preview {
    OnboardingView()
}
