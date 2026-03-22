import Cocoa
import Carbon
import ServiceManagement

// MARK: - Shortcut Config

struct ShortcutEntry: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(keyCode))
        return parts.joined()
    }

    static func keyName(_ code: UInt32) -> String {
        let map: [UInt32: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
            0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q",
            0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1",
            0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
            0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P", 0x25: "L",
            0x26: "J", 0x28: "K", 0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/",
            0x2D: "N", 0x2E: "M", 0x2F: ".", 0x31: "Space", 0x32: "`",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return map[code] ?? "Key\(code)"
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }
}

struct ShortcutConfig: Codable {
    var area: ShortcutEntry
    var window: ShortcutEntry
    var fullscreen: ShortcutEntry

    static let `default` = ShortcutConfig(
        area: ShortcutEntry(keyCode: 0x00, modifiers: UInt32(optionKey | controlKey)),
        window: ShortcutEntry(keyCode: 0x0D, modifiers: UInt32(optionKey | controlKey)),
        fullscreen: ShortcutEntry(keyCode: 0x03, modifiers: UInt32(optionKey | controlKey))
    )

    static var configURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("ScreenshotClipboard")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shortcuts.json")
    }

    static func load() -> ShortcutConfig {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(ShortcutConfig.self, from: data) else {
            return .default
        }
        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.configURL)
        }
    }
}

// MARK: - Screenshot Manager

class ScreenshotManager {
    enum Mode: String {
        case area, window, fullscreen

        var label: String {
            switch self {
            case .area: return "区域截图"
            case .window: return "窗口截图"
            case .fullscreen: return "全屏截图"
            }
        }
    }

    func capture(_ mode: Mode) {
        var args = ["-c", "-x"]
        switch mode {
        case .area: args.append("-s")
        case .window: args += ["-s", "-w"]
        case .fullscreen: break
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = args
            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        ToastWindow.show(message: "\(mode.label) 已复制到剪贴板")
                    }
                }
            } catch {
                print("Screenshot failed: \(error)")
            }
        }
    }
}

// MARK: - Toast Window

class ToastWindow {
    private static var toastWindow: NSWindow?

    static func show(message: String) {
        toastWindow?.orderOut(nil)
        toastWindow = nil

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.sizeToFit()

        let padding: CGFloat = 24
        let width = label.frame.width + padding * 2
        let height: CGFloat = 40

        guard let screen = NSScreen.main else { return }
        let x = screen.visibleFrame.midX - width / 2
        let y = screen.visibleFrame.maxY - 80

        let win = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.ignoresMouseEvents = true

        let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        bg.material = .hudWindow
        bg.state = .active
        bg.blendingMode = .behindWindow
        bg.wantsLayer = true
        bg.layer?.cornerRadius = height / 2
        bg.layer?.masksToBounds = true

        label.frame = NSRect(x: padding, y: (height - label.frame.height) / 2,
                             width: label.frame.width, height: label.frame.height)
        bg.addSubview(label)
        win.contentView = bg

        win.alphaValue = 0
        win.orderFront(nil)
        toastWindow = win

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            win.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak win] in
            guard let w = win else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                w.animator().alphaValue = 0
            }, completionHandler: { [weak w] in
                w?.orderOut(nil)
                if toastWindow === w { toastWindow = nil }
            })
        }
    }
}

// MARK: - Global Hotkey Manager

class HotkeyManager {
    typealias Handler = () -> Void
    private var hotkeys: [(id: EventHotKeyID, ref: EventHotKeyRef?, handler: Handler)] = []
    private var nextID: UInt32 = 1

    static let shared = HotkeyManager()

    private init() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            for entry in HotkeyManager.shared.hotkeys where entry.id.id == hkID.id {
                DispatchQueue.main.async { entry.handler() }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventSpec, nil, nil)
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) {
        let id = EventHotKeyID(signature: OSType(0x5353_4348), id: nextID)
        nextID += 1
        var ref: EventHotKeyRef?
        if RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr {
            hotkeys.append((id: id, ref: ref, handler: handler))
        }
    }

    func unregisterAll() {
        for entry in hotkeys {
            if let ref = entry.ref { UnregisterEventHotKey(ref) }
        }
        hotkeys.removeAll()
        nextID = 1
    }
}

// MARK: - Shortcut Recorder (NSView-based, safe key capture)

class ShortcutRecorderView: NSView {
    var shortcut: ShortcutEntry? { didSet { needsDisplay = true } }
    var isRecording = false { didSet { needsDisplay = true } }
    var onRecorded: ((ShortcutEntry) -> Void)?

    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateAppearance() {
        if isRecording {
            layer?.borderColor = NSColor.systemBlue.cgColor
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        } else {
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        updateAppearance()

        let text: String
        if isRecording {
            text = "请按下快捷键组合..."
        } else if let s = shortcut {
            text = s.displayString
        } else {
            text = "点击设置"
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: isRecording ? .medium : .regular),
            .foregroundColor: isRecording ? NSColor.systemBlue : NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startRecording()
    }

    private func startRecording() {
        stopRecording()
        isRecording = true

        // Use local monitor - store reference for cleanup
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            // Escape cancels
            if event.keyCode == 0x35 {
                self.stopRecording()
                return nil
            }

            let mods = ShortcutEntry.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { return nil } // require at least one modifier

            let entry = ShortcutEntry(keyCode: UInt32(event.keyCode), modifiers: mods)
            self.shortcut = entry
            self.stopRecording()
            self.onRecorded?(entry)
            return nil
        }
    }

