import AppKit
import Foundation
import TOMLDecoder

// MARK: - Config

// hosts/rule are optional because Swift's synthesized Decodable ignores
// property defaults for absent keys — and an absent `hosts` is the catch-all.
struct Rule: Decodable {
    var hosts: [String]?
    var browser: String
    var profile: String?
}

private struct ConfigFile: Decodable {
    var rule: [Rule]?
}

let starterConfig = """
    # Rules are tried in order; the first match wins.
    # `hosts` matches the URL host exactly or as a suffix:
    # "nvidia.com" matches nvidia.com and foo.nvidia.com, but not evilnvidia.com.

    [[rule]]
    # Work SSO/auth domains
    hosts = ["localhost", "nvidia.com", "login.microsoftonline.com", "paloaltonetworks.com"]
    browser = "Google Chrome"
    profile = "Work"

    [[rule]]
    # No `hosts` = catch-all. Keep this last.
    browser = "Google Chrome"
    profile = "Personal"

    """

// MARK: - Router

final class Router {
    static let configPath: URL = {
        if let override = ProcessInfo.processInfo.environment["PERSNICKETY_CONFIG"] {
            return URL(filePath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/persnickety/config.toml")
    }()

    // ponytail: last resort so a missing or broken config never eats a click.
    // Safari is the one browser guaranteed to be installed.
    private static let lastResort = Rule(browser: "Safari")

    private var rules: [Rule] = []
    private var profileDirs: [String: String] = [:]
    private var stamp: Date?

    /// Reloads when the config's mtime changes. Called on every dispatch —
    /// a stat per click is free, and unlike a DispatchSource watcher it
    /// survives the write-temp-then-rename that editors use to save.
    private func reloadIfChanged() {
        let mtime = (try? FileManager.default.attributesOfItem(atPath: Self.configPath.path))?[.modificationDate] as? Date
        guard mtime != stamp else { return }
        stamp = mtime
        do {
            let text = try String(contentsOf: Self.configPath, encoding: .utf8)
            rules = (try TOMLDecoder().decode(ConfigFile.self, from: text).rule ?? []).map {
                Rule(hosts: ($0.hosts ?? []).map { $0.lowercased() },
                     browser: $0.browser, profile: $0.profile)
            }
        } catch {
            FileHandle.standardError.write(Data("persnickety: \(Self.configPath.path): \(error)\n".utf8))
            rules = []
        }
        profileDirs = Self.chromeProfileDirs()
    }

    private func rule(for host: String) -> Rule {
        rules.first { rule in
            let hosts = rule.hosts ?? []
            return hosts.isEmpty || hosts.contains { host == $0 || host.hasSuffix("." + $0) }
        } ?? Self.lastResort
    }

    /// Chrome's display name -> on-disk profile directory ("Work" -> "Profile 18").
    private static func chromeProfileDirs() -> [String: String] {
        let localState = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Google/Chrome/Local State")
        guard let data = try? Data(contentsOf: localState),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cache = (json["profile"] as? [String: Any])?["info_cache"] as? [String: Any]
        else { return [:] }

        var map: [String: String] = [:]
        // ponytail: sorted so a duplicate display name resolves the same way every
        // run (two profiles can share one name). Put the literal directory in the
        // config to pick the other one.
        for dir in cache.keys.sorted() {
            guard let name = (cache[dir] as? [String: Any])?["name"] as? String else { continue }
            if map[name] == nil { map[name] = dir }
        }
        return map
    }

    private func resolve(_ profile: String) -> String {
        profileDirs[profile] ?? profile  // unknown name = already a directory
    }

    private func target(for raw: String) -> (rule: Rule, profileDir: String?) {
        reloadIfChanged()
        let host = URL(string: raw)?.host()?.lowercased() ?? ""
        let rule = rule(for: host)
        return (rule, rule.profile.map(resolve))
    }

    /// Dry run for `--route`, and the thing test.sh asserts on.
    func describe(_ raw: String) -> String {
        let (rule, dir) = target(for: raw)
        return "\(rule.browser)\t\(dir ?? "-")"
    }

    func open(_ raw: String) {
        let (rule, dir) = target(for: raw)
        let process = Process()
        let chromeBinary = "/Applications/\(rule.browser).app/Contents/MacOS/\(rule.browser)"

        if let dir, FileManager.default.isExecutableFile(atPath: chromeBinary) {
            // Chrome's process singleton forwards this to the running instance and
            // honors the profile. NSWorkspace's `arguments` are ignored when the
            // app is already up, which is almost always.
            process.executableURL = URL(filePath: chromeBinary)
            process.arguments = ["--profile-directory=\(dir)", raw]
        } else {
            process.executableURL = URL(filePath: "/usr/bin/open")
            process.arguments = ["-a", rule.browser, raw]
        }
        try? process.run()
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let router = Router()
    private var statusItem: NSStatusItem!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Must be here, not didFinishLaunching: a URL that cold-starts us arrives
        // before didFinishLaunching and would be dropped.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "persnickety")

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        // target stays nil so this walks the responder chain up to NSApp
        menu.addItem(NSMenuItem(title: "Quit persnickety",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        router.open(url)
    }

    @objc private func openConfig() {
        let path = Router.configPath
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? starterConfig.write(to: path, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(path)
    }
}

// MARK: - Entry

let arguments = CommandLine.arguments
if arguments.count == 3, arguments[1] == "--route" {
    print(Router().describe(arguments[2]))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
