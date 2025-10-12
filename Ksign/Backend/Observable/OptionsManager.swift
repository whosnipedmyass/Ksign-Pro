//
//  OptionsManager.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import Foundation
import UIKit

// MARK: - Class
class OptionsManager: ObservableObject {
	static let shared = OptionsManager()
	
	@Published var options: Options
	private let _key = "signing_options"
	
	init() {
		if let data = UserDefaults.standard.data(forKey: _key),
		   let savedOptions = try? JSONDecoder().decode(Options.self, from: data) {
			self.options = savedOptions
		} else {
			self.options = Options.defaultOptions
			self.saveOptions()
		}
	}
	
	/// Saves options
	func saveOptions() {
		if let encoded = try? JSONEncoder().encode(options) {
			UserDefaults.standard.set(encoded, forKey: _key)
			objectWillChange.send()
		}
	}
	
	/// Resets options to default
	func resetToDefaults() {
		options = Options.defaultOptions
		saveOptions()
	}
}

// MARK: - Class Options
struct Options: Codable, Equatable {
	/// App name
	var appName: String?
	/// App version
	var appVersion: String?
	/// App bundle identifer
	var appIdentifier: String?
	/// App entitlements
	var appEntitlementsFile: URL?
	/// App apparence (i.e. Light/Dark/Default)
	var appAppearance: String
	/// App minimum iOS requirement (i.e. iOS 11.0)
	var minimumAppRequirement: String
	/// Random string appended to the app identifier
	var ppqString: String
	/// Basic protection against PPQ
	var ppqProtection: Bool
	/// (Better) protection against PPQ
	var dynamicProtection: Bool
	/// App identifiers list which matches and replaces
	var identifiers: [String: String]
	/// App name list which matches and replaces
	var displayNames: [String: String]
	/// Array of files (`.dylib`, `.deb` ) to extract and inject
	var injectionFiles: [URL]
	/// Mach-o load paths to remove (i.e. `@executable_path/demo1.dylib`)
	var disInjectionFiles: [String]
	/// App files to remove from (i.e. `Frameworks/CydiaSubstrate.framework`)
	var removeFiles: [String]
	/// If app should have filesharing forcefully enabled
	var fileSharing: Bool
	/// If app should have iTunes filesharing forcefully enabled
	var itunesFileSharing: Bool
	/// If app should have Pro Motion enabled (may not be needed)
	var proMotion: Bool
	/// If app should have Game Mode enabled
	var gameMode: Bool
	/// If app should use fullscreen (iPad mainly)
	var ipadFullscreen: Bool
	/// If app shouldn't have device restrictions
	var removeSupportedDevices: Bool
	/// If app shouldn't have URL Schemes
	var removeURLScheme: Bool
	/// If app should not include a `embedded.mobileprovision` (useful for JB detection)
	var removeProvisioning: Bool
	/// If app shouldn't include a "Watch Placeholder" (i.e. `Youtube Music` may include a useless app)
	var removeWatchPlaceholder: Bool
	/// Forcefully rename string files for App name
	var changeLanguageFilesForCustomDisplayName: Bool
	/// If app should be Adhoc signed instead of normally signed
	var doAdhocSigning: Bool
	/// If Ksign should remove the app after signed it in the Downloaded Apps options
    var removeApp: Bool
    /// If Ksign should only modify and no signing
    var onlyModify: Bool
	/// If Ksign copy things should start in the last used location instead of Documents dir
	var useLastExportLocation: Bool?
	/// If Ksign should use Zip or ZIPFoundation
	var extractionLibrary: String?
    /// Modifies app to support liquid glass
    var experiment_supportLiquidGlass: Bool
    /// Modifies application to use ElleKit instead of CydiaSubstrate
    var experiment_replaceSubstrateWithEllekit: Bool
    /// If Ksign should use background audio
    var backgroundAudio: Bool
	// default
	static let defaultOptions = Options(
		appAppearance: "Default",
		minimumAppRequirement: "Default",
		ppqString: randomString(),
		ppqProtection: true,
		dynamicProtection: false,
		identifiers: [:],
		displayNames: [:],
		injectionFiles: [],
		disInjectionFiles: [],
		removeFiles: [],
		fileSharing: false,
		itunesFileSharing: false,
		proMotion: false,
		gameMode: false,
		ipadFullscreen: false,
		removeSupportedDevices: true,
		removeURLScheme: false,
		removeProvisioning: true,
		removeWatchPlaceholder: false,
		changeLanguageFilesForCustomDisplayName: false,
		doAdhocSigning: false,
		removeApp: false,
        onlyModify: false,
		useLastExportLocation: false,
		extractionLibrary: "Zip",
        experiment_supportLiquidGlass: false,
        experiment_replaceSubstrateWithEllekit: false,
        backgroundAudio: true
	)
	// extraction library values
	static let extractionLibraryValues = ["Zip", "ZIPFoundation"]
	// duplicate values are not recommended!
	/// Default values for `appAppearance`
	static let appAppearanceValues = ["Default", "Light", "Dark"]
	/// Default values for `minimumAppRequirement`
	static let appMinimumAppRequirementValues = ["Default", "16.0", "15.0", "14.0", "13.0", "12.0"]
	/// Default random value for `ppqString`
	static func randomString() -> String {
		let letters = UUID().uuidString
		return String((0..<6).compactMap { _ in letters.randomElement() })
	}
}
