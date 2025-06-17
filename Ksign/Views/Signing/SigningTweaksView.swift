//
//  SigningTweaksView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningTweaksView: View {
	@State private var _isAddingPresenting = false
	@State private var _tweaksInDirectory: [URL] = []
	@State private var _enabledTweaks: Set<URL> = []
	
	@Binding var options: Options
	
	// MARK: Body
	var body: some View {
		List {
			// Display added tweaks from options
			if !options.injectionFiles.isEmpty {
				Section(header: Text("Added Tweaks").font(.subheadline)) {
					ForEach(options.injectionFiles, id: \.absoluteString) { tweak in
						_file(tweak: tweak, isFromOptions: true)
					}
				}
			}
			
			// Display available tweaks from directory
			if !_tweaksInDirectory.isEmpty {
				Section(header: Text("Available Tweaks").font(.subheadline)) {
					ForEach(_tweaksInDirectory, id: \.absoluteString) { tweak in
						_file(tweak: tweak, isFromOptions: false)
					}
				}
			}
			
			if options.injectionFiles.isEmpty && _tweaksInDirectory.isEmpty {
				Text("No tweaks found. Add tweaks using the + button.")
					.foregroundColor(.secondary)
					.frame(maxWidth: .infinity, alignment: .center)
					.padding()
			}
		}
		.navigationTitle(.localized("Tweaks"))
		.listStyle(.plain)
		.toolbar {
			NBToolbarButton(
				systemImage: "plus",
				style: .icon,
				placement: .topBarTrailing
			) {
				_isAddingPresenting = true
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
                allowedContentTypes: [.item],
				onDocumentsPicked: { urls in
					guard let selectedFileURL = urls.first else { return }
					
					// Check if from file provider and handle security-scoped resource
					var didStartAccessing = false
					if FileManager.default.isFileFromFileProvider(at: selectedFileURL) {
						didStartAccessing = selectedFileURL.startAccessingSecurityScopedResource()
					}
					
					// Ensure we stop accessing the resource when done
					defer {
						if didStartAccessing {
							selectedFileURL.stopAccessingSecurityScopedResource()
						}
					}
					
					let fileExtension = selectedFileURL.pathExtension.lowercased()
					if ["dylib", "deb", "framework"].contains(fileExtension) {
						// Copy to tweaks directory
						let tweaksDir = FileManager.default.tweaks
						let destinationURL = tweaksDir.appendingPathComponent(selectedFileURL.lastPathComponent)
						
						do {
							// Create tweaks directory if it doesn't exist
							try FileManager.default.createDirectoryIfNeeded(at: tweaksDir)
							
							// Copy the file to the tweaks directory
							if FileManager.default.fileExists(atPath: destinationURL.path) {
								// If file exists, remove it first
								try FileManager.default.removeItem(at: destinationURL)
							}
							
							// Handle differently based on file type
							if fileExtension == "framework" {
								// Frameworks are directories, so use direct copy
								try FileManager.default.copyItem(at: selectedFileURL, to: destinationURL)
							} else {
								// For regular files, use data reading/writing
								let fileData = try Data(contentsOf: selectedFileURL)
								try fileData.write(to: destinationURL)
							}
							
							// Add to options if it's toggled
							if !options.injectionFiles.contains(destinationURL) {
								options.injectionFiles.append(destinationURL)
							}
							
							// Reload tweaks list
							_loadTweaks()
						} catch {
							print("Error copying tweak file: \(error)")
						}
					} else {
						// Use the original moveAndStore method for non-tweak files
						FileManager.default.moveAndStore(selectedFileURL, with: "FeatherTweak") { url in
							options.injectionFiles.append(url)
							_loadTweaks()
						}
					}
				}
			)
		}
		.animation(.smooth, value: options.injectionFiles)
		.animation(.smooth, value: _tweaksInDirectory)
		.onAppear(perform: _loadTweaks)
	}
	
	private func _loadTweaks() {
		let tweaksDir = FileManager.default.tweaks
		guard let files = try? FileManager.default.contentsOfDirectory(
			at: tweaksDir,
			includingPropertiesForKeys: nil
		) else { return }
		
		_tweaksInDirectory = files.filter { url in
			let ext = url.pathExtension.lowercased()
			return ext == "dylib" || ext == "deb" || ext == "framework"
		}
		
		// Initialize enabled tweaks from options
		_enabledTweaks = Set(options.injectionFiles)
	}
}

// MARK: - Extension: View
extension SigningTweaksView {
	@ViewBuilder
	private func _file(tweak: URL, isFromOptions: Bool) -> some View {
		HStack {
			Text(tweak.lastPathComponent)
				.lineLimit(2)
				.frame(maxWidth: .infinity, alignment: .leading)
			
			if !isFromOptions {
				Toggle("", isOn: Binding(
					get: { _enabledTweaks.contains(tweak) },
					set: { newValue in
						if newValue {
							_enabledTweaks.insert(tweak)
							if !options.injectionFiles.contains(tweak) {
								options.injectionFiles.append(tweak)
							}
						} else {
							_enabledTweaks.remove(tweak)
							if let index = options.injectionFiles.firstIndex(of: tweak) {
								options.injectionFiles.remove(at: index)
							}
						}
					}
				))
				.labelsHidden()
			}
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			Button(role: .destructive) {
				if isFromOptions {
					FileManager.default.deleteStored(tweak) { url in
						if let index = options.injectionFiles.firstIndex(where: { $0 == url }) {
							options.injectionFiles.remove(at: index)
						}
						_loadTweaks()
					}
				} else {
					do {
						try FileManager.default.removeItem(at: tweak)
						if let index = options.injectionFiles.firstIndex(of: tweak) {
							options.injectionFiles.remove(at: index)
						}
						_enabledTweaks.remove(tweak)
						_loadTweaks()
					} catch {
						print("Error deleting tweak: \(error)")
					}
				}
			} label: {
				Label(.localized("Delete"), systemImage: "trash")
			}
		}
	}
}
