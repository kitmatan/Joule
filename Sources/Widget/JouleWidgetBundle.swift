import WidgetKit
import SwiftUI

@main
struct JouleWidgetBundle: WidgetBundle {
    var body: some Widget {
        JouleOverviewWidget()
        JouleBatteryWidget()
    }
}
