import Foundation
import Testing
@testable import SilexCore

struct HistoryAnalyzerTests {
    private let analyzer = HistoryAnalyzer()

    @Test
    func filtersRangesByTimestampInsteadOfPointCount() {
        let now = Date(timeIntervalSince1970: 4_000_000)
        let samples = [
            makeSample(date: now.addingTimeInterval(-40 * 86_400)),
            makeSample(date: now.addingTimeInterval(-10 * 86_400)),
            makeSample(date: now.addingTimeInterval(-23 * 3_600)),
            makeSample(date: now.addingTimeInterval(-1 * 3_600))
        ]

        #expect(analyzer.filtered(samples, range: .hours24, now: now).count == 2)
        #expect(analyzer.filtered(samples, range: .days30, now: now).count == 3)
        #expect(analyzer.filtered(samples, range: .all, now: now).count == 4)
    }

    @Test
    func preservesAOnePointRange() {
        let now = Date(timeIntervalSince1970: 4_000_000)
        let sample = makeSample(date: now.addingTimeInterval(-60))

        #expect(analyzer.filtered([sample], range: .hours24, now: now) == [sample])
    }

    @Test
    func calculatesRatesUsingActualElapsedHours() {
        let start = Date(timeIntervalSince1970: 1_000)
        let samples = [
            makeSample(date: start, writtenBytes: 2_000_000_000),
            makeSample(
                date: start.addingTimeInterval(2.5 * 3_600),
                writtenBytes: 7_000_000_000
            )
        ]

        let statistics = analyzer.statistics(for: .dataWritten, samples: samples)

        #expect(statistics.latest == 7)
        #expect(statistics.recentChange == 5)
        #expect(statistics.recentRatePerHour == 2)
        #expect(statistics.averageRatePerHour == 2)
    }

    @Test
    func computesMetricSpecificStatisticsFromValidValues() {
        let start = Date(timeIntervalSince1970: 1_000)
        let samples = [
            makeSample(date: start, temperature: 20),
            makeSample(date: start.addingTimeInterval(3_600), temperature: 30),
            makeSample(date: start.addingTimeInterval(7_200), temperature: 40)
        ]

        let statistics = analyzer.statistics(for: .temperature, samples: samples)

        #expect(statistics.latest == 40)
        #expect(statistics.minimum == 20)
        #expect(statistics.maximum == 40)
        #expect(statistics.average == 30)
        #expect(statistics.recentChange == 10)
        #expect(statistics.recentRatePerHour == 10)
        #expect(statistics.averageRatePerHour == 10)
    }

    @Test
    func returnsNoRateForOneValidSample() {
        let sample = makeSample(date: Date(timeIntervalSince1970: 1_000))

        let statistics = analyzer.statistics(for: .temperature, samples: [sample])

        #expect(statistics.latest == 30)
        #expect(statistics.recentRatePerHour == nil)
        #expect(statistics.averageRatePerHour == nil)
    }
}

