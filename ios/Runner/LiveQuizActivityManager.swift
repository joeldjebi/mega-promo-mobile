import ActivityKit
import Foundation

@available(iOS 16.2, *)
enum LiveQuizActivityManager {
  static func startOrUpdateWaiting(
    contestId: String,
    title: String,
    prizeLabel: String,
    startsAt: Date,
    registeredCount: Int,
    connectedCount: Int
  ) async throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw LiveQuizActivityError.disabled
    }

    let state = LiveQuizActivityAttributes.ContentState(
      status: "Salle d'attente",
      startsAt: startsAt,
      registeredCount: registeredCount,
      connectedCount: connectedCount
    )

    if let activity = activity(for: contestId) {
      await activity.update(
        ActivityContent(
          state: state,
          staleDate: startsAt.addingTimeInterval(60 * 60)
        )
      )
      return
    }

    let attributes = LiveQuizActivityAttributes(
      contestId: contestId,
      title: title,
      prizeLabel: prizeLabel
    )

    _ = try Activity<LiveQuizActivityAttributes>.request(
      attributes: attributes,
      content: ActivityContent(
        state: state,
        staleDate: startsAt.addingTimeInterval(60 * 60)
      ),
      pushType: nil
    )
  }

  static func end(contestId: String) async {
    guard let activity = activity(for: contestId) else { return }
    await activity.end(nil, dismissalPolicy: .immediate)
  }

  private static func activity(
    for contestId: String
  ) -> Activity<LiveQuizActivityAttributes>? {
    Activity<LiveQuizActivityAttributes>.activities.first {
      $0.attributes.contestId == contestId
    }
  }
}

enum LiveQuizActivityError: LocalizedError {
  case disabled

  var errorDescription: String? {
    switch self {
    case .disabled:
      return "Live Activities disabled for this device."
    }
  }
}
