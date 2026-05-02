import WidgetKit
import SwiftUI

@main
struct DayflowWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayflowPlanWidget()
        DayflowShiftWidget()
    }
}
