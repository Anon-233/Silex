import Foundation
import Testing
@testable import SilexCore

struct SchedulerTests {
    @Test
    func calculatesNextDateFromRealLastCollectionTime() {
        let now = Date(timeIntervalSince1970: 100_000)

        #expect(
            CollectionScheduler.nextCollectionDate(
                lastCollectedAt: nil,
                intervalHours: 8,
                now: now
            ) == now
        )
        #expect(
            CollectionScheduler.nextCollectionDate(
                lastCollectedAt: now.addingTimeInterval(-2 * 3_600),
                intervalHours: 8,
                now: now
            ) == now.addingTimeInterval(6 * 3_600)
        )
        #expect(
            CollectionScheduler.nextCollectionDate(
                lastCollectedAt: now.addingTimeInterval(-10 * 3_600),
                intervalHours: 8,
                now: now
            ) == now
        )
    }

    @Test
    func schedulingAgainCancelsThePreviousTimer() {
        let clock = RecordingOneShotScheduler()
        let scheduler = CollectionScheduler(scheduler: clock)
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)

        scheduler.schedule(at: firstDate) {}
        scheduler.schedule(at: secondDate) {}

        #expect(clock.tokens.count == 2)
        #expect(clock.tokens[0].cancelCalls == 1)
        #expect(clock.tokens[1].cancelCalls == 0)
        #expect(clock.dates == [firstDate, secondDate])
    }
}

private final class RecordingOneShotScheduler: OneShotScheduling, @unchecked Sendable {
    private(set) var dates: [Date] = []
    private(set) var tokens: [RecordingCancellation] = []

    func schedule(at date: Date, action: @escaping @Sendable () -> Void) -> any Cancellation {
        let token = RecordingCancellation()
        dates.append(date)
        tokens.append(token)
        return token
    }
}

private final class RecordingCancellation: Cancellation, @unchecked Sendable {
    private(set) var cancelCalls = 0

    func cancel() {
        cancelCalls += 1
    }
}

