//
//  LogsView.swift
//  Ksign
//
//  Created by Nagata Asami on 7/10/25.
//

import SwiftUI

struct LogsView: View {
	@ObservedObject var manager: LogsManager

	private var _lastId: LogEntry.ID? { manager.entries.last?.id }

	var body: some View {
		NavigationStack {
			ScrollViewReader { proxy in
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 0) {
						ForEach(manager.entries) { entry in
							Text(entry.message)
								.font(.system(size: 12, weight: .regular, design: .monospaced))
								.textSelection(.enabled)
								.frame(maxWidth: .infinity, alignment: .leading)
								.padding(.horizontal)
								.padding(.vertical, 1)
								.id(entry.id)
						}
					}
				}
				.onAppear { if let id = _lastId { proxy.scrollTo(id, anchor: .bottom) } }
				.onChange(of: manager.entries.count) { _ in
					if let id = _lastId { proxy.scrollTo(id, anchor: .bottom) }
				}
			}
			.toolbar {
				ToolbarItemGroup(placement: .navigationBarTrailing) {
					Button { manager.clear() } label: { Image(systemName: "trash") }
					Button {
						if manager.isCapturing { manager.stopCapture() } else { manager.startCapture() }
					} label: {
						Image(systemName: manager.isCapturing ? "pause.circle" : "play.circle")
					}
				}
			}
		}
	}
}


