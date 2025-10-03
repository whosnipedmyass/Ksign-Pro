//
//  WebViewContainer.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var downloadManager: IPADownloadManager
    @Binding var isPresented: Bool
    @Binding var errorMessage: String
    @Binding var isLoading: Bool
    @Binding var title: String
    var initialURL: URL
    
    let webView: WKWebView
    
    init(downloadManager: IPADownloadManager, isPresented: Binding<Bool>, errorMessage: Binding<String>, isLoading: Binding<Bool>, title: Binding<String>, url: URL) {
        self.downloadManager = downloadManager
        self._isPresented = isPresented
        self._errorMessage = errorMessage
        self._isLoading = isLoading
        self._title = title
        self.initialURL = url
        
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        config.preferences = preferences
        
        config.processPool = WKProcessPool()
        self.webView = WKWebView(frame: .zero, configuration: config)
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        
        let windowOpenScript = WKUserScript(
            source: """
            window.nativeOpen = window.open;
            window.open = function(url, target, features) {
                if (url) {
                    window.webkit.messageHandlers.windowOpen.postMessage(url);
                    return null;
                } else {
                    return window.nativeOpen(url, target, features);
                }
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        webView.configuration.userContentController.addUserScript(windowOpenScript)
        
        let request = URLRequest(url: initialURL)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Updates happen through bindings and coordinator
    }
    
    func handleITMSURL(_ url: URL) {
        downloadManager.handleITMSServicesURL(url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let filename):
                    self.isPresented = false
                case .failure(let error):
                    UIAlertController.showAlertWithOk(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func downloadDirectFile(_ url: URL) {
        isPresented = false
        
        downloadManager.checkFileTypeAndDownload(url: url) { _ in
            // Result handled by download manager
        }
    }
} 
