//
//  BulkSigningView.swift
//  Ksign
//
//  Created by Nagata Asami on 11/9/25.
//

import SwiftUI
import NimbleViews
import PhotosUI

struct BulkSigningView: View {
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		return certificates[_temporaryCertificate]
	}
	
	@StateObject private var _optionsManager = OptionsManager.shared
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State var appIcon: UIImage?
	@State private var _selectedAppForIcon: AnyApp?
	
	@Environment(\.dismiss) private var dismiss
	var apps: [AppInfoPresentable]

	init(apps: [AppInfoPresentable]) {
		self.apps = apps
		let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
	}

	var body: some View {
		NBNavigationView(.localized("Bulk Signing"), displayMode: .inline) {
			Form {
                _cert()
				
				ForEach(apps, id: \.uuid) { app in
					Section {
						_customizationOptions(for: app)
						_customizationProperties(for: app)
					}
				}
			}
			.safeAreaInset(edge: .bottom) {
				Button {
					_start()
				} label: {
					NBSheetButton(title: .localized("Start Signing"))
				}
			}
			.toolbar {
				NBToolbarButton(role: .dismiss)
				
				NBToolbarButton(
					.localized("Reset"),
					style: .text,
					placement: .topBarTrailing
				) {
					_temporaryOptions = OptionsManager.shared.options
					appIcon = nil
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) {
				if let selected = _selectedAppForIcon {
					SigningAlternativeIconView(app: selected.base, appIcon: $appIcon, isModifing: .constant(true))
				}
			}
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self.appIcon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.onChange(of: _selectedPhoto) { newValue in
				guard let newValue else { return }
				
				Task {
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						appIcon = image
					}
				}
			}
			.disabled(_isSigning)
			.animation(.smooth, value: _isSigning)
		}
	}
}

extension BulkSigningView {
	@ViewBuilder
	private func _customizationOptions(for app: AppInfoPresentable) -> some View {
			Menu {
				Button(.localized("Select Alternative Icon")) { _isAltPickerPresenting = true }
				Button(.localized("Choose from Files")) { _isFilePickerPresenting = true }
				Button(.localized("Choose from Photos")) { _isImagePickerPresenting = true }
			} label: {
				FRAppIconView(app: app, size: 55)
			}
			_infoCell(.localized("Name"), desc: _temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: .localized("Name"),
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
			_infoCell(.localized("Identifier"), desc: _temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: .localized("Identifier"),
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
			_infoCell(.localized("Version"), desc: _temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: .localized("Version"),
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
	}
	

	@ViewBuilder
	private func _cert() -> some View {
		NBSection(.localized("Signing")) {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			}
		}
	}
	
	@ViewBuilder
	private func _customizationProperties(for app: AppInfoPresentable) -> some View {
			DisclosureGroup(.localized("Modify")) {
				NavigationLink(.localized("Existing Dylibs")) {
					SigningDylibView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				
				NavigationLink(String.localized("Frameworks & PlugIns")) {
					SigningFrameworksView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				#if NIGHTLY || DEBUG
				NavigationLink(String.localized("Entitlements")) {
					SigningEntitlementsView(
						bindingValue: $_temporaryOptions.appEntitlementsFile
					)
				}
				#endif
				NavigationLink(String.localized("Tweaks")) {
					SigningTweaksView(
						options: $_temporaryOptions
					)
				}
			}
			
			NavigationLink(String.localized("Properties")) {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
			.navigationTitle(.localized("Properties"))
		}
	}

	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			LabeledContent(title) {
				Text(desc ?? .localized("Unknown"))
			}
		}
	}

	private func _start() {
		guard _selectedCert() != nil || _temporaryOptions.doAdhocSigning || _temporaryOptions.onlyModify else {
			UIAlertController.showAlertWithOk(
				title: .localized("No Certificate"),
				message: .localized("Please go to settings and import a valid certificate"),
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		_isSigning = true

		
		for app in apps {
			FR.signPackageFile(
				app,
				using: _temporaryOptions,
				icon: appIcon,
				certificate: _selectedCert()
			) { [self] error in
				if let error {
					UIAlertController.showAlertWithOk(title: "Error", message: error.localizedDescription)
				}
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
					NotificationCenter.default.post(name: NSNotification.Name("ksign.bulkSigningFinished"), object: nil)
				}
				dismiss()
			}
		}

	}
}
