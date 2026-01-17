//
//  countDownWidgetsBundle.swift
//  countDownWidgets
//
//  Created by 遠藤拓弥 on 2026/01/17.
//

import WidgetKit
import SwiftUI

@main
struct countDownWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
        if #available(iOSApplicationExtension 16.0, *) {
            CountdownLockScreenWidget()
        }
        countDownWidgetsLiveActivity()
    }
}
