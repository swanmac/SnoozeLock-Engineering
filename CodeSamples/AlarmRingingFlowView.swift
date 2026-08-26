//
//  AlarmRingingFlowView.swift
//  SnoozeLock
//
//  Engineering showcase excerpt.
//
//  Coordinates the alarm ringing workflow and sequential wake challenges.
//  The production implementation also handles additional alarm lifecycle,
//  analytics, notification, and presentation details.
//

import SwiftUI

struct AlarmRingingFlowView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(AlarmStatsService.self) private var stats

    /// Index into the active challenge stack.
    /// Resets when a new alarm workflow begins.
    @State private var challengeIndex: Int = 0

    var body: some View {
        @Bindable var appState = appState

        Group {
            if let alarm = activeAlarm {
                switch appState.ringingPhase {

                case .missionBriefing:
                    MissionBriefingView(alarm: alarm) {
                        appState.acceptMission()
                    }

                case .ringing:
                    AlarmRingingView(
                        alarm: alarm,
                        onSnooze: {
                            appState.requestDismiss(action: .snooze)
                        },
                        onTurnOff: {
                            challengeIndex = 0
                            appState.requestDismiss(action: .turnOff)
                        }
                    )

                case .challenge:
                    challengeView(for: alarm)

                case .missionSuccess:
                    MissionSuccessView(missionTitle: alarm.missionTitle) {
                        Task {
                            await finishAfterSuccess(alarm: alarm)
                        }
                    }
                }
            } else {
                AlarmRingingPlaceholderView()
            }
        }
        .onChange(of: appState.ringingPhase) { _, newPhase in
            if newPhase == .ringing {
                challengeIndex = 0
            }
        }
    }

    // MARK: - Challenge routing

    @ViewBuilder
    private func challengeView(for alarm: Alarm) -> some View {
        let steps = AlarmHelpers.activeChallenges(for: alarm)
        let index = min(challengeIndex, steps.count - 1)

        if steps.isEmpty {
            EmptyView()
        } else {
            WakeChallengeView(
                step: steps[index],
                stepNumber: index + 1,
                totalSteps: steps.count
            ) {
                Task {
                    await advanceOrComplete(alarm: alarm, steps: steps)
                }
            }
            .id(index)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing)
                        .combined(with: .opacity),
                    removal: .move(edge: .leading)
                        .combined(with: .opacity)
                )
            )
            .animation(
                .easeInOut(duration: 0.35),
                value: challengeIndex
            )
        }
    }

    private func advanceOrComplete(
        alarm: Alarm,
        steps: [ChallengeStep]
    ) async {
        let completedStep =
            steps[min(challengeIndex, steps.count - 1)]

        AnalyticsService.shared
            .trackChallengeCompleted(type: completedStep.type)

        let next = challengeIndex + 1

        if next < steps.count {
            withAnimation {
                challengeIndex = next
            }
        } else {
            await handleChallengeComplete(alarm: alarm)
        }
    }

    private func handleChallengeComplete(alarm: Alarm) async {
        if AlarmHelpers.hasMissionRecall(for: alarm) {
            appState.showMissionSuccess()
        } else {
            await executeDismissAction(alarm: alarm)
            appState.clearRingingState()
        }
    }

    private var activeAlarm: Alarm? {
        let id =
            appState.ringingAlarmID ??
            appState.launchPendingAlarmID

        guard let id else { return nil }

        return store.alarm(with: id)
    }
}
