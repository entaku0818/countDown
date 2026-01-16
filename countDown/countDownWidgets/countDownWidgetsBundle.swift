import WidgetKit
import SwiftUI

@main
struct countDownWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()

        // ロック画面用ウィジェット
        if #available(iOSApplicationExtension 16.0, *) {
            CountdownLockScreenWidget()
        }
    }
}
