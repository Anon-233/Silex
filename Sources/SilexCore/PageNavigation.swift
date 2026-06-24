import Foundation

public enum PageDirection: Sendable {
    case previous
    case next
}

public struct PageNavigationState: Equatable, Sendable {
    public private(set) var page: Int
    public let pageCount: Int

    public init(page: Int, pageCount: Int) {
        self.pageCount = max(pageCount, 1)
        self.page = min(max(page, 0), max(pageCount - 1, 0))
    }

    public mutating func go(to target: Int) {
        page = min(max(target, 0), pageCount - 1)
    }

    public mutating func move(
        _ direction: PageDirection,
        isBlocked: Bool
    ) {
        guard !isBlocked else {
            return
        }
        go(to: page + (direction == .next ? 1 : -1))
    }

    @discardableResult
    public mutating func finishDrag(
        width: Double,
        height: Double,
        isBlocked: Bool
    ) -> Int {
        guard
            !isBlocked,
            abs(width) >= 60,
            abs(width) > abs(height) * 1.25
        else {
            return page
        }
        move(width < 0 ? .next : .previous, isBlocked: false)
        return page
    }
}
