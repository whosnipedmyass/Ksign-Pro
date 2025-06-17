//
//  ShareComponents.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import UniformTypeIdentifiers

// ShareSheet for file sharing
struct DownloaderShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Document Picker for exporting to Files app
struct DocumentPickerView: UIViewControllerRepresentable {
    let fileURL: URL
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let _ = fileURL.startAccessingSecurityScopedResource()
        
        let picker = UIDocumentPickerViewController(forExporting: [fileURL])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let fileURL: URL
        
        init(fileURL: URL) {
            self.fileURL = fileURL
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            fileURL.stopAccessingSecurityScopedResource()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            fileURL.stopAccessingSecurityScopedResource()
        }
    }
} 
