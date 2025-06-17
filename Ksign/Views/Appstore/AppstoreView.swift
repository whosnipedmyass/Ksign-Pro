//
//  AppstoreView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

struct AppstoreView: View {
    @StateObject var viewModel = SourcesViewModel.shared
    @State private var searchText = ""
    @State private var sortOption: SourceAppsView.SortOption = .default
    @State private var sortAscending = true
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var sources: [ASRepository]?
    
    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var sourcesData: FetchedResults<AltSource>
    
    var body: some View {
        NBNavigationView(.localized("App Store")) {
            ZStack {
                if let sources, !sources.isEmpty {
                    SourceAppsTableRepresentableView(
                        sources: sources,
                        searchText: $searchText,
                        sortOption: $sortOption,
                        sortAscending: $sortAscending
                    )
                    .ignoresSafeArea()
                } else {
                    ProgressView()
                }
            }
            .searchable(text: $searchText, placement: .platform())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SourcesView()) {
                        Text(.localized("Source"))
                    }
                }
                
                NBToolbarMenu(
                    systemImage: "line.3.horizontal.decrease",
                    style: .icon,
                    placement: .topBarTrailing
                ) {
                    sortActions()
                }
            }
        }
        .onAppear {
            // Nothing needed here now, task handles initial loading
        }
        .onChange(of: viewModel.isFinished) { _ in
            if sources == nil || sources?.isEmpty == true {
                load()
            }
        }
        .task {
            if !hasLoadedOnce {
                await viewModel.fetchSources(sourcesData)
                load()
                hasLoadedOnce = true
            }
        }
        .refreshable {
            await viewModel.fetchSources(sourcesData, refresh: true)
            load()
        }
    }
    
    private func load() {
        isLoading = true
        
        Task {
            let loadedSources = Array(sourcesData).compactMap { viewModel.sources[$0] }
            sources = loadedSources
            withAnimation(.easeIn(duration: 0.2)) {
                isLoading = false
            }
        }
    }
    
    @ViewBuilder
    private func sortActions() -> some View {
        Section(.localized("Filter by")) {
            ForEach(SourceAppsView.SortOption.allCases, id: \.displayName) { opt in
                sortButton(for: opt)
            }
        }
    }
    
    private func sortButton(for option: SourceAppsView.SortOption) -> some View {
        Button {
            if sortOption == option {
                sortAscending.toggle()
            } else {
                sortOption = option
                sortAscending = true
            }
        } label: {
            HStack {
                Text(option.displayName)
                Spacer()
                if sortOption == option {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                }
            }
        }
    }
}

