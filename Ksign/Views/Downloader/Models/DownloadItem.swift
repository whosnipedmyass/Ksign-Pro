//
//  DownloadItem.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI

// Model for download items
struct DownloadItem: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let localPath: URL
    var isFinished: Bool
    var progress: Double
    var totalBytes: Int64
    var bytesDownloaded: Int64
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        
        if isFinished || totalBytes > 0 {
            return formatter.string(fromByteCount: totalBytes)
        } else {
            return "Unknown size"
        }
    }
    
    var progressText: String {
        if isFinished {
            return "Completed"
        } else if progress > 0 {
            let downloadedStr = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
            let totalStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(downloadedStr) of \(totalStr) (\(Int(progress * 100))%)"
        } else {
            return "Starting download..."
        }
    }
} 