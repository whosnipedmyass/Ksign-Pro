//
//  DownloadItemRow.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI

// Download Item Row
struct DownloadItemRow: View {
    let item: DownloadItem
    @State private var isHovering = false
    var onTap: (DownloadItem) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on file state
            Image(systemName: item.isFinished ? "doc.zipper" : "arrow.down.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)
                
                Text(item.isFinished ? item.formattedFileSize : item.progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !item.isFinished {
                    ProgressView(value: item.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .accentColor(.accentColor)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.gray.opacity(0.1) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if item.isFinished {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onTap(item)
            }
        }
    }
} 