import AlarmKit
import Foundation

/// Selected production logic demonstrating AlarmKit authorization
/// and scheduling used by SnoozeLock.
@MainActor
final class AlarmSchedulingService {

    var isAuthorized: Bool {
        AlarmManager.shared.authorizationState == .authorized
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        switch AlarmManager.shared.authorizationState {

        case .authorized:
            return true

        case .denied:
            return false

        case .notDetermined:
            do {
                let state = try await AlarmManager.shared.requestAuthorization()
                return state == .authorized
            } catch {
                return false
            }

        @unknown default:
            return false
        }
    }

    @discardableResult
    func scheduleAlarm(_ alarm: Alarm) async -> Bool {
        guard alarm.isEnabled, isAuthorized else {
            return false
        }

        do {
            let schedule = try makeSchedule(for: alarm)
            let configuration = makeConfiguration(
                for: alarm,
                schedule: schedule
            )

            _ = try await AlarmManager.shared.schedule(
                id: alarm.id,
                configuration: configuration
            )

            return true
        } catch {
            return false
        }
    }

    private func makeSchedule(
        for alarm: Alarm
    ) throws -> AlarmKit.Alarm.Schedule {

        let time = AlarmKit.Alarm.Schedule.Relative.Time(
            hour: alarm.hour,
            minute: alarm.minute
        )

        guard !alarm.repeatDays.isEmpty else {
            return .relative(
                .init(time: time, repeats: .never)
            )
        }

        let weekdays = alarm.repeatDays.compactMap {
            localeWeekday(from: $0)
        }

        guard !weekdays.isEmpty else {
            throw AlarmSchedulingError.missingWeekdays
        }

        return .relative(
            .init(time: time, repeats: .weekly(weekdays))
        )
    }
}
Production excerpt: Simplified from SnoozeLock’s AlarmKit service to demonstrate the authorization and scheduling architecture without publishing the complete application implementation. The production service additionally handles snoozing, alert-state monitoring, cancellation, custom presentation metadata, sound coordination, and user-facing recovery states.