    func stopRecording() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    // Cleanup on removal from window
    override func removeFromSuperview() {
        stopRecording()
        super.removeFromSuperview()
    }
}

// MARK: - Preferences Window

class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private var areaRecorder: ShortcutRecorderView!
    private var windowRecorder: ShortcutRecorderView!
    private var fullscreenRecorder: ShortcutRecorderView!
    var config: ShortcutConfig
    var onSave: ((ShortcutConfig) -> Void)?

    init(config: ShortcutConfig) {
        self.config = config
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 230),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        win.title = "快捷键设置"
        win.center()
        super.init(window: win)
        win.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let view = window?.contentView else { return }

        let items: [(String, ShortcutEntry)] = [
            ("区域截图", config.area),
            ("窗口截图", config.window),
            ("全屏截图", config.fullscreen),
        ]

        var recorders: [ShortcutRecorderView] = []

        for (i, item) in items.enumerated() {
            let y = CGFloat(170 - i * 48)

            let label = NSTextField(labelWithString: item.0)
            label.font = NSFont.systemFont(ofSize: 14)
            label.frame = NSRect(x: 24, y: y + 4, width: 80, height: 24)
            view.addSubview(label)

            let recorder = ShortcutRecorderView(frame: NSRect(x: 120, y: y, width: 230, height: 32))
            recorder.shortcut = item.1
            view.addSubview(recorder)
            recorders.append(recorder)
        }

        areaRecorder = recorders[0]
        windowRecorder = recorders[1]
        fullscreenRecorder = recorders[2]

        areaRecorder.onRecorded = { [weak self] e in self?.config.area = e }
        windowRecorder.onRecorded = { [weak self] e in self?.config.window = e }
        fullscreenRecorder.onRecorded = { [weak self] e in self?.config.fullscreen = e }

        let saveBtn = NSButton(title: "保存", target: self, action: #selector(doSave))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: 290, y: 16, width: 80, height: 32)
        view.addSubview(saveBtn)

        let resetBtn = NSButton(title: "恢复默认", target: self, action: #selector(doReset))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: 24, y: 16, width: 100, height: 32)
        view.addSubview(resetBtn)
    }

    @objc private func doSave() {
        // Stop any active recording
        areaRecorder.stopRecording()
        windowRecorder.stopRecording()
        fullscreenRecorder.stopRecording()

        config.save()
        onSave?(config)
        window?.close()
        ToastWindow.show(message: "快捷键已保存")
    }

    @objc private func doReset() {
        config = .default
        areaRecorder.shortcut = config.area
        windowRecorder.shortcut = config.window
        fullscreenRecorder.shortcut = config.fullscreen
    }

    func windowWillClose(_ notification: Notification) {
        // Clean up monitors
        areaRecorder?.stopRecording()
        windowRecorder?.stopRecording()
        fullscreenRecorder?.stopRecording()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let screenshotManager = ScreenshotManager()
    var config = ShortcutConfig.load()
    var prefsController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        registerHotkeys()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "截图")
            btn.image?.size = NSSize(width: 18, height: 18)
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let items: [(String, ShortcutEntry, Selector)] = [
            ("区域截图", config.area, #selector(captureArea)),
            ("窗口截图", config.window, #selector(captureWindow)),
            ("全屏截图", config.fullscreen, #selector(captureFullscreen)),
        ]

        for item in items {
            let mi = NSMenuItem(title: item.0, action: item.2, keyEquivalent: "")
            mi.target = self
            let attr = NSMutableAttributedString(string: item.0)
            attr.append(NSAttributedString(string: "    \(item.1.displayString)", attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 12)
            ]))
            mi.attributedTitle = attr
            menu.addItem(mi)
        }

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "快捷键设置...", action: #selector(openPrefs), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let launchItem = NSMenuItem(title: "开机自启动", action: #selector(toggleAutoLaunch), keyEquivalent: "")
        launchItem.target = self
        if SMAppService.mainApp.status == .enabled {
            launchItem.state = .on
        } else {
            launchItem.state = .off
        }
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func registerHotkeys() {
        let mgr = HotkeyManager.shared
        mgr.unregisterAll()

        mgr.register(keyCode: config.area.keyCode, modifiers: config.area.modifiers) { [weak self] in
            self?.screenshotManager.capture(.area)
        }
        mgr.register(keyCode: config.window.keyCode, modifiers: config.window.modifiers) { [weak self] in
            self?.screenshotManager.capture(.window)
        }
        mgr.register(keyCode: config.fullscreen.keyCode, modifiers: config.fullscreen.modifiers) { [weak self] in
            self?.screenshotManager.capture(.fullscreen)
        }
    }

    @objc private func captureArea() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.screenshotManager.capture(.area)
        }
    }
    @objc private func captureWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.screenshotManager.capture(.window)
        }
    }
    @objc private func captureFullscreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.screenshotManager.capture(.fullscreen)
        }
    }

    @objc private func openPrefs() {
        let ctrl = PreferencesWindowController(config: config)
        ctrl.onSave = { [weak self] newConfig in
            self?.config = newConfig
            self?.registerHotkeys()
            self?.rebuildMenu()
        }
        prefsController = ctrl
        ctrl.showWindow(nil)
        ctrl.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleAutoLaunch() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                ToastWindow.show(message: "已关闭开机自启动")
            } else {
                try service.register()
                ToastWindow.show(message: "已开启开机自启动")
            }
        } catch {
            ToastWindow.show(message: "设置失败: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Main Entry

let app = NSApplication.shared
// Global strong reference — prevents ARC from deallocating the delegate
nonisolated(unsafe) let appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()
