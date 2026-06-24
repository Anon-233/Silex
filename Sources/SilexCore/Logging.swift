import OSLog

public enum SilexLog {
    public static let app = Logger(
        subsystem: "com.anon233.Silex",
        category: "app"
    )
    public static let collection = Logger(
        subsystem: "com.anon233.Silex",
        category: "collection"
    )
    public static let service = Logger(
        subsystem: "com.anon233.Silex",
        category: "smart-service"
    )
    public static let database = Logger(
        subsystem: "com.anon233.Silex",
        category: "database"
    )
}

