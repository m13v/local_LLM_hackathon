import Cocoa
import CoreGraphics
import PythonKit

class OverlayWindow: NSWindow {
    var messageView: NSTextField
    var blinkCount = 0
    var fullMessage = "🧨😫🥵 You are about to push your trash code to main branch, are you sure?! Press Esc to exit."
    var currentMessage = ""

    init() {
        let screen = NSScreen.main!.frame
        self.messageView = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 50))

        super.init(contentRect: screen,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)

        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true

        let view = NSView(frame: self.frame)
        self.contentView = view

        messageView.stringValue = ""

        messageView.alignment = .center
        messageView.font = NSFont.systemFont(ofSize: 18)
        messageView.textColor = .white
        messageView.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        messageView.isBezeled = false
        messageView.isEditable = false
        messageView.isSelectable = false
        view.addSubview(messageView)

        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            self.updateMessagePosition(with: event.locationInWindow)
            return event
        }

        performTwoBlinks()
    }

    func updateMessagePosition(with point: NSPoint) {
        var frame = messageView.frame
        frame.origin.x = point.x
        frame.origin.y = point.y - frame.height - 20 // 20 pixels below cursor
        messageView.frame = frame
    }

    func performTwoBlinks() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            self.blinkCount += 1
            self.backgroundColor = (self.blinkCount % 2 == 0) ? .black : .white

            if self.blinkCount >= 4 {
                timer.invalidate()
                self.backgroundColor = .clear
                self.startTypingMessage()
            }
        }
    }

    func startTypingMessage() {
        print("Starting to type message: \(self.fullMessage)") // Debug print
        let typingInterval = 0.02
        DispatchQueue.global().async {
            for char in self.fullMessage {
                DispatchQueue.main.async {
                    self.currentMessage.append(char)
                    self.messageView.stringValue = self.currentMessage
                }
                Thread.sleep(forTimeInterval: typingInterval)
            }
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

var eventTap: CFMachPort?
var typedKeys = ""
var shouldBlockKeyboard = false

func runOllamaPrompt(window: OverlayWindow) {
    let userMessage = "is this a dangerous and bad language?"
    let instruction = """
    Identify if the user is doing something obviously wrong or bad and tell them concisely in one sentence. Respond in one sentence only.
    """
    let requestData: [String: Any] = [
        "model": "llama3.1",
        "messages": [
            ["role": "system", "content": instruction],
            ["role": "user", "content": userMessage]
        ]
    ]

    guard let url = URL(string: "http://localhost:11434/api/chat") else {
        print("Invalid URL")
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData, options: [])
    } catch {
        print("Failed to serialize JSON: \(error)")
        return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error sending data to Ollama: \(error)")
            return
        }
        guard let data = data else {
            print("No data received from Ollama")
            return
        }

        if let responseString = String(data: data, encoding: .utf8) {
            var accumulatedResponse = ""
            let lines = responseString.split(separator: "\n")
            for line in lines {
                if let lineData = line.data(using: .utf8) {
                    do {
                        if let jsonResponse = try JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any],
                           let message = jsonResponse["message"] as? [String: Any],
                           let responseText = message["content"] as? String {
                            accumulatedResponse += responseText
                        } else {
                            print("Invalid response format")
                        }
                    } catch {
                        print("Failed to parse response: \(error)")
                    }
                }
            }
            DispatchQueue.main.async {
                print("Setting fullMessage to: \(accumulatedResponse)") // Debug print
                window.fullMessage = accumulatedResponse
                window.startTypingMessage()
            }
            print("Accumulated Response: \(accumulatedResponse)")
        }
    }
    task.resume()
}

func cgEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if shouldBlockKeyboard {
            if keyCode == 53 { // Escape key
                NSApplication.shared.terminate(nil)
                return Unmanaged.passRetained(event) // Allow the event to pass through
            }
            return nil // Block all other key events
        }

        if let key = keyCodeToString(keyCode) {
            typedKeys.append(key)
            if typedKeys.hasSuffix("I hat") {
                let window = OverlayWindow()
                window.makeKeyAndOrderFront(nil)
                typedKeys = "" // Reset after activation
                shouldBlockKeyboard = true // Set flag to block keyboard
                runOllamaPrompt(window: window) // Call Ollama prompt function
                return nil // Block the event
            }
        }
    }
    return Unmanaged.passRetained(event) // Allow non-keyDown events to pass through
}

func keyCodeToString(_ keyCode: Int64) -> String? {
    let source = CGEventSource(stateID: .hidSystemState)
    let keyEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
    keyEvent?.flags = []

    var length = 1
    var chars: [UniChar] = [0]
    keyEvent?.keyboardGetUnicodeString(maxStringLength: 1, actualStringLength: &length, unicodeString: &chars)

    return String(utf16CodeUnits: chars, count: length)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let delegate = AppDelegate()
app.delegate = delegate
app.run()

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: OverlayWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = OverlayWindow()
        window?.makeKeyAndOrderFront(nil)
        setupEventTap()
    }

    func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(eventMask), callback: cgEventCallback, userInfo: nil)

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap!, enable: true)
    }
}
