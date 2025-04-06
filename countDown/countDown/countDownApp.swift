//
//  countDownApp.swift
//  countDown
//
//  Created by 遠藤拓弥 on 2025/04/06.
//

import SwiftUI
import ComposableArchitecture

@main
struct countDownApp: App {
    var body: some Scene {
        WindowGroup {
            CountdownListView(
                store: Store(initialState: CountdownFeature.State()) {
                    CountdownFeature()
                }
            )
        }
    }
}
