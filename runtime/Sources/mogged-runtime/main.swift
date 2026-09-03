import Foundation
import MoggedRuntime

@main
enum MoggedRuntimeCLI {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch let error as MoggedError {
            fputs("error: \(error.logDescription)\n", stderr)
            exit(1)
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run(_ args: [String]) async throws {
        guard let command = args.first else {
            printUsage()
            return
        }

        let supervisor = RuntimeSupervisor()
        let profiles = try ProfileLoader.load()

        switch command {
        case "list":
            let entries = await supervisor.libraryEntries(profiles: profiles)
            for entry in entries {
                let flag = entry.canPlay ? "ready" : (entry.isInstalled ? "installed" : "missing")
                print("\(entry.profile.id)\t\(entry.profile.displayName)\t\(flag)")
            }
        case "steam":
            let snap = await supervisor.steamSnapshot()
            print("present\t\(snap.present)")
            print("running\t\(snap.running)")
            if let root = snap.root { print("root\t\(root.path)") }
            if let account = snap.account {
                print("account\t\(account.personaName ?? account.steamId)")
            }
            for app in snap.apps {
                let flag = app.isInstalled ? "installed" : "missing"
                print("\(app.appId)\t\(app.name)\t\(flag)")
            }
        case "detect":
            let probe = BackendProbe()
            let backends = probe.detect()
            if backends.isEmpty {
                print("none")
            } else {
                for backend in backends {
                    print("\(backend.kind.rawValue)\t\(backend.path)")
                }
            }
        case "status":
            let running = await supervisor.runningTitleIds()
            print(running.isEmpty ? "idle" : running.joined(separator: ","))
        case "launch":
            guard args.count >= 2 else {
                fputs("usage: mogged-runtime launch <title-id>\n", stderr)
                exit(2)
            }
            var profile = profiles.first(where: { $0.id == args[1] })
            if profile == nil {
                profile = await supervisor.libraryEntries(profiles: profiles).first(where: { $0.id == args[1] })?.profile
            }
            guard let profile else {
                throw MoggedError.gameNotFound(args[1])
            }
            let state = try await supervisor.launch(profile: profile)
            print("started\t\(state.titleId)\t\(state.pid)")
        case "stop":
            guard args.count >= 2 else {
                fputs("usage: mogged-runtime stop <title-id>\n", stderr)
                exit(2)
            }
            try await supervisor.stop(titleId: args[1])
            print("stopped\t\(args[1])")
        case "help", "-h", "--help":
            printUsage()
        default:
            fputs("unknown command: \(command)\n", stderr)
            printUsage()
            exit(2)
        }
    }

    private static func printUsage() {
        print(
            """
            mogged-runtime — hidden helper, not a user-facing app
            commands: list | steam | detect | status | launch <title-id> | stop <title-id>
            """
        )
    }
}
