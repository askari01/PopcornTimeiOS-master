

import Foundation

typealias DispatchCancelableBlock = (_ cancel: Bool) -> Void

extension DispatchQueue {
    
    func asyncAfter(delay: Double, execute block: @escaping () -> Void) -> DispatchCancelableBlock? {
        var originalBlock: (() -> Void)? = block
        var cancelableBlock: DispatchCancelableBlock? = nil
        let delayBlock: DispatchCancelableBlock = { (cancel: Bool) in
            if let originalBlock = originalBlock, !cancel {
                self.async(execute: originalBlock)
            }
            cancelableBlock = nil
            originalBlock = nil
        }
        cancelableBlock = delayBlock
        asyncAfter(deadline: .now() + delay, execute: {
            cancelableBlock?(false)
        })
        return cancelableBlock
    }
    
    @nonobjc private static var _onceTracker = [String]()
    
    /**
     Executes a block of code, associated with a unique token, only once.  The code is thread safe and will
     only execute the code once even in the presence of multithreaded calls.
     
     - Parameter token: A unique reverse DNS style name such as com.vectorform.<name> or a GUID. Defaults to device UUID.
     - Parameter block: Block to execute once
     */
    public class func once(token: String = UUID().uuidString, block: () -> Void) {
        objc_sync_enter(self); defer { objc_sync_exit(self) }
        
        if _onceTracker.contains(token) {
            return
        }
        
        _onceTracker.append(token)
        block()
    }
}
