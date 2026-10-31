import SwiftUI

public extension View {
    @ViewBuilder
    func navigationTitleModeLarge() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    @ViewBuilder
    func navigationTitleModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

public extension ToolbarItemPlacement {
    static var trailingAction: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .primaryAction
        #endif
    }
}
