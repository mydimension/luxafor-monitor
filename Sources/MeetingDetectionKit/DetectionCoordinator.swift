import Combine
import Foundation

/// Polls a set of `MeetingDetector`s on a timer, merges their readings into
/// a single per-app view, fuses that into one overall `MeetingStatus`, and
/// debounces the published fused status so a single noisy/transient reading
/// doesn't cause visible flicker (e.g. in a menu bar icon or a physical
/// light).
@MainActor
public final class DetectionCoordinator: ObservableObject {
    /// The debounced, fused meeting status. Only changes after the
    /// underlying fused value has been the same for `requiredStableReadings`
    /// consecutive polls.
    @Published public private(set) var fusedStatus: MeetingStatus = .unknown

    /// The most recent reading for each app identifier, updated immediately
    /// on every poll (not debounced) — intended for UI display of raw
    /// per-app detector state.
    @Published public private(set) var latestReadings: [String: DetectorReading] = [:]

    private let detectors: [MeetingDetector]
    private let pollInterval: TimeInterval
    private let requiredStableReadings: Int

    private var timer: Timer?

    /// The instantaneous fused candidate computed on the most recent poll,
    /// and how many consecutive polls in a row have produced that same
    /// candidate. Used to implement the debounce.
    private var pendingCandidate: MeetingStatus?
    private var pendingCandidateStreak: Int = 0

    public init(detectors: [MeetingDetector], pollInterval: TimeInterval = 3.0, requiredStableReadings: Int = 2) {
        self.detectors = detectors
        self.pollInterval = pollInterval
        self.requiredStableReadings = max(1, requiredStableReadings)
    }

    /// Starts polling immediately (an initial `refreshNow()` runs
    /// synchronously) and then every `pollInterval` seconds thereafter.
    /// Calling `start()` again while already running restarts the timer.
    public func start() {
        stop()
        refreshNow()

        let newTimer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshNow()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    /// Stops polling. Safe to call even if not started / already stopped.
    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Synchronously polls every detector once, updates `latestReadings`
    /// immediately, and feeds the resulting fused candidate into the
    /// debounce logic that gates `fusedStatus`. Exposed publicly so callers
    /// (including tests) can drive polling deterministically without
    /// waiting on the timer.
    public func refreshNow() {
        var merged: [String: DetectorReading] = [:]
        for detector in detectors {
            for reading in detector.currentReadings() {
                if let existing = merged[reading.appIdentifier] {
                    merged[reading.appIdentifier] = Self.resolveConflict(existing: existing, new: reading)
                } else {
                    merged[reading.appIdentifier] = reading
                }
            }
        }
        latestReadings = merged

        let candidate = Self.fuse(merged)
        if candidate == pendingCandidate {
            pendingCandidateStreak += 1
        } else {
            pendingCandidate = candidate
            pendingCandidateStreak = 1
        }

        if pendingCandidateStreak >= requiredStableReadings {
            fusedStatus = candidate
        }
    }

    // MARK: - Fusion helpers

    /// When two detectors report a reading for the same `appIdentifier` in
    /// the same poll, prefer whichever is non-`.unknown`; if both (or
    /// neither) are `.unknown`, prefer the higher-confidence reading; on an
    /// exact tie, the later detector's reading wins.
    private static func resolveConflict(existing: DetectorReading, new: DetectorReading) -> DetectorReading {
        if existing.status == .unknown && new.status != .unknown {
            return new
        }
        if new.status == .unknown && existing.status != .unknown {
            return existing
        }
        if new.confidence > existing.confidence {
            return new
        }
        if new.confidence < existing.confidence {
            return existing
        }
        return new
    }

    /// `.inMeeting` if any reading is `.inMeeting`; else `.notInMeeting` if
    /// there's at least one reading; else `.unknown` if there are none.
    private static func fuse(_ readings: [String: DetectorReading]) -> MeetingStatus {
        guard !readings.isEmpty else { return .unknown }
        if readings.values.contains(where: { $0.status == .inMeeting }) {
            return .inMeeting
        }
        return .notInMeeting
    }
}
