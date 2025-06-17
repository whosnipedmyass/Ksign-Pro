//
//  Storage+Sources.swift
//  Feather
//
//  Created by samara on 12.04.2025.
//

import CoreData
import AltSourceKit

// MARK: - Class extension: Sources
extension Storage {
	/// Retrieve sources in an array, we don't normally need this in swiftUI but we have it for the copy sources action
	func getSources() -> [AltSource] {
		let request: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		return (try? context.fetch(request)) ?? []
	}
	
	func addSource(
		_ url: URL,
		name: String? = "Unknown",
		identifier: String,
		iconURL: URL? = nil,
		deferSave: Bool = false,
		isBuiltIn: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		if sourceExists(identifier) {
			completion(nil)
			print("ignoring \(identifier)")
			return
		}
		
		let new = AltSource(context: context)
		new.name = name
		new.date = Date()
		new.identifier = identifier
		new.sourceURL = url
		new.iconURL = iconURL
		new.setValue(isBuiltIn, forKey: "isBuiltIn")
		
		do {
			if !deferSave {
				try context.save()
			}
			completion(nil)
		} catch {
			completion(error)
		}
	}
	
	func addSource(
		_ url: URL,
		repository: ASRepository,
		id: String = "",
		deferSave: Bool = false,
		isBuiltIn: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		addSource(
			url,
			name: repository.name,
			identifier: !id.isEmpty
						? id
						: (repository.id ?? url.absoluteString),
			iconURL: repository.currentIconURL,
			deferSave: deferSave,
			isBuiltIn: isBuiltIn,
			completion: completion
		)
	}

	func addSources(
		repos: [URL: ASRepository],
		completion: @escaping (Error?) -> Void
	) {
		for (url, repo) in repos {
			addSource(
				url,
				repository: repo,
				deferSave: true,
				completion: { error in
					if let error {
						completion(error)
					}
				}
			)
		}
		
        saveContext()
        completion(nil)
	}


	func addBuiltInSources() {
		let builtInSources: [(URL, String, String, URL?)] = [
            (URL(string: "https://repository.apptesters.org")!, "Apptesters IPA repository", "org.apptesters.repo", URL(string: "https://apptesters.org/wp-content/uploads/2024/04/AppTesters-Logo-Site-Icon.webp")!),
            (URL(string: "https://ipa.cypwn.xyz/cypwn.json")!, "CyPwn IPA Library", "xyz.cypwn.ipalibrary", URL(string: "https://repo.cypwn.xyz/assets/images/cypwn_small.png")!),
            (URL(string: "https://raw.githubusercontent.com/whoeevee/EeveeSpotify/swift/repo.json")!, "EeveeSpotify", "com.eevee.source", URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/0c/1f/61/0c1f6144-af80-f395-3204-1d14fd8b2be7/AppIcon-0-0-1x_U007emarketing-0-6-0-0-85-220.png/512x512bb.jpg")!),
            (URL(string: "https://apps.nabzclan.vip/repos/altstore.php")!, "Nabzclan - IPA Library", "com.nabzclan.repo.altstore", URL(string: "https://cdn.nabzclan.vip/imgs/logo/logo_400x400.jpg")!),
            (URL(string: "https://ipa.thuthuatjb.com/repo")!, "TTJB IPA", "ttjb.ipa.repo", URL(string: "https://ipa.thuthuatjb.com/img/logo.png")!),
            (URL(string: "https://repo.ethsign.fyi")!, "ethMods Repo", "fyi.ethsign.repo", URL(string: "https://repo.ethsign.fyi/icon.jpg")!),
		]
		
		for source in builtInSources {
			addSource(
				source.0,
				name: source.1,
				identifier: source.2,
				iconURL: source.3,
				deferSave: true,
				isBuiltIn: true
			) { _ in }
		}
		
		saveContext()
	}

	func deleteSource(for source: AltSource) {
		context.delete(source)
		saveContext()
	}

	func sourceExists(_ identifier: String) -> Bool {
		let fetchRequest: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)

		do {
			let count = try context.count(for: fetchRequest)
			return count > 0
		} catch {
			print("Error checking if repository exists: \(error)")
			return false
		}
	}
}
