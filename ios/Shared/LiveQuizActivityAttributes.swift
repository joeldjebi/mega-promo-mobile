import ActivityKit
import Foundation

struct LiveQuizActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var status: String
    var startsAt: Date
    var registeredCount: Int
    var connectedCount: Int
  }

  var contestId: String
  var title: String
  var prizeLabel: String
}
