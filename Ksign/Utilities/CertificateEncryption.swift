//
//  CertificateEncryption.swift
//  Ksign
//
//  Created by Nagata Asami on 6/14/25.
//

import Foundation
import CryptoKit
import UIKit
import CommonCrypto

// Yall be doing reverse enginnering stuffs on .ksign I have to do this, sorry.
final class CertificateEncryption {
    
    // MARK: - Private Properties
    private static let kIterations: UInt32 = 10000
    private static let kKeyLength = 32
    
    private static func generateSalt() -> String {
        return "Nyagata_Nyasami" // You can put anything here as the encrytion key if you building from source yourself.
    }

    private static func generateEncryptionKey() -> Data {
        let salt = generateSalt()
        
        let password = Data(salt.utf8)
        let saltData = Data(salt.utf8)
        
        var derivedKey = Data(count: kKeyLength)
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            password.withUnsafeBytes { passwordBytes in
                saltData.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        kIterations,
                        derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                        kKeyLength
                    )
                }
            }
        }
        
        if result != kCCSuccess {
            let keyData = Data(salt.utf8)
            let hashedKey = SHA256.hash(data: keyData)
            return Data(hashedKey)
        }
        
        return derivedKey
    }
    
    // MARK: - Public Methods
    
    static func encryptCertificateData(_ data: Data) -> Data? {
        do {
            let key = SymmetricKey(data: generateEncryptionKey())
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("Certificate encryption failed: \(error)")
            return nil
        }
    }
    
    static func decryptCertificateData(_ encryptedData: Data) -> Data? {
        do {
            let key = SymmetricKey(data: generateEncryptionKey())
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            print("Certificate decryption failed: \(error)")
            return nil
        }
    }
    
    static func safeEncrypt(_ data: Data) -> Data {
        return encryptCertificateData(data) ?? data
    }
    
    static func safeDecrypt(_ data: Data) -> Data {
        return decryptCertificateData(data) ?? data
    }
    
    static func isEncrypted(_ data: Data) -> Bool {
        return data.count >= 28
    }
    
    // MARK: - .ksign File Format Support
    
    static func encryptKsignData(_ data: Data) -> Data? {
        guard let encryptedData = encryptCertificateData(data) else { return nil }
        
        var finalData = Data("KSIGN01".utf8)
        finalData.append(encryptedData)
        
        return finalData
    }
    
    static func decryptKsignData(_ data: Data) -> Data? {
        let signatureData = Data("KSIGN01".utf8)
        
        guard data.count >= signatureData.count else { return nil }
        guard data.prefix(signatureData.count) == signatureData else { return nil }
        
        let encryptedData = data.subdata(in: signatureData.count..<data.count)
        
        return decryptCertificateData(encryptedData)
    }

    static func migrateExistingCertificates() {
        let storage = Storage.shared
        let context = storage.context
        
        let request = CertificatePair.fetchRequest()
        
        do {
            let certificates = try context.fetch(request)
            var migratedCount = 0
            
            for cert in certificates {
                var needsSave = false
                
                if let p12Data = cert.p12Data, !isEncrypted(p12Data) {
                    cert.p12Data = safeEncrypt(p12Data)
                    needsSave = true
                    print("Encrypted p12 data for certificate: \(cert.uuid ?? "unknown")")
                }
                
                if let provisionData = cert.provisionData, !isEncrypted(provisionData) {
                    cert.provisionData = safeEncrypt(provisionData)
                    needsSave = true
                    print("Encrypted provision data for certificate: \(cert.uuid ?? "unknown")")
                }
                
                if needsSave {
                    migratedCount += 1
                }
            }
            
            if migratedCount > 0 {
                storage.saveContext()
                print("Migrated \(migratedCount) certificates to encrypted format")
            }
            
        } catch {
            print("Failed to migrate existing certificates: \(error)")
        }
    }
} 
