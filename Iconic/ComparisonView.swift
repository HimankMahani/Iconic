//
// SPDX-License-Identifier: MIT
//  ComparisonView.swift
//  Iconic
//
//  Before/after comparison view for folder icons.
//

import SwiftUI
import AppKit

struct ComparisonView: View {
    let item: FolderItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(item.displayName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 480)

            HStack(spacing: 40) {
                VStack(spacing: 12) {
                    Text("Original")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let original = item.originalIcon {
                        Image(nsImage: original)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary)
                                .frame(width: 200, height: 200)
                            Image(systemName: "folder")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Text("New")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let preview = item.preview {
                        Image(nsImage: preview)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary)
                                .frame(width: 200, height: 200)
                            if item.symbolName.isEmojiGlyph {
                                Text(item.symbolName)
                                    .font(.system(size: 80))
                            } else {
                                Image(systemName: item.symbolName)
                                    .font(.system(size: 80))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(32)
        .frame(width: 600, height: 380)
    }
}
