//
//  DownloaderView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers
import NimbleViews
import UIKit

struct DownloaderView: View {
    @StateObject private var downloadManager = IPADownloadManager()
    @StateObject private var libraryManager = DownloadManager.shared
    
    // MARK: - State Properties
    @State private var showWebView = false
    @State private var showURLAlert = false
    @State private var urlText = ""
    @State private var errorMessage = ""
    @State private var selectedItem: DownloadItem?
    @State private var showActionSheet = false
    @State private var webViewURL = URL(string: "https://apple.com")!
    @State private var isLoading = false
    @State private var webViewTitle = "Web Browser"
    @State private var shareItems: [Any] = []
    @State private var showDocumentPicker = false
    @State private var fileToExport: URL?
    @State private var isExtracting = false
    @State private var extractionProgress: Double = 0.0
    @State private var _searchText = ""
    
    // MARK: - Computed Properties
    private var filteredDownloadItems: [DownloadItem] {
        if _searchText.isEmpty {
            return downloadManager.downloadItems
        } else {
            return downloadManager.downloadItems.filter { $0.title.localizedCaseInsensitiveContains(_searchText) }
        }
    }

    var body: some View {
        NBNavigationView("IPA Downloads") {
            ZStack {
                content
                
                if isExtracting {
                    extractionProgressOverlay
                }
            }
            .toolbar {
                trailingToolbarContent
            }
            .onAppear {
                downloadManager.loadDownloadedIPAs()
            }
        }
        .accentColor(.accentColor)
        .alert("Enter Website URL", isPresented: $showURLAlert) {
            urlInputAlert
        } message: {
            Text("Enter the URL of the website containing the IPA file")
        }
        .confirmationDialog("Choose an action", isPresented: $showActionSheet, titleVisibility: .visible) {
            actionSheetContent
        }
        .sheet(isPresented: $showWebView) {
            webViewSheet
        }
        .sheet(isPresented: $showDocumentPicker) {
            documentPickerSheet
        }
    }
}

// MARK: - View Components
private extension DownloaderView {
    @ViewBuilder
    var content: some View {
        downloadsList
            .overlay {
                if downloadManager.downloadItems.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label(.localized("No downloaded IPAs"), systemImage: "square.and.arrow.down.fill")
                        } description: {
                            Text(.localized("Get started by downloading your first IPA file."))
                        } actions: {
                            Button {
                                showURLAlert = true
                            } label: {
                                Text("Add Download").bg()
                            }
                        }
                    }
                }
            }
            .searchable(text: $_searchText, placement: .platform())
    }
        
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No downloaded IPAs")
                .font(.headline)
                .foregroundColor(.gray)
            
            Button("Add Download") {
                showURLAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var downloadsList: some View {
        List {
            ForEach(filteredDownloadItems) { item in
                DownloadItemRow(item: item) { tappedItem in
                    selectedItem = tappedItem
                    showActionSheet = true
                }
            }
            .onDelete(perform: downloadManager.deleteIPA)
        }
        .listStyle(.plain)
    }
    
    var extractionProgressOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(value: extractionProgress, total: 1.0)
                .progressViewStyle(.linear)
                .accentColor(.accentColor)
            
            Text("Importing \(Int(extractionProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 200)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
        .transition(.scale.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: isExtracting)
    }
}

// MARK: - Toolbar Content
private extension DownloaderView {
    var trailingToolbarContent: some ToolbarContent {
        NBToolbarButton(
            "Add",
            systemImage: "plus",
            placement: .topBarTrailing
        ) {
            showURLAlert = true
        }
    }
}

// MARK: - Alert & Sheet Content
private extension DownloaderView {
    var urlInputAlert: some View {
        Group {
            TextField(String("https://example.com"), text: $urlText)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            
            Button("Cancel", role: .cancel) {}
            Button("Go") {
                handleURLInput()
            }
        }
    }
    
    @ViewBuilder
    var actionSheetContent: some View {
        if let selectedItem = selectedItem {
            Button("Share") {
                shareItem(selectedItem)
            }
            
            Button("Import to Library") {
                importIpaToLibrary(selectedItem)
            }
            
            Button("Export to Files App") {
                exportToFiles(selectedItem)
            }
            
            Button("Delete", role: .destructive) {
                deleteItem(selectedItem)
            }
            
            Button("Cancel", role: .cancel) {}
        }
    }
    
    var webViewSheet: some View {
        WebViewSheet(
            downloadManager: downloadManager,
            isPresented: $showWebView,
            url: webViewURL,
            errorMessage: $errorMessage
        )
    }
    
    @ViewBuilder
    var documentPickerSheet: some View {
        if let fileURL = fileToExport {
            FileExporterRepresentableView(
                urlsToExport: [fileURL],
                asCopy: true,
                useLastLocation: false,
                onCompletion: { _ in
                    showDocumentPicker = false
                }
            )
        }
    }

}

// MARK: - Action Handlers
private extension DownloaderView {
    func handleURLInput() {
        guard !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        var finalUrl = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalUrl.lowercased().hasPrefix("http://") && !finalUrl.lowercased().hasPrefix("https://") {
            finalUrl = "https://" + finalUrl
        }
        
        guard let url = URL(string: finalUrl) else {
            UIAlertController.showAlertWithOk(title: "Error", message: "Invalid URL format")
            return
        }
        
        if downloadManager.isFileURL(url) {
            downloadManager.checkFileTypeAndDownload(url: url) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break // Success handled by download manager
                    case .failure(let error):
                        UIAlertController.showAlertWithOk(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        } else {
            webViewURL = url
            showWebView = true
        }
        
        urlText = ""
    }
    
    func shareItem(_ item: DownloadItem) {
        shareItems = [item.localPath]
        UIActivityViewController.show(activityItems: shareItems)
    }
    
    private func importIpaToLibrary(_ file: DownloadItem) {
        let id = "FeatherManualDownload_\(UUID().uuidString)"
        let download = self.libraryManager.startArchive(from: file.url, id: id)
        libraryManager.handlePachageFile(url: file.url, dl: download) { err in
            DispatchQueue.main.async {
                if let error = err {
                    UIAlertController.showAlertWithOk(title: "Error", message: "Whoops!, something went wrong when extracting the file. \nMaybe try switching the extraction library in the settings?")
                } else {
                }
                if let index = libraryManager.getDownloadIndex(by: download.id) {
                    libraryManager.downloads.remove(at: index)
                }
            }
        }
    }
    
    func exportToFiles(_ item: DownloadItem) {
        fileToExport = item.localPath
        showDocumentPicker = true
    }
    
    func deleteItem(_ item: DownloadItem) {
        guard let index = downloadManager.downloadItems.firstIndex(where: { $0.id == item.id }) else { return }
        downloadManager.deleteIPA(at: IndexSet(integer: index))
    }
    
} 
