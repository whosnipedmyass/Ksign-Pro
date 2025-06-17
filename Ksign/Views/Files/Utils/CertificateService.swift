//
//  CertificateService.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import Foundation
import UniformTypeIdentifiers

final class CertificateService {
    
    // MARK: - Shared Instance
    static let shared = CertificateService()
    private init() {}
    
    // MARK: - Import Result
    enum ImportResult {
        case success(String)
        case failure(ImportError)
    }
    
    enum ImportError: LocalizedError {
        case invalidFile
        case corruptedKsignFile
        case invalidFileFormat
        case missingProvisionData
        case missingCertificateData
        case invalidPassword
        case multipleProvisionFiles
        case noProvisionFile
        case importFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "Invalid or inaccessible file"
            case .corruptedKsignFile:
                return "Invalid or corrupted .ksign file"
            case .invalidFileFormat:
                return "Invalid file format"
            case .missingProvisionData:
                return "Missing provisioning profile data"
            case .missingCertificateData:
                return "Missing certificate data"
            case .invalidPassword:
                return "Invalid certificate password"
            case .multipleProvisionFiles:
                return "Multiple .mobileprovision files found. Please import certificate using the Settings > Certificates section."
            case .noProvisionFile:
                return "No .mobileprovision file found in the same directory"
            case .importFailed(let message):
                return "Failed to import certificate: \(message)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func importP12Certificate(from file: FileItem, completion: @escaping (ImportResult) -> Void) {
        guard file.isP12Certificate else {
            completion(.failure(.invalidFile))
            return
        }
        
        let directory = file.url.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let provisionFiles = directoryContents.filter { url in
                url.pathExtension.lowercased() == "mobileprovision"
            }
            
            if provisionFiles.isEmpty {
                completion(.failure(.noProvisionFile))
                return
            }
            
            if provisionFiles.count > 1 {
                completion(.failure(.multipleProvisionFiles))
                return
            }
            
            let provisionURL = provisionFiles[0]
            let resourceValues = try provisionURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey])
            let provisionFile = FileItem(
                name: provisionURL.lastPathComponent,
                url: provisionURL,
                size: Int64(resourceValues.fileSize ?? 0),
                creationDate: resourceValues.creationDate,
                isDirectory: resourceValues.isDirectory ?? false
            )
            
            // Import with password prompt
            importP12Certificate(p12File: file, provisionFile: provisionFile, password: "", completion: completion)
            
        } catch {
            completion(.failure(.importFailed(error.localizedDescription)))
        }
    }
    
    func importP12Certificate(p12File: FileItem, provisionFile: FileItem, password: String, completion: @escaping (ImportResult) -> Void) {
        guard FR.checkPasswordForCertificate(
            for: p12File.url,
            with: password,
            using: provisionFile.url
        ) else {
            completion(.failure(.invalidPassword))
            return
        }
        
        FR.handleCertificateFiles(
            p12URL: p12File.url,
            provisionURL: provisionFile.url,
            p12Password: password,
            certificateName: p12File.name.replacingOccurrences(of: ".p12", with: "")
        ) { error in
            if let error = error {
                completion(.failure(.importFailed(error.localizedDescription)))
            } else {
                completion(.success("Certificate imported successfully"))
            }
        }
    }
    
    func importKsignCertificate(from file: FileItem, completion: @escaping (ImportResult) -> Void) {
        guard file.isKsignFile else {
            completion(.failure(.invalidFile))
            return
        }
        
        importKsignCertificate(from: file.url, completion: completion)
    }
    
    func importKsignCertificate(from url: URL, completion: @escaping (ImportResult) -> Void) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()

        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let fileData = try Data(contentsOf: url)
            
            guard let decryptedData = decryptKsignData(fileData) else {
                completion(.failure(.corruptedKsignFile))
                return
            }
            
            guard let json = try JSONSerialization.jsonObject(with: decryptedData, options: []) as? [String: Any] else {
                completion(.failure(.invalidFileFormat))
                return
            }
            
            let name = json["name"] as? String ?? "Certificate"
            
            guard let provisionBase64 = json["provisionData"] as? String,
                  let provisionData = Data(base64Encoded: provisionBase64) else {
                completion(.failure(.missingProvisionData))
                return
            }
            
            guard let p12Base64 = json["p12Data"] as? String,
                  let p12Data = Data(base64Encoded: p12Base64) else {
                completion(.failure(.missingCertificateData))
                return
            }
            
            let password = json["password"] as? String ?? ""
            
            guard FR.checkPasswordForCertificateData(
                p12Data: p12Data,
                provisionData: provisionData,
                password: password
            ) else {
                completion(.failure(.invalidPassword))
                return
            }
            
            FR.handleCertificateData(
                p12Data: p12Data,
                provisionData: provisionData,
                p12Password: password,
                certificateName: name
            ) { error in
                if let error = error {
                    completion(.failure(.importFailed(error.localizedDescription)))
                } else {
                    completion(.success("Certificate imported successfully from .ksign file"))
                }
            }
            
        } catch {
            completion(.failure(.importFailed(error.localizedDescription)))
        }
    }
    
    // MARK: - Private Decryption Methods
    
    private func decryptKsignData(_ data: Data) -> Data? {
        return CertificateEncryption.decryptKsignData(data)
    }
}

// MARK: - Extensions

extension UTType {
    static var ksign: UTType {
        UTType(exportedAs: "nya.asami.ksign.cert")
    }
} 