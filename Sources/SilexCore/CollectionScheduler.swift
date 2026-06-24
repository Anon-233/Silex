import Foundation

public struct CollectionSchedulePlan: Equatable, Sendable {
    public let scheduledAt: Date
    public let isDueNow: Bool

    public init(scheduledAt: Date, isDueNow: Bool) {
        self.scheduledAt = scheduledAt
        self.isDueNow = isDueNow
    }
}

public enum CollectionSchedulePlanner {
    public static let minimumIntervalHours: Double = 0.25

    public static func normalizedIntervalHours(_ intervalHours: Double) -> Double {
        guard intervalHours.isFinite else {
            return 8
        }
        return max(intervalHours, minimumIntervalHours)
    }

    public static func plan(
        lastCollectedAt: Date?,
        intervalHours: Double,
        now: Date
    ) -> CollectionSchedulePlan {
        guard let lastCollectedAt else {
            return CollectionSchedulePlan(scheduledAt: now, isDueNow: true)
        }

        let candidate = lastCollectedAt.addingTimeInterval(
            normalizedIntervalHours(intervalHours) * 3_600
        )
        if candidate <= now {
            return CollectionSchedulePlan(scheduledAt: now, isDueNow: true)
        }
        return CollectionSchedulePlan(scheduledAt: candidate, isDueNow: false)
    }
}

public protocol Cancellation: Sendable {
    func cancel()
}

public protocol OneShotScheduling: Sendable {
    func schedule(
        at date: Date,
        action: @escaping @Sendable () -> Void
    ) -> any Cancellation
}

public final class CollectionScheduler: @unchecked Sendable {
    private let scheduler: any OneShotScheduling
    private let lock = NSLock()
    private var cancellation: (any Cancellation)?

    public init(scheduler: any OneShotScheduling = DispatchOneShotScheduler()) {
        self.scheduler = scheduler
    }

    deinit {
        cancellation?.cancel()
    }

    public func schedule(
        at date: Date,
        action: @escaping @Sendable () -> Void
    ) {
        lock.withLock {
            cancellation?.cancel()
            cancellation = scheduler.schedule(at: date, action: action)
        }
    }

    public func cancel() {
        lock.withLock {
            cancellation?.cancel()
            cancellation = nil
        }
    }

    public static func nextCollectionDate(
        lastCollectedAt: Date?,
        intervalHours: Double,
        now: Date
    ) -> Date {
        CollectionSchedulePlanner.plan(
            lastCollectedAt: lastCollectedAt,
            intervalHours: intervalHours,
            now: now
        ).scheduledAt
    }
}

public struct DispatchOneShotScheduler: OneShotScheduling {
    public init() {}

    public func schedule(
        at date: Date,
        action: @escaping @Sendable () -> Void
    ) -> any Cancellation {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + max(date.timeIntervalSinceNow, 0))
        source.setEventHandler(handler: action)
        source.resume()
        return DispatchTimerCancellation(source: source)
    }
}

private final class DispatchTimerCancellation: Cancellation, @unchecked Sendable {
    private let source: DispatchSourceTimer
    private let lock = NSLock()
    private var isCancelled = false

    init(source: DispatchSourceTimer) {
        self.source = source
    }

    func cancel() {
        lock.withLock {
            guard !isCancelled else {
                return
            }
            isCancelled = true
            source.setEventHandler {}
            source.cancel()
        }
    }
}
