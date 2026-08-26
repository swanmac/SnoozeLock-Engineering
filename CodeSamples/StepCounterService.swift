//
// StepCounterService.swift
//
// Engineering excerpt from SnoozeLock.
// Demonstrates CoreMotion integration, permission handling,
// asynchronous step updates, and responsive UI polling.
//

import CoreMotion
import Foundation

@Observable
@MainActor
final class StepCounterService {

    enum Status: Equatable {
        case notStarted
        case counting
        case unavailable
        case denied
    }

    var stepCount: Int = 0
    var status: Status = .notStarted

    private let pedometer = CMPedometer()
    private var startDate: Date?
    private var pollingTask: Task<Void, Never>?

    // MARK: - API

    static var isHardwareAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    /// Triggers the Motion & Fitness permission prompt if needed.
    static func requestPermissionIfNeeded() {
        guard isHardwareAvailable else { return }
        guard CMPedometer.authorizationStatus() == .notDetermined else { return }

        let probe = CMPedometer()
        probe.queryPedometerData(from: Date(), to: Date()) { _, _ in }
    }

    func startCounting() {
        guard Self.isHardwareAvailable else {
            status = .unavailable
            return
        }

        let currentAuth = CMPedometer.authorizationStatus()

        if currentAuth == .denied || currentAuth == .restricted {
            status = .denied
            return
        }

        let start = Date()
        startDate = start
        status = .counting

        // Channel 1:
        // CMPedometer updates provide the authoritative OS step count.
        pedometer.startUpdates(from: start) { [weak self] data, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if error != nil {
                    let auth = CMPedometer.authorizationStatus()

                    if auth == .denied || auth == .restricted {
                        self.status = .denied
                        self.pollingTask?.cancel()
                    }

                    return
                }

                let reported = data?.numberOfSteps.intValue ?? 0

                // Never move the displayed count backward.
                if reported > self.stepCount {
                    self.stepCount = reported
                }
            }
        }

        // Channel 2:
        // Poll every 0.5 seconds for smoother real-time UI updates.
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))

                guard !Task.isCancelled else { break }
                self?.pollStepCount()
            }
        }
    }

    func stopCounting() {
        pedometer.stopUpdates()
        pollingTask?.cancel()
        pollingTask = nil
        startDate = nil
    }

    // MARK: - Private

    private func pollStepCount() {
        guard let startDate else { return }

        pedometer.queryPedometerData(
            from: startDate,
            to: Date()
        ) { [weak self] data, error in
            Task { @MainActor [weak self] in
                guard let self, error == nil else { return }

                let polled = data?.numberOfSteps.intValue ?? 0

                if polled > self.stepCount {
                    self.stepCount = polled
                }
            }
        }
    }
}
