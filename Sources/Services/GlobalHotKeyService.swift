import Cocoa
import Carbon

class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()
    var onHotKeyTriggered: (() -> Void)?
    
    private var hotKeyRef: EventHotKeyRef?
    
    private init() {}
    
    func register() {
        unregister()
        // Defaults: Cmd + Shift + Space
        let storedKeyCode = UserDefaults.standard.integer(forKey: "hotkey.code")
        let storedModifiers = UserDefaults.standard.integer(forKey: "hotkey.modifiers")
        let keyCode = storedKeyCode == 0 ? Int(kVK_Space) : storedKeyCode
        let modifiers = storedModifiers == 0 ? Int(cmdKey | shiftKey) : storedModifiers

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x534F4E55) // 'SONU'
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
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
