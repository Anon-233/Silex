import Foundation

public enum ApplicationPaths {
    public static func applicationSupport(
        fileManager: FileManager = .default
    ) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Silex", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    public static func databaseURL(
        fileManager: FileManager = .default
    ) throws -> URL {
        try applicationSupport(fileManager: fileManager)
            .appendingPathComponent("silex.sqlite3")
    }
}

