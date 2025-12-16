import Cocoa
import Carbon

class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()
    var onHotKeyTriggered: (() -> Void)?
    
    private var hotKeyRef: EventHotKeyRef?
    
    private init() {}
    
    func register() {
        // Cmd + Shift + Space
        // kVK_Space = 0x31 (49)
        let keyCode = UInt32(0x31) // kVK_Space
        // cmdKey = 1 << 8 (256), shiftKey = 1 << 9 (512)
        let modifiers = UInt32(cmdKey | shiftKey)
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x534F4E55) // 'SONU'
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return
        }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, _, _) -> OSStatus in
            DispatchQueue.main.async {
                GlobalHotKeyService.shared.onHotKeyTriggered?()
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
