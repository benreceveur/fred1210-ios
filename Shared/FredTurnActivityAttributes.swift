#if canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct FredTurnActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var currentTool: String?
        var toolCount: Int
        var elapsedSec: Int
    }

    var prompt: String
    var turnId: String
}
#endif
