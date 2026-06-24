import Foundation

public struct SettingsRepository: Sendable {
    private static let key = "app"

    private let database: Database
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(database: Database) {
        self.database = database
    }

    public func save(_ settings: AppSettings) throws {
        let payload = try encoder.encode(settings)
        try database.execute(
            """
            INSERT INTO settings(key, payload) VALUES (?, ?)
            ON CONFLICT(key) DO UPDATE SET payload = excluded.payload
            """,
            bindings: [.text(Self.key), .blob(payload)]
        )
    }

    public func load() throws -> AppSettings {
        let rows = try database.query(
            "SELECT payload FROM settings WHERE key = ?",
            bindings: [.text(Self.key)]
        )
        guard let payload = rows.first?["payload"]?.blob else {
            return AppSettings()
        }
        do {
            return try decoder.decode(AppSettings.self, from: payload)
        } catch {
            throw DatabaseError.decode(error.localizedDescription)
        }
    }
}

