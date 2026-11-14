import CoreGraphics
import Foundation

/// Private display APIs, resolved at runtime with dlsym so the build never
/// links against private frameworks. If Apple removes a symbol, the
/// corresponding function returns nil instead of crashing at launch.
enum PrivateAPI {
    // CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool)
    typealias ConfigureDisplayEnabledFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError
    // CGError CGSGetDisplayList(uint32_t max, CGDirectDisplayID *list, uint32_t *count)
    typealias GetDisplayListFn = @convention(c) (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError
    // CGError SLSDetectDisplays(void)
    typealias DetectDisplaysFn = @convention(c) () -> CGError

    private static let coreGraphics = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY)
    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer?, _ name: String, as: T.Type) -> T? {
        guard let handle, let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    static let configureDisplayEnabled = symbol(coreGraphics, "CGSConfigureDisplayEnabled", as: ConfigureDisplayEnabledFn.self)
    static let getDisplayList = symbol(coreGraphics, "CGSGetDisplayList", as: GetDisplayListFn.self)
    static let detectDisplays = symbol(skyLight, "SLSDetectDisplays", as: DetectDisplaysFn.self)
}
