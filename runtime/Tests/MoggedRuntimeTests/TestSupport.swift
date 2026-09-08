import Foundation
import Testing
@testable import MoggedRuntime

enum TestRepo {
    static let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    static let runtimeDirectory = testsDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    static let repoRoot = runtimeDirectory.deletingLastPathComponent()
    static let sourcesDirectory = runtimeDirectory.appendingPathComponent("Sources/MoggedRuntime")
    static let profilesDirectory = repoRoot.appendingPathComponent("profiles")
}

func scratchHome() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("mogged-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func makeSupervisor(home: URL, wine: String?) throws -> (RuntimeSupervisor, RuntimePaths) {
    let paths = RuntimePaths(root: home)
    let supervisor = RuntimeSupervisor(
        library: LibraryStore(paths: paths),
        probe: BackendProbe(fixedWine: wine),
        telemetry: TelemetryLog(paths: paths),
        configStore: BackendConfigStore(paths: paths),
        environment: WineEnvironment(paths: paths),
        launcher: BackendLauncher(paths: paths),
        services: SteamServices(paths: paths),
        paths: paths
    )
    return (supervisor, paths)
}

func writeFakeWine(in dir: URL, hold: Bool) throws -> URL {
    let url = dir.appendingPathComponent("fake-wine")
    let holdLine = hold ? "sleep 60" : "true"
    let script = """
    #!/bin/sh
    echo "$*" >> "$(dirname "$0")/invocations.txt"
    if [ "$1" = "wineboot" ]; then
      mkdir -p "$WINEPREFIX"
      touch "$WINEPREFIX/system.reg"
      exit 0
    fi
    if [ "$1" = "reg" ]; then
      exit 0
    fi
    \(holdLine)
    exit 0
    """
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}

/// Fakes the two things a real Steam client would do: deny a code-less `-login`
/// (SteamCMD's device trust never carries over) and succeed once a code is passed.
func writeFakeSteamClientWine(in dir: URL) throws -> URL {
    let url = dir.appendingPathComponent("fake-steam-wine")
    let script = #"""
    #!/bin/sh
    echo "$*" >> "$(dirname "$0")/invocations.txt"
    case "$1" in
      *steamcmd.exe)
        STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
        mkdir -p "$STEAM"
        if [ "$5" != "+quit" ] && [ -n "$5" ]; then
          echo dummy > "$STEAM/ssfn_ok"
          echo "Waiting for user info...OK"
        else
          echo "Please check your email for the message from Steam"
          echo "ERROR (Account Logon Denied)"
        fi
        exit 0
        ;;
      *SteamSetup.exe)
        STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
        mkdir -p "$STEAM"
        : > "$STEAM/steam.exe"
        exit 0
        ;;
      *steam.exe)
        LOGS="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs"
        STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
        mkdir -p "$LOGS"
        STAMP=$(date +%s)
        if ls "$STEAM"/ssfn* >/dev/null 2>&1; then
          printf '[Software\\\\Valve\\\\Steam\\\\ActiveProcess]\n"ActiveUser"=dword:00000001\n' > "$WINEPREFIX/user.reg"
          printf '[%s] Client version: 1\n[%s] Connected\n' "$STAMP" "$STAMP" >> "$LOGS/console_log.txt"
        else
          printf '[%s] Client version: 1\n[%s] LogonFailure Account Logon Denied\n' "$STAMP" "$STAMP" >> "$LOGS/console_log.txt"
        fi
        sleep 5
        exit 0
        ;;
    esac
    exit 0
    """#
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}

func makeGameFolder(home: URL, profile: TitleProfile) throws -> URL {
    let game = home.appendingPathComponent("game")
    try FileManager.default.createDirectory(at: game, withIntermediateDirectories: true)
    try Data().write(to: game.appendingPathComponent(profile.executables[0]))
    return game
}

func plantSteamClient(prefix: URL, programFilesX86: Bool = true) throws -> URL {
    let rel = programFilesX86
        ? "drive_c/Program Files (x86)/Steam"
        : "drive_c/Program Files/Steam"
    let steamDir = prefix.appendingPathComponent(rel)
    try FileManager.default.createDirectory(
        at: steamDir.appendingPathComponent("logs"),
        withIntermediateDirectories: true
    )
    try Data().write(to: steamDir.appendingPathComponent("steam.exe"))
    return steamDir
}

func smokeProfile() throws -> TitleProfile {
    try ProfileLoader.load().first { $0.id == "apex-legends" }!
}

func deskJobProfile() throws -> TitleProfile {
    try ProfileLoader.load().first { $0.id == "aperture-desk-job" }!
}

func decodeProfile(_ json: String) throws -> TitleProfile {
    try JSONDecoder().decode(TitleProfile.self, from: Data(json.utf8))
}

func pgrep(matching needle: String) -> [Int32] {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    proc.arguments = ["-f", needle]
    let pipe = Pipe()
    proc.standardOutput = pipe
    try? proc.run()
    proc.waitUntilExit()
    let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return text.split(separator: "\n").compactMap { Int32($0) }
}

func sampleSteamApp(
    appId: Int = 42,
    name: String = "Catalog Title",
    hasWindowsExe: Bool = true,
    macNativeOnly: Bool = false,
    isTool: Bool = false,
    executableNames: [String] = ["game.exe"]
) -> SteamLibraryApp {
    SteamLibraryApp(
        appId: appId,
        name: name,
        installDir: name,
        installPath: nil,
        lastPlayed: 9,
        coverURL: nil,
        executableNames: executableNames,
        hasWindowsExe: hasWindowsExe,
        macNativeOnly: macNativeOnly,
        isInstalled: true,
        isTool: isTool
    )
}
