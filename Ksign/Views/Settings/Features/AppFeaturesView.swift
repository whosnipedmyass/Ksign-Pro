//
//  AppFeaturesView.swift
//  Ksign
//
//  Created by Nagata Asami on 10/10/25.
//

import SwiftUI
import NimbleViews

struct AppFeaturesView: View {
    @StateObject private var _optionsManager = OptionsManager.shared
    
    var body: some View {
        NBList(.localized("App Features")) {
            Section {
                Toggle(isOn: $_optionsManager.options.backgroundAudio) {
                    Label(.localized("Keep app running in background"), systemImage: "arrow.trianglehead.2.clockwise")
                }
            } footer: {
                Text(.localized("This will keep the app running even when you close it, helpful with download or installing ipa."))
            }
        }
    }
}
