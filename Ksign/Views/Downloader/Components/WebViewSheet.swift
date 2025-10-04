//
//  WebViewSheet.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit

// Web View Sheet
struct WebViewSheet: View {
    @ObservedObject var downloadManager: IPADownloadManager
    @Binding var isPresented: Bool
    let url: URL
    @Binding var errorMessage: String
    @State private var isLoading = false
    @State private var title = "Web Browser"
    
    var body: some View {
        NavigationView {
            ZStack {
                WebViewContainer(
                    downloadManager: downloadManager,
                    isPresented: $isPresented,
                    errorMessage: $errorMessage,
                    isLoading: $isLoading,
                    title: $title,
                    url: url
                )
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .accentColor(.accentColor)
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle(title)
            .navigationBarItems(
                leading: Button("Close") {
                    isPresented = false
                },
                trailing: Button(action: {
                    // Reload the web view
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.accentColor)
                }
            )
        }
        .accentColor(.accentColor)
    }
} 