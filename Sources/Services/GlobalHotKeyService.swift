import Cocoa
import Carbon

class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()
    var onHotKeyTriggered: (() -> Void)?
    var onAssistantHotKeyTriggered: (() -> Void)?
    
    private var hotKeyRef: EventHotKeyRef?
    private var assistantHotKeyRef: EventHotKeyRef?
    
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
    
    func registerAssistantHotKey() {
        unregisterAssistantHotKey()
        
        // Option + Space для AI ассистента
        let keyCode = Int(kVK_Space)
        let modifiers = Int(optionKey)
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x41495354) // 'AIST'
        hotKeyID.id = 2
        
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &assistantHotKeyRef)
        
        if status != noErr {
            print("Failed to register assistant hotkey: \(status)")
            return
        }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, inEvent, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(inEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            DispatchQueue.main.async {
                if hotKeyID.id == 2 {
                    GlobalHotKeyService.shared.onAssistantHotKeyTriggered?()
                } else if hotKeyID.id == 1 {
                    GlobalHotKeyService.shared.onHotKeyTriggered?()
                }
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
    
    func unregisterAssistantHotKey() {
        if let assistantHotKeyRef = assistantHotKeyRef {
            UnregisterEventHotKey(assistantHotKeyRef)
            self.assistantHotKeyRef = nil
        }
    }
}
