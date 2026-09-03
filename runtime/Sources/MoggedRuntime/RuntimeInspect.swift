import Foundation

public struct RuntimeInspect: Sendable, Equatable {
    public let wine: String?
    public let wineReady: Bool
    public let backend: BackendConfig?
    public let supportRoot: String
    public let logsDir: String
    public let steamPresent: Bool
    public let steamRunning: Bool
    public let steamRoot: String?
    public let steamAccount: String?
    public let steamAppCount: Int

    public init(
        wine: String?,
        wineReady: Bool,
        backend: BackendConfig?,
        supportRoot: String,
        logsDir: String,
        steamPresent: Bool,
        steamRunning: Bool,
        steamRoot: String?,
        steamAccount: String?,
        steamAppCount: Int
    ) {
        self.wine = wine
        self.wineReady = wineReady
        self.backend = backend
        self.supportRoot = supportRoot
        self.logsDir = logsDir
        self.steamPresent = steamPresent
        self.steamRunning = steamRunning
        self.steamRoot = steamRoot
        self.steamAccount = steamAccount
        self.steamAppCount = steamAppCount
    }

    public static let empty = RuntimeInspect(
        wine: nil,
        wineReady: false,
        backend: nil,
        supportRoot: "",
        logsDir: "",
        steamPresent: false,
        steamRunning: false,
        steamRoot: nil,
        steamAccount: nil,
        steamAppCount: 0
    )
}

public struct SessionInspect: Sendable, Equatable {
    public let titleId: String
    public let pid: Int32?
    public let running: Bool
    public let lastExit: Int32?
    public let prefix: String
    public let cache: String
    public let logPath: String
    public let exe: String?
    public let install: String?
    public let stack: String
    public let env: [String: String]
    public let prefixReady: Bool

    public init(
        titleId: String,
        pid: Int32?,
        running: Bool,
        lastExit: Int32?,
        prefix: String,
        cache: String,
        logPath: String,
        exe: String?,
        install: String?,
        stack: String,
        env: [String: String],
        prefixReady: Bool
    ) {
        self.titleId = titleId
        self.pid = pid
        self.running = running
        self.lastExit = lastExit
        self.prefix = prefix
        self.cache = cache
        self.logPath = logPath
        self.exe = exe
        self.install = install
        self.stack = stack
        self.env = env
        self.prefixReady = prefixReady
    }
}
