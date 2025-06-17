//
//  IPAHandler.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import Foundation
import Zip
import SwiftUICore
import SWCompression
import Foundation.NSByteCountFormatter

final class AppFileHandler: NSObject, @unchecked Sendable {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private let _uniqueWorkDir: URL
	var uniqueWorkDirPayload: URL?

	private var _ipa: URL
	private let _install: Bool
	private let _download: Download?
	
	init(
		file ipa: URL,
		install: Bool = false,
		download: Download? = nil
	) {
		self._ipa = ipa
		self._install = install
		self._download = download
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherImport_\(_uuid)", isDirectory: true)
		
		super.init()
		print("Import initiated for: \(_ipa.lastPathComponent) with ID: \(_uuid)")
	}
	
	func copy() async throws {
		try _fileManager.createDirectoryIfNeeded(at: _uniqueWorkDir)
		
		let destinationURL = _uniqueWorkDir.appendingPathComponent(_ipa.lastPathComponent)

		try _fileManager.removeFileIfNeeded(at: destinationURL)
		
		try _fileManager.copyItem(at: _ipa, to: destinationURL)
		_ipa = destinationURL
		print("[\(_uuid)] File copied to: \(_ipa.path)")
	}
	
	func extract() async throws {
		Zip.addCustomFileExtension("ipa")
		Zip.addCustomFileExtension("tipa")
		
		let download = self._download
		
		// Check if file is larger than 500MB
		let fileSize = try _fileManager.attributesOfItem(atPath: _ipa.path)[.size] as? Int64 ?? 0
		let isLargeFile = fileSize > 500_000_000 // 500MB threshold
		
		print("[\(_uuid)] File size: \(fileSize) bytes, using \(isLargeFile ? "large file" : "standard") extraction")
		
		try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .utility).async {
				do {
					if isLargeFile {
						// For large files, use a more memory-efficient approach
						try self.extractLargeFile(download: download)
						self.uniqueWorkDirPayload = self._uniqueWorkDir.appendingPathComponent("Payload")
						continuation.resume()
					} else {
						// Use standard Zip for smaller files
						try Zip.unzipFile(
							self._ipa,
							destination: self._uniqueWorkDir,
							overwrite: true,
							password: nil,
							progress: { progress in
								print("[\(self._uuid)] Unzip progress: \(progress)")
								
								if let download = download {
									DispatchQueue.main.async {
										download.unpackageProgress = progress
									}
								}
							}
						)
						
						self.uniqueWorkDirPayload = self._uniqueWorkDir.appendingPathComponent("Payload")
						continuation.resume()
					}
				} catch {
					print("[\(self._uuid)] Extraction error: \(error.localizedDescription)")
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	private func extractLargeFile(download: Download?) throws {
		// Check available disk space
		if let freeDiskSpace = try? _fileManager.volumeAvailableCapacity(for: _uniqueWorkDir),
		   let fileSize = try? _fileManager.attributesOfItem(atPath: _ipa.path)[.size] as? Int64 {
			// We need at least twice the file size for safe extraction
			if freeDiskSpace < fileSize * 2 {
				throw ImportedFileHandlerError.notEnoughDiskSpace(needed: fileSize * 2, available: freeDiskSpace)
			}
		}
		
		print("[\(_uuid)] Using minizip-based extraction for large file")
		
		// Create Payload directory
		let payloadPath = _uniqueWorkDir.appendingPathComponent("Payload")
		try _fileManager.createDirectoryIfNeeded(at: payloadPath)
		
		// Use the built-in Zip extraction which uses minizip internally
		// for memory-efficient extraction
		do {
			try Zip.unzipFile(
				_ipa,
				destination: _uniqueWorkDir,
				overwrite: true,
				password: nil,
				progress: { progress in
					print("Large file extraction progress: \(progress)")
					if let download = download {
						DispatchQueue.main.async {
							download.unpackageProgress = progress
						}
					}
				}
			)
		} catch {
			print("[\(_uuid)] Zip extraction error: \(error.localizedDescription)")
			throw ImportedFileHandlerError.extractionFailed
		}
		
		// Verify the Payload directory was created
		if !_fileManager.fileExists(atPath: payloadPath.path) {
			throw ImportedFileHandlerError.payloadNotFound
		}
	}
	
	func move() async throws {
		guard let payloadURL = uniqueWorkDirPayload else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		let destinationURL = try await _directory()
		
		guard _fileManager.fileExists(atPath: payloadURL.path) else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		try _fileManager.moveItem(at: payloadURL, to: destinationURL)
		print("[\(_uuid)] Moved Payload to: \(destinationURL.path)")
		
		try? _fileManager.removeItem(at: _uniqueWorkDir)
	}
	
	func addToDatabase() async throws {
		let app = try await _directory()
		
		guard let appUrl = _fileManager.getPath(in: app, for: "app") else {
			return
		}
		
		let bundle = Bundle(url: appUrl)
		
		Storage.shared.addImported(
			uuid: _uuid,
			appName: bundle?.name,
			appIdentifier: bundle?.bundleIdentifier,
			appVersion: bundle?.version,
			appIcon: bundle?.iconFileName
		) { _ in
			print("[\(self._uuid)] Added to database")
		}
	}
	
	private func _directory() async throws -> URL {
		// Documents/Feather/Unsigned/\(UUID)
		_fileManager.unsigned(_uuid)
	}
	
	func clean() async throws {
		try _fileManager.removeFileIfNeeded(at: _uniqueWorkDir)
	}
}

enum ImportedFileHandlerError: Error, CustomStringConvertible {
	case payloadNotFound
	case notEnoughDiskSpace(needed: Int64, available: Int64)
	case extractionFailed
	case zipLibraryNotAvailable
	
	var description: String {
		switch self {
		case .payloadNotFound:
			return "No Payload folder was found in the archive. The file may be corrupted."
		case .notEnoughDiskSpace(let needed, let available):
			let neededStr = ByteCountFormatter.string(fromByteCount: needed, countStyle: .file)
			let availableStr = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
			return "Not enough disk space. Needed: \(neededStr), Available: \(availableStr)"
		case .extractionFailed:
			return "Failed to extract the archive. The file may be corrupted."
		case .zipLibraryNotAvailable:
			return "Zip library is not available on this platform."
		}
	}
}
