import Foundation

public struct SampleRepository: Sendable {
    private let database: Database
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(database: Database) {
        self.database = database
    }

    public func insert(_ sample: DriveSample) throws {
        let payload = try encoder.encode(sample)
        try database.execute(
            """
            INSERT OR REPLACE INTO samples(id, collected_at, payload)
            VALUES (?, ?, ?)
            """,
            bindings: [
                .text(sample.id.uuidString),
                .real(sample.collectedAt.timeIntervalSince1970),
                .blob(payload)
            ]
        )
    }

    public func all() throws -> [DriveSample] {
        try decode(
            database.query(
                "SELECT payload FROM samples ORDER BY collected_at ASC"
            )
        )
    }

    public func samples(since date: Date) throws -> [DriveSample] {
        try decode(
            database.query(
                """
                SELECT payload FROM samples
                WHERE collected_at >= ?
                ORDER BY collected_at ASC
                """,
                bindings: [.real(date.timeIntervalSince1970)]
            )
        )
    }

    public func latest() throws -> DriveSample? {
        try decode(
            database.query(
                "SELECT payload FROM samples ORDER BY collected_at DESC LIMIT 1"
            )
        ).first
    }

    public func deleteAll() throws {
        try database.execute("DELETE FROM samples")
    }

    private func decode(_ rows: [SQLiteRow]) throws -> [DriveSample] {
        try rows.map { row in
            guard let payload = row["payload"]?.blob else {
                throw DatabaseError.decode("Missing sample payload.")
            }
            do {
                return try decoder.decode(DriveSample.self, from: payload)
            } catch {
                throw DatabaseError.decode(error.localizedDescription)
            }
        }
    }
}

