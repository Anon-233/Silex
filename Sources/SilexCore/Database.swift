import CSQLite
import Foundation

public enum DatabaseError: Error, Equatable, LocalizedError {
    case open(String)
    case prepare(String)
    case bind(String)
    case step(String)
    case decode(String)

    public var errorDescription: String? {
        switch self {
        case let .open(message):
            "Unable to open database: \(message)"
        case let .prepare(message):
            "Unable to prepare database statement: \(message)"
        case let .bind(message):
            "Unable to bind database value: \(message)"
        case let .step(message):
            "Unable to execute database statement: \(message)"
        case let .decode(message):
            "Unable to decode database value: \(message)"
        }
    }
}

public final class Database: @unchecked Sendable {
    private let connection: OpaquePointer
    private let lock = NSLock()

    public init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var handle: OpaquePointer?
        let status = sqlite3_open_v2(
            url.path,
            &handle,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard status == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            if let handle {
                sqlite3_close(handle)
            }
            throw DatabaseError.open(message)
        }

        connection = handle
        do {
            try Self.execute(connection, sql: "PRAGMA journal_mode = WAL")
            try Self.execute(connection, sql: "PRAGMA foreign_keys = ON")
            try Self.execute(connection, sql: "PRAGMA busy_timeout = 5000")
            try Self.migrate(connection)
        } catch {
            sqlite3_close(connection)
            throw error
        }
    }

    deinit {
        sqlite3_close(connection)
    }

    public func schemaVersion() throws -> Int {
        try lock.withLock {
            let rows = try Self.query(
                connection,
                sql: "SELECT COALESCE(MAX(version), 0) AS version FROM schema_migrations"
            )
            return Int(rows.first?["version"]?.integer ?? 0)
        }
    }

    func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        try lock.withLock {
            try Self.execute(connection, sql: sql, bindings: bindings)
        }
    }

    func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        try lock.withLock {
            try Self.query(connection, sql: sql, bindings: bindings)
        }
    }

    func transaction<T>(_ body: () throws -> T) throws -> T {
        try lock.withLock {
            try Self.execute(connection, sql: "BEGIN IMMEDIATE")
            do {
                let value = try body()
                try Self.execute(connection, sql: "COMMIT")
                return value
            } catch {
                try? Self.execute(connection, sql: "ROLLBACK")
                throw error
            }
        }
    }

    private static func migrate(_ connection: OpaquePointer) throws {
        try execute(
            connection,
            sql: """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY
            )
            """
        )

        let rows = try query(
            connection,
            sql: "SELECT COALESCE(MAX(version), 0) AS version FROM schema_migrations"
        )
        let current = rows.first?["version"]?.integer ?? 0
        guard current < 1 else {
            return
        }

        try execute(connection, sql: "BEGIN IMMEDIATE")
        do {
            try execute(
                connection,
                sql: """
                CREATE TABLE samples (
                    id TEXT PRIMARY KEY,
                    collected_at REAL NOT NULL,
                    payload BLOB NOT NULL
                )
                """
            )
            try execute(
                connection,
                sql: "CREATE INDEX samples_collected_at ON samples(collected_at)"
            )
            try execute(
                connection,
                sql: """
                CREATE TABLE rules (
                    id TEXT PRIMARY KEY,
                    payload BLOB NOT NULL
                )
                """
            )
            try execute(
                connection,
                sql: """
                CREATE TABLE settings (
                    key TEXT PRIMARY KEY,
                    payload BLOB NOT NULL
                )
                """
            )
            try execute(
                connection,
                sql: "INSERT INTO schema_migrations(version) VALUES (1)"
            )
            try execute(connection, sql: "COMMIT")
        } catch {
            try? execute(connection, sql: "ROLLBACK")
            throw error
        }
    }

    private static func execute(
        _ connection: OpaquePointer,
        sql: String,
        bindings: [SQLiteValue] = []
    ) throws {
        let statement = try prepare(connection, sql: sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, connection: connection)
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE || status == SQLITE_ROW else {
            throw DatabaseError.step(String(cString: sqlite3_errmsg(connection)))
        }
    }

    private static func query(
        _ connection: OpaquePointer,
        sql: String,
        bindings: [SQLiteValue] = []
    ) throws -> [SQLiteRow] {
        let statement = try prepare(connection, sql: sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, connection: connection)

        var rows: [SQLiteRow] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE {
                return rows
            }
            guard status == SQLITE_ROW else {
                throw DatabaseError.step(String(cString: sqlite3_errmsg(connection)))
            }

            var row: SQLiteRow = [:]
            for column in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, column))
                row[name] = value(statement: statement, column: column)
            }
            rows.append(row)
        }
    }

    private static func prepare(_ connection: OpaquePointer, sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(connection, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let statement else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(connection)))
        }
        return statement
    }

    private static func bind(
        _ values: [SQLiteValue],
        to statement: OpaquePointer,
        connection: OpaquePointer
    ) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch value {
            case .null:
                status = sqlite3_bind_null(statement, index)
            case let .integer(value):
                status = sqlite3_bind_int64(statement, index, value)
            case let .real(value):
                status = sqlite3_bind_double(statement, index, value)
            case let .text(value):
                status = sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
            case let .blob(data):
                status = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), sqliteTransient)
                }
            }
            guard status == SQLITE_OK else {
                throw DatabaseError.bind(String(cString: sqlite3_errmsg(connection)))
            }
        }
    }

    private static func value(statement: OpaquePointer, column: Int32) -> SQLiteValue {
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER:
            .integer(sqlite3_column_int64(statement, column))
        case SQLITE_FLOAT:
            .real(sqlite3_column_double(statement, column))
        case SQLITE_TEXT:
            .text(String(cString: sqlite3_column_text(statement, column)))
        case SQLITE_BLOB:
            .blob(Data(
                bytes: sqlite3_column_blob(statement, column),
                count: Int(sqlite3_column_bytes(statement, column))
            ))
        default:
            .null
        }
    }
}

enum SQLiteValue: Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    var integer: Int64? {
        guard case let .integer(value) = self else {
            return nil
        }
        return value
    }

    var blob: Data? {
        guard case let .blob(value) = self else {
            return nil
        }
        return value
    }
}

typealias SQLiteRow = [String: SQLiteValue]

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

