import Flutter
import Foundation

final class LiveQuizActivityBridge {
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startOrUpdateWaiting":
      guard let arguments = call.arguments as? [String: Any],
            let contestId = arguments["contestId"] as? String,
            let title = arguments["title"] as? String,
            let startsAtMillis = arguments["startsAtMillis"] as? NSNumber else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Parametres Live Activity invalides.",
            details: nil
          )
        )
        return
      }

      let startsAt = Date(timeIntervalSince1970: startsAtMillis.doubleValue / 1000)
      let prizeLabel = arguments["prizeLabel"] as? String ?? "Gain surprise"
      let registeredCount = (arguments["registeredCount"] as? NSNumber)?.intValue ?? 0
      let connectedCount = (arguments["connectedCount"] as? NSNumber)?.intValue ?? 0

      Task {
        do {
          if #available(iOS 16.2, *) {
            try await LiveQuizActivityManager.startOrUpdateWaiting(
              contestId: contestId,
              title: title,
              prizeLabel: prizeLabel,
              startsAt: startsAt,
              registeredCount: registeredCount,
              connectedCount: connectedCount
            )
            result(nil)
          } else {
            result(
              FlutterError(
                code: "live_activity_unavailable",
                message: "Live Activities requires iOS 16.2 or later.",
                details: nil
              )
            )
          }
        } catch {
          result(
            FlutterError(
              code: "live_activity_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }

    case "end":
      guard let arguments = call.arguments as? [String: Any],
            let contestId = arguments["contestId"] as? String else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Contest id manquant.",
            details: nil
          )
        )
        return
      }

      Task {
        if #available(iOS 16.2, *) {
          await LiveQuizActivityManager.end(contestId: contestId)
        }
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
