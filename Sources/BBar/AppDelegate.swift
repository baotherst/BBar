import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var expandCollapseItem: NSStatusItem!
    private var separatorItem: NSStatusItem!
    
    private var isCollapsed = false
    private let contextMenu = NSMenu()
    
    // Settings Window & Controls
    private var settingsWindow: NSWindow?
    private var launchCheckbox: NSButton?
    private var delayPopup: NSPopUpButton?
    
    // Timers for Auto-hide & Hover detection
    private var autoHideTimer: Timer?
    private var hoverPollingTimer: Timer?
    private var lastMouseWasInMenuBar = false
    
    // Global mouse event monitor
    private var globalClickMonitor: Any?
    
    private func log(_ message: String) {
        let logMessage = "[\(Date())] \(message)\n"
        let path = "/Users/baother/Documents/AiGoogle/bbar/output.log"
        if let fileHandle = FileHandle(forWritingAtPath: path) {
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try? logMessage.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        log("Application did finish launching")
        
        // Create expandCollapseItem first so it's placed to the right of separatorItem
        expandCollapseItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        separatorItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Configure expandCollapseItem
        if let button = expandCollapseItem.button {
            button.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "切换隐藏状态")
            button.action = #selector(toggleState(_:))
            button.target = self
            // Enable both left and right clicks
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                button.image = button.image?.withSymbolConfiguration(config)
            }
        }
        
        // Configure separatorItem
        if let button = separatorItem.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "隐藏区域分割线")
            button.action = #selector(separatorClicked(_:))
            button.target = self
            
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 6, weight: .regular)
                button.image = button.image?.withSymbolConfiguration(config)
            }
            
            // Disable click highlight for visual aesthetics
            if let buttonCell = button.cell as? NSButtonCell {
                buttonCell.highlightsBy = NSCell.StyleMask(rawValue: 0)
            }
        }
        
        setupMenu()
        loadState()
        updateLayout()
        
        // Start mouse hover polling timer
        hoverPollingTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(pollMouseHover),
            userInfo: nil,
            repeats: true
        )
        // Ensure it runs in common modes (e.g. while scrolling or dragging)
        RunLoop.main.add(hoverPollingTimer!, forMode: .common)
        
        // Initialize the auto-hide timer if expanded
        resetAutoHideTimer()
    }
    
    private func setupMenu() {
        let titleItem = NSMenuItem(title: "BBar (极简菜单栏)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        contextMenu.addItem(titleItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        contextMenu.addItem(settingsItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 BBar", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }
    
    @objc private func toggleState(_ sender: Any?) {
        log("Chevron button clicked")
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Show the context menu dynamically
            expandCollapseItem.menu = contextMenu
            expandCollapseItem.button?.performClick(nil)
            expandCollapseItem.menu = nil
        } else {
            isCollapsed.toggle()
            saveState()
            updateLayout()
            
            if !isCollapsed {
                resetAutoHideTimer()
            } else {
                invalidateAutoHideTimer()
            }
        }
    }
    
    @objc private func separatorClicked(_ sender: Any?) {
        log("Separator button clicked directly")
        isCollapsed.toggle()
        saveState()
        updateLayout()
        
        if !isCollapsed {
            resetAutoHideTimer()
        } else {
            invalidateAutoHideTimer()
        }
    }
    
    @objc private func quitApp(_ sender: Any?) {
        log("Quitting application")
        NSApp.terminate(nil)
    }
    
    private func updateLayout() {
        log("Updating layout. isCollapsed = \(isCollapsed)")
        if isCollapsed {
            let screenWidth = NSScreen.main?.frame.width ?? 2000
            separatorItem.length = screenWidth + 100
            log("Chevron frame (collapsed): \(String(describing: expandCollapseItem.button?.frame))")
            log("Separator frame (collapsed): \(String(describing: separatorItem.button?.frame))")
            
            if let button = expandCollapseItem.button {
                button.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "展开图标")
                if #available(macOS 11.0, *) {
                    let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                    button.image = button.image?.withSymbolConfiguration(config)
                }
            }
            
            // Start listening to global clicks on empty space when collapsed
            startGlobalClickMonitor()
        } else {
            separatorItem.length = 22 // Normal status item width
            log("Chevron frame (expanded): \(String(describing: expandCollapseItem.button?.frame))")
            log("Separator frame (expanded): \(String(describing: separatorItem.button?.frame))")
            
            if let button = expandCollapseItem.button {
                button.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "隐藏图标")
                if #available(macOS 11.0, *) {
                    let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                    button.image = button.image?.withSymbolConfiguration(config)
                }
            }
            
            // Stop listening to global clicks when expanded
            stopGlobalClickMonitor()
        }
    }
    
    private func saveState() {
        UserDefaults.standard.set(isCollapsed, forKey: "isCollapsed")
    }
    
    private func loadState() {
        isCollapsed = UserDefaults.standard.bool(forKey: "isCollapsed")
    }
    
    // MARK: - Auto-hide & Hover Timer Logic
    
    private func resetAutoHideTimer() {
        invalidateAutoHideTimer()
        
        guard !isCollapsed else { return }
        
        let delay = UserDefaults.standard.integer(forKey: "autoHideDelay")
        guard delay > 0 else { return }
        
        log("Resetting auto-hide timer with delay: \(delay)s")
        autoHideTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(delay),
            target: self,
            selector: #selector(autoHideTimerFired),
            userInfo: nil,
            repeats: false
        )
    }
    
    private func invalidateAutoHideTimer() {
        if autoHideTimer != nil {
            log("Invalidating auto-hide timer")
            autoHideTimer?.invalidate()
            autoHideTimer = nil
        }
    }
    
    @objc private func autoHideTimerFired() {
        guard !isCollapsed else { return }
        
        // Only hide if the mouse is NOT in the menu bar area
        if !checkIfMouseInMenuBar() {
            log("Auto-hide timer fired. Collapsing bar.")
            isCollapsed = true
            saveState()
            updateLayout()
            invalidateAutoHideTimer()
        } else {
            log("Auto-hide timer fired, but mouse is in menu bar. Deferring.")
            // Mouse is in menu bar, defer hiding by resetting the timer
            resetAutoHideTimer()
        }
    }
    
    @objc private func pollMouseHover() {
        let mouseInMenuBar = checkIfMouseInMenuBar()
        
        if mouseInMenuBar {
            // Mouse is hovering. Suspend auto-hide timer immediately
            if autoHideTimer != nil {
                invalidateAutoHideTimer()
                log("Auto-hide suspended (mouse entering menu bar)")
            }
        } else {
            // Mouse is outside
            if lastMouseWasInMenuBar {
                // Mouse just left! Start countdown
                log("Mouse left menu bar. Restarting auto-hide countdown.")
                resetAutoHideTimer()
            } else {
                // Mouse remains outside. If expanded and no timer running, start countdown
                let delay = UserDefaults.standard.integer(forKey: "autoHideDelay")
                if !isCollapsed && delay > 0 && autoHideTimer == nil {
                    log("Mouse is outside. Starting auto-hide countdown.")
                    resetAutoHideTimer()
                }
            }
        }
        
        lastMouseWasInMenuBar = mouseInMenuBar
    }
    
    private func checkIfMouseInMenuBar() -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        return checkIfPointInMenuBar(mouseLocation)
    }
    
    private func checkIfPointInMenuBar(_ point: NSPoint) -> Bool {
        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            let menuBarRect = NSRect(
                x: screenFrame.minX,
                y: screenFrame.maxY - 45,
                width: screenFrame.width,
                height: 45
            )
            if NSMouseInRect(point, menuBarRect, false) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Global Click Monitor (Empty Space Click Detection)
    
    private func startGlobalClickMonitor() {
        guard globalClickMonitor == nil else { return }
        log("Starting global click monitor")
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.handleGlobalClick(event)
        }
    }
    
    private func stopGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            log("Stopping global click monitor")
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
    
    private func handleGlobalClick(_ event: NSEvent) {
        let clickLocation = NSEvent.mouseLocation
        
        // Check if click occurred inside the menu bar
        guard checkIfPointInMenuBar(clickLocation) else { return }
        
        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            // Verify click is on this specific screen's menu bar
            if clickLocation.x >= screenFrame.minX && clickLocation.x <= screenFrame.maxX {
                if let window = expandCollapseItem.button?.window {
                    let chevronFrame = window.frame
                    
                    // Define left boundary (e.g. 350 pts from left edge of screen to prevent intercepting active app menus)
                    let leftBoundary = screenFrame.minX + max(350, screenFrame.width * 0.25)
                    
                    // Trigger expansion only if click is between the app menu boundary and the BBar chevron
                    if clickLocation.x > leftBoundary && clickLocation.x < chevronFrame.minX {
                        log("Global click on empty space detected at \(clickLocation). Expanding BBar.")
                        DispatchQueue.main.async { [weak self] in
                            self?.expandMenuBar()
                        }
                    }
                }
            }
        }
    }
    
    private func expandMenuBar() {
        isCollapsed = false
        saveState()
        updateLayout()
        resetAutoHideTimer()
    }
    
    // MARK: - Settings UI
    
    @objc private func openSettings(_ sender: Any?) {
        log("Opening settings window")
        if settingsWindow == nil {
            createSettingsWindow()
        }
        
        // Sync states before display
        launchCheckbox?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        
        let currentDelay = UserDefaults.standard.integer(forKey: "autoHideDelay")
        switch currentDelay {
        case 5: delayPopup?.selectItem(at: 1)
        case 10: delayPopup?.selectItem(at: 2)
        case 30: delayPopup?.selectItem(at: 3)
        default: delayPopup?.selectItem(at: 0)
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func createSettingsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BBar 设置"
        window.center()
        window.isReleasedWhenClosed = false
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 180))
        window.contentView = contentView
        
        // Title Label
        let titleLabel = NSTextField(labelWithString: "BBar 偏好设置")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: 135, width: 320, height: 25)
        contentView.addSubview(titleLabel)
        
        // Checkbox for Launch at Login
        let checkbox = NSButton(
            checkboxWithTitle: "开机自动启动",
            target: self,
            action: #selector(settingsToggleLaunchAtLogin(_:))
        )
        checkbox.frame = NSRect(x: 20, y: 95, width: 320, height: 20)
        contentView.addSubview(checkbox)
        self.launchCheckbox = checkbox
        
        // Auto-hide Delay Label
        let delayLabel = NSTextField(labelWithString: "自动隐藏延时：")
        delayLabel.font = NSFont.systemFont(ofSize: 13)
        delayLabel.frame = NSRect(x: 20, y: 55, width: 120, height: 20)
        contentView.addSubview(delayLabel)
        
        // Auto-hide Delay Popup Button
        let popup = NSPopUpButton(
            frame: NSRect(x: 140, y: 52, width: 150, height: 25),
            pullsDown: false
        )
        popup.addItems(withTitles: ["从不", "5 秒", "10 秒", "30 秒"])
        popup.target = self
        popup.action = #selector(settingsDelayChanged(_:))
        contentView.addSubview(popup)
        self.delayPopup = popup
        
        // Close button
        let closeButton = NSButton(title: "完成", target: self, action: #selector(settingsDone(_:)))
        closeButton.frame = NSRect(x: 260, y: 15, width: 80, height: 25)
        closeButton.bezelStyle = .rounded
        contentView.addSubview(closeButton)
        
        self.settingsWindow = window
    }
    
    @objc private func settingsToggleLaunchAtLogin(_ sender: NSButton) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.register()
                log("Launch at login enabled via settings")
            } else {
                try SMAppService.mainApp.unregister()
                log("Launch at login disabled via settings")
            }
        } catch {
            log("Failed to change launch-at-login: \(error)")
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }
    
    @objc private func settingsDelayChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        let delay: Int
        switch index {
        case 1: delay = 5
        case 2: delay = 10
        case 3: delay = 30
        default: delay = 0 // Never
        }
        
        UserDefaults.standard.set(delay, forKey: "autoHideDelay")
        log("Auto-hide delay set to \(delay) seconds")
        resetAutoHideTimer()
    }
    
    @objc private func settingsDone(_ sender: Any?) {
        settingsWindow?.close()
    }
}
