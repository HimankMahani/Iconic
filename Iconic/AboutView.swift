//
//  AboutView.swift
//  Iconic
//
// SPDX-License-Identifier: MIT
//
//  Modal "About Iconic" sheet, reachable from the header's `…` overflow
//  menu and the macOS standard "About Iconic" app menu. Shows the
//  current version, build, commit SHA, and links to the GitHub repo
//  and changelog.
//

import SwiftUI

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            // Hero
            VStack(spacing: 8) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text("Iconic")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Beautiful icons for your folders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Divider()

            // Version info
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Version") {
                    Text(AppVersion.displayString)
                        .font(.system(.body, design: .monospaced))
                }
                if AppVersion.isDebug {
                    LabeledContent("Build") {
                        Text("Development build")
                            .foregroundStyle(.orange)
                    }
                }
                LabeledContent("macOS") {
                    Text("14.0+ (Sonoma)")
                }
                LabeledContent("License") {
                    Text("MIT")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            // Links
            HStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/HimankMahani/Iconic")!) {
                    Label("GitHub", systemImage: "link")
                }
                Link(destination: URL(string: "https://github.com/HimankMahani/Iconic/blob/main/CHANGELOG.md")!) {
                    Label("Changelog", systemImage: "list.bullet.rectangle")
                }
                Link(destination: URL(string: "https://github.com/HimankMahani/Iconic/blob/main/LICENSE")!) {
                    Label("License", systemImage: "doc.text")
                }
            }
            .controlSize(.small)

            // Done
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 360)
    }
}

#Preview {
    AboutView()
}
