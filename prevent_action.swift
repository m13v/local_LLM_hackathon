import Cocoa
import CoreGraphics

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
            if typedKeys.hasSuffix("git push") {
                let window = OverlayWindow()
                window.makeKeyAndOrderFront(nil)
                typedKeys = "" // Reset after activation
                shouldBlockKeyboard = true // Set flag to block keyboard
                return nil // Block the event
            }
        }
    }
    return Unmanaged.passRetained(event) // Allow non-keyDown events to pass through
}

func keyCodeToString(_ keyCode: Int64) -> String? {
    switch keyCode {
    case 0: return "a"
    case 1: return "s"
    case 2: return "d"
    case 3: return "f"
    case 4: return "h"
    case 5: return "g"
    case 6: return "z"
    case 7: return "x"
    case 8: return "c"
    case 9: return "v"
    case 11: return "b"
    case 12: return "q"
    case 13: return "w"
    case 14: return "e"
    case 15: return "r"
    case 16: return "y"
    case 17: return "t"
    case 18: return "1"
    case 19: return "2"
    case 20: return "3"
    case 21: return "4"
    case 22: return "6"
    case 23: return "5"
    case 24: return "="
    case 25: return "9"
    case 26: return "7"
    case 27: return "-"
    case 28: return "8"
    case 29: return "0"
    case 30: return "]"
    case 31: return "o"
    case 32: return "u"
    case 33: return "["
    case 34: return "i"
    case 35: return "p"
    case 37: return "l"
    case 38: return "j"
    case 39: return "'"
    case 40: return "k"
    case 41: return ";"
    case 42: return "\\"
    case 43: return ","
    case 44: return "/"
    case 45: return "n"
    case 46: return "m"
    case 47: return "."
    case 50: return "`"
    case 65: return "<"
    case 67: return "*"
    case 69: return "+"
    case 71: return "clear"
    case 75: return "/"
    case 76: return "return"
    case 78: return "-"
    case 81: return "="
    case 82: return "0"
    case 83: return "1"
    case 84: return "2"
    case 85: return "3"
    case 86: return "4"
    case 87: return "5"
    case 88: return "6"
    case 89: return "7"
    case 91: return "8"
    case 92: return "9"
    case 36: return "return"
    case 49: return " "
    default: return nil
    }
}

let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                       place: .headInsertEventTap,
                                       options: .defaultTap,
                                       eventsOfInterest: CGEventMask(eventMask),
                                       callback: cgEventCallback,
                                       userInfo: nil) else {
    print("Failed to create event tap")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

NSApplication.shared.run()