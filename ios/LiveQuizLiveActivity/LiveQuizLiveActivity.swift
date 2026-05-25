import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MegaPromoLiveActivitiesBundle: WidgetBundle {
  var body: some Widget {
    LiveQuizLiveActivity()
  }
}

struct LiveQuizLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveQuizActivityAttributes.self) { context in
      LiveQuizLockScreenView(context: context)
        .activityBackgroundTint(Color.black.opacity(0.82))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 8) {
            MegaPromoLogo(size: 30)
            Text("MegaPromo")
              .font(.caption.weight(.semibold))
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 4) {
            Text(context.state.startsAt, style: .timer)
              .font(.title3.monospacedDigit().weight(.bold))
            Text("avant départ")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.7))
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 8) {
            Text(context.attributes.title)
              .font(.footnote.weight(.semibold))
              .lineLimit(1)
            Spacer(minLength: 6)
            HStack(spacing: 6) {
              Image(systemName: "person.2.fill")
              Text("\(context.state.registeredCount)")
              Text("·")
                .foregroundStyle(.white.opacity(0.42))
              Image(systemName: "gamecontroller.fill")
              Text("\(context.state.connectedCount)")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
          }
        }
      } compactLeading: {
        MegaPromoLogo(size: 22)
      } compactTrailing: {
        Text(context.state.startsAt, style: .timer)
          .font(.caption2.monospacedDigit().weight(.bold))
      } minimal: {
        MegaPromoLogo(size: 20)
      }
      .keylineTint(Color(red: 0.72, green: 0.62, blue: 1.0))
    }
  }
}

private struct LiveQuizLockScreenView: View {
  let context: ActivityViewContext<LiveQuizActivityAttributes>

  var body: some View {
    HStack(spacing: 14) {
      MegaPromoLogo(size: 50)

      VStack(alignment: .leading, spacing: 5) {
        Text("MegaPromo")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.64))
        Text(context.attributes.title)
          .font(.headline.weight(.bold))
          .foregroundStyle(.white)
          .lineLimit(1)
        Text(context.attributes.prizeLabel)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color(red: 0.86, green: 0.78, blue: 1.0))
          .lineLimit(1)
        HStack(spacing: 8) {
          HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
            Text("\(context.state.registeredCount)")
          }
          Text("·")
            .foregroundStyle(.white.opacity(0.42))
          HStack(spacing: 4) {
            Image(systemName: "gamecontroller.fill")
            Text("\(context.state.connectedCount)")
          }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.white.opacity(0.68))
      }

      Spacer(minLength: 8)

      VStack(alignment: .trailing, spacing: 4) {
        Text(context.state.startsAt, style: .timer)
          .font(.title3.monospacedDigit().weight(.bold))
          .foregroundStyle(.white)
        Text("départ")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.white.opacity(0.62))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

private struct MegaPromoLogo: View {
  let size: CGFloat

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        .fill(Color.white)
      Image("MegaPromoLogo")
        .resizable()
        .scaledToFit()
        .padding(size * 0.08)
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        .stroke(Color.white.opacity(0.22), lineWidth: 1)
    )
  }
}
