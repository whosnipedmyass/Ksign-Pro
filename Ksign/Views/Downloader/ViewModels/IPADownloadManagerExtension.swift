//
//  IPADownloadManagerExtension.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import Foundation

extension IPADownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloadItemId = activeDownloads[downloadTask.taskIdentifier],
              let index = downloadItems.firstIndex(where: { $0.id.uuidString == downloadItemId }) else {
            print("Could not find download item for completed task: \(downloadTask.taskIdentifier)")
            return
        }
        
        let item = downloadItems[index]
        
        do {
            if FileManager.default.fileExists(atPath: item.localPath.path) {
                try FileManager.default.removeItem(at: item.localPath)
            }
            
            try FileManager.default.moveItem(at: location, to: item.localPath)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var updatedItem = item
                updatedItem.isFinished = true
                updatedItem.progress = 1.0
                
                if let fileSize = try? FileManager.default.attributesOfItem(atPath: item.localPath.path)[.size] as? Int64 {
                    updatedItem.totalBytes = fileSize
                    updatedItem.bytesDownloaded = fileSize
                }
                
                if index < self.downloadItems.count {
                    self.downloadItems[index] = updatedItem
                }
                
                self.activeDownloads.removeValue(forKey: downloadTask.taskIdentifier)
            }
            
            print("Successfully completed download: \(item.title)")
            
        } catch {
            print("Error saving downloaded file: \(error)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if index < self.downloadItems.count {
                    self.downloadItems.remove(at: index)
                }
                self.activeDownloads.removeValue(forKey: downloadTask.taskIdentifier)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let downloadItemId = activeDownloads[downloadTask.taskIdentifier],
              let index = downloadItems.firstIndex(where: { $0.id.uuidString == downloadItemId }) else {
            return
        }
        
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, index < self.downloadItems.count else { return }
            
            var item = self.downloadItems[index]
            item.progress = progress
            item.bytesDownloaded = totalBytesWritten
            item.totalBytes = totalBytesExpectedToWrite
            self.downloadItems[index] = item
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            activeDownloads.removeValue(forKey: task.taskIdentifier)
        }
        
        if let error = error {
            print("Download error for task \(task.taskIdentifier): \(error)")
            
            guard let downloadItemId = activeDownloads[task.taskIdentifier],
                  let index = downloadItems.firstIndex(where: { $0.id.uuidString == downloadItemId }) else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self, index < self.downloadItems.count else { return }
                
                if (error as NSError).code != NSURLErrorCancelled {
                    print("Removing failed download: \(self.downloadItems[index].title)")
                }
                
                self.downloadItems.remove(at: index)
            }
        }
    }
} 