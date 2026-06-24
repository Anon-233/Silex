import Foundation

public struct RuleRepository: Sendable {
    private let database: Database
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(database: Database) {
        self.database = database
    }

    public func save(_ rule: AlertRule) throws {
        let payload = try encoder.encode(rule)
        try database.execute(
            """
            INSERT INTO rules(id, payload) VALUES (?, ?)
            ON CONFLICT(id) DO UPDATE SET payload = excluded.payload
            """,
            bindings: [.text(rule.id.uuidString), .blob(payload)]
        )
    }

    public func all() throws -> [AlertRule] {
        try database.query("SELECT payload FROM rules ORDER BY rowid ASC").map { row in
            guard let payload = row["payload"]?.blob else {
                throw DatabaseError.decode("Missing rule payload.")
            }
            do {
                return try decoder.decode(AlertRule.self, from: payload)
            } catch {
                throw DatabaseError.decode(error.localizedDescription)
            }
        }
    }

    public func delete(id: UUID) throws {
        try database.execute(
            "DELETE FROM rules WHERE id = ?",
            bindings: [.text(id.uuidString)]
        )
    }
}

