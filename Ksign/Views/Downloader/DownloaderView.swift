//
//  DownloaderView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct DownloaderView: View {
    @StateObject private var downloadManager = IPADownloadManager()
    @State private var showWebView = false
    @State private var showURLAlert = false
    @State private var urlText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedItem: DownloadItem?
    @State private var showActionSheet = false
    @State private var webViewURL = URL(string: "https://apple.com")!
    @State private var isLoading = false
    @State private var webViewTitle = "Web Browser"
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showDocumentPicker = false
    @State private var fileToExport: URL?
    @State private var isExtracting = false
    @State private var extractionProgress: Double = 0.0
    @StateObject private var libraryManager = DownloadManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    if downloadManager.downloadItems.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No downloaded IPAs")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showURLAlert = true
                            }) {
                                Text("Add Download")
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(downloadManager.downloadItems) { item in
                                DownloadItemRow(item: item, onTap: { tappedItem in
                                    selectedItem = tappedItem
                                    showActionSheet = true
                                })
                            }
                            .onDelete { indexSet in
                                downloadManager.deleteIPA(at: indexSet)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                
                if isExtracting {
                    extractionProgressView
                }
            }
            .navigationTitle("IPA Downloads")
            .navigationBarItems(
                leading: Button(action: {
                    downloadManager.debugDownloadStatus()
                }) {
                    Image(systemName: "info.circle")
                },
                trailing: Button(action: {
                    showURLAlert = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .alert("Enter Website URL", isPresented: $showURLAlert) {
                TextField("https://example.com", text: $urlText)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                Button("Cancel", role: .cancel) {}
                Button("Go") {
                    handleURLInput()
                }
            } message: {
                Text("Enter the URL of the website containing the IPA file")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Choose an action", isPresented: $showActionSheet, titleVisibility: .visible) {
                if let selectedItem = selectedItem {
                    Button("Share") {
                        shareItem(selectedItem)
                    }
                    
                    Button("Import to Library") {
                        importItemToLibrary(selectedItem)
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
            .sheet(isPresented: $showWebView) {
                WebViewSheet(
                    downloadManager: downloadManager,
                    isPresented: $showWebView,
                    url: webViewURL,
                    showError: $showError,
                    errorMessage: $errorMessage
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                DownloaderShareSheet(items: shareItems)
            }
            .sheet(isPresented: $showDocumentPicker) {
                if let fileURL = fileToExport {
                    DocumentPickerView(fileURL: fileURL)
                }
            }
            .onAppear {
                downloadManager.loadDownloadedIPAs()
            }
        }
        .accentColor(.accentColor)
    }
    
    private var extractionProgressView: some View {
        VStack {
            ProgressView(value: extractionProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(.accentColor)
                .padding()
            
            Text("Importing \(Int(extractionProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 200)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 5)
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    private func handleURLInput() {
        guard !urlText.isEmpty else { return }
        
        var finalUrl = urlText
        if !urlText.lowercased().hasPrefix("http://") && !urlText.lowercased().hasPrefix("https://") {
            finalUrl = "https://" + urlText
        }
        
        if let url = URL(string: finalUrl) {
            if downloadManager.isFileURL(url) {
                downloadManager.checkFileTypeAndDownload(url: url) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let filename):
                            break
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            } else {
                webViewURL = url
                showWebView = true
            }
        } else {
            errorMessage = "Invalid URL format"
            showError = true
        }
        
        urlText = ""
    }
    
    private func shareItem(_ item: DownloadItem) {
        let didStartAccessing = item.localPath.startAccessingSecurityScopedResource()
        
        shareItems = [item.localPath]
        showingShareSheet = true
        
        if didStartAccessing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                item.localPath.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    private func importItemToLibrary(_ item: DownloadItem) {
        isExtracting = true
        extractionProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let id = "FeatherDownloader_\(UUID().uuidString)"
                
                let download = self.libraryManager.startArchive(from: item.localPath, id: id)
                
                DispatchQueue.main.async {
                    self.extractionProgress = 0.3
                }
                
                try self.libraryManager.handlePachageFile(url: item.localPath, dl: download)
                
                DispatchQueue.main.async {
                    self.extractionProgress = 0.8
                }
                
                Thread.sleep(forTimeInterval: 0.5)
                
                DispatchQueue.main.async {
                    self.isExtracting = false
                    self.errorMessage = "Successfully imported \(item.title) to Library"
                    self.showError = true
                    
                    NotificationCenter.default.post(name: Notification.Name("lfetch"), object: nil)
                }
            } catch {
                print("Import error: \(error)")
                DispatchQueue.main.async {
                    self.isExtracting = false
                    self.errorMessage = "Failed to import to Library: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func exportToFiles(_ item: DownloadItem) {
        fileToExport = item.localPath
        showDocumentPicker = true
    }
    
    private func deleteItem(_ item: DownloadItem) {
        if let index = downloadManager.downloadItems.firstIndex(where: { $0.id == item.id }) {
            downloadManager.deleteIPA(at: IndexSet(integer: index))
        }
    }
} 