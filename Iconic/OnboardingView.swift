//
// SPDX-License-Identifier: MIT
//  OnboardingView.swift
//  Iconic
//
//  First-launch onboarding sheet for Gemini API key setup.
//

import SwiftUI

/// First-launch onboarding sheet. Walks the user through a 4- or 5-page flow:
/// 1. Welcome (with a before/after folder preview)
/// 2. Icon style (SF Symbols vs emoji)
/// 3. Matching mode (Local vs AI)
/// 4. Either the Gemini API key entry page (if AI is selected) or the
///    "you're ready" tips page
/// 5. Tips page (only reached when AI is selected — page 4 then becomes the
///    API key page and the tips move to page 5)
///
/// The AI-specific page is conditionally inserted, so total page count is 4
/// for local-only and 5 for AI. On finish, the chosen style is written to
/// `IconStyleStore` and the API key (if any) is saved via `SettingsViewModel`.
struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsVM = SettingsViewModel()
    @State private var selectedMode: MatchingMode = .local
    @State private var selectedStyle: IconStyle = IconStyleStore.current
    @State private var pageIndex = 0

    enum MatchingMode {
        case ai, local
    }

    private var pageCount: Int {
        selectedMode == .ai ? 5 : 4
    }

    var body: some View {
        VStack(spacing: 0) {
            pageHeader

            ZStack {
                pageContent
                    .id(pageIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .padding(28)
        .frame(width: 560, height: 540)
        .animation(.easeInOut(duration: 0.22), value: pageIndex)
        .animation(.easeInOut(duration: 0.18), value: selectedMode)
    }

    private var pageHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == pageIndex ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: index == pageIndex ? 28 : 8, height: 8)
            }
            Spacer()
            Text("\(pageIndex + 1) of \(pageCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch pageIndex {
        case 0:
            welcomePage
        case 1:
            stylePage
        case 2:
            matchingPage
        case 3:
            if selectedMode == .ai {
                aiPage
            } else {
                tipsPage
            }
        default:
            tipsPage
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 22) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Welcome to Iconic")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Automatically assign beautiful icons to your folders and keep everything reversible.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 380)
            }

            HStack(spacing: 24) {
                folderPreview(label: "Before", overlay: nil, isEmoji: false, tint: .secondary)
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                folderPreview(label: "After", overlay: "music.note", isEmoji: false, tint: .blue)
            }

            Text("Pick a style, choose matching mode, then select a folder or drag one into the main window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stylePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose an Icon Style")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("You can switch this later from the main window or Settings.")
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
                    description: "Full-color emoji rendered directly onto each folder.",
                    previewSymbol: "🎵",
                    useEmojiPreview: true
                )
            }

            infoPanel(
                icon: "paintpalette",
                title: selectedStyle == .emoji ? "Emoji keep their built-in colors" : "Symbols use your chosen colors",
                message: selectedStyle == .emoji
                    ? "Color pickers still tint folders, but the emoji artwork itself stays full color."
                    : "Auto-color can tint folders and choose a matching symbol shade automatically.",
                tint: selectedStyle == .emoji ? .orange : .blue
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var matchingPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose Matching")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Local matching is the easiest start. AI can be enabled now or later.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                modeOption(
                    mode: .local,
                    icon: "book.closed",
                    title: "Local Matching",
                    description: "Built-in keyword mappings. Fast, private, and works offline.",
                    color: .blue
                )

                modeOption(
                    mode: .ai,
                    icon: "sparkles",
                    title: "AI Matching (Gemini)",
                    description: "Smarter semantic matching using Google's Gemini API. Requires an API key.",
                    color: .purple
                )
            }

            infoPanel(
                icon: "slider.horizontal.3",
                title: "You stay in control",
                message: "Dry Run previews every match before anything is applied in Finder.",
                tint: .green
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var aiPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connect Gemini")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Paste an API key now, or continue without AI and add it later in Settings.")
                    .foregroundStyle(.secondary)
            }

            aiKeySection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var tipsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("You're Ready")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("A couple of useful details before you start.")
                    .foregroundStyle(.secondary)
            }

            infoPanel(
                icon: "hand.draw",
                title: "Drag & Drop",
                message: "Drop folders directly onto the app window to scan them instantly.",
                tint: .blue
            )

            infoPanel(
                icon: "eye",
                title: "Preview Before Applying",
                message: "Dry Run lets you review every match before Iconic changes anything on disk.",
                tint: .green
            )

            infoPanel(
                icon: "lock.shield",
                title: "Protected Folders",
                message: "macOS can block changes to system folders such as /System and /Library.",
                tint: .orange
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Skip") {
                finish(saveAI: false)
            }

            Spacer()

            Button("Back") {
                pageIndex = max(0, pageIndex - 1)
            }
            .disabled(pageIndex == 0)

            Button(isLastPage ? primaryFinishTitle : "Next") {
                if isLastPage {
                    finish(saveAI: true)
                } else {
                    pageIndex = min(pageCount - 1, pageIndex + 1)
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 18)
    }

    private var isLastPage: Bool {
        pageIndex == pageCount - 1
    }

    private var primaryFinishTitle: String {
        selectedMode == .ai && settingsVM.apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Continue without AI"
            : "Get Started"
    }

    private func finish(saveAI: Bool) {
        if saveAI,
           selectedMode == .ai,
           !settingsVM.apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty {
            settingsVM.saveAPIKey()
            settingsVM.toggleAI(true)
        } else {
            settingsVM.toggleAI(false)
        }
        IconStyleStore.current = selectedStyle
        dismiss()
    }

    private func folderPreview(label: String, overlay: String?, isEmoji: Bool, tint: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                if let overlay {
                    if isEmoji {
                        Text(overlay)
                            .font(.system(size: 24))
                            .offset(y: 3)
                    } else {
                        Image(systemName: overlay)
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .offset(y: 5)
                            .accessibilityHidden(true)
                    }
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(tint)
        }
    }

    private func infoPanel(icon: String, title: String, message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(tint.opacity(0.08))
        .cornerRadius(8)
    }

    private func modeOption(mode: MatchingMode, icon: String, title: String, description: String, color: Color) -> some View {
        Button {
            selectedMode = mode
            if pageIndex >= pageCount {
                pageIndex = pageCount - 1
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40)
                    .accessibilityHidden(true)

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
                        .accessibilityHidden(true)
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
            VStack(spacing: 10) {
                ZStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    if useEmojiPreview {
                        Text(previewSymbol)
                            .font(.system(size: 25))
                            .offset(y: 3)
                    } else {
                        Image(systemName: previewSymbol)
                            .font(.system(size: 19))
                            .foregroundStyle(.white)
                            .offset(y: 5)
                            .accessibilityHidden(true)
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
            .frame(maxWidth: .infinity, minHeight: 170)
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

            Link("Get a free API key from Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
                .font(.caption)

            infoPanel(
                icon: "key",
                title: "Stored in Keychain",
                message: "Your API key is saved securely and never logged.",
                tint: .purple
            )
        }
        .padding(16)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    OnboardingView()
}
