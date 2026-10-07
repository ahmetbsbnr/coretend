import Foundation

// An app extension's entry point is Foundation's NSExtensionMain, which loads the principal class
// named in the Info.plist. Xcode links it with `-e _NSExtensionMain`; SwiftPM needs a main.
@_silgen_name("NSExtensionMain")
func NSExtensionMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32

exit(NSExtensionMain(CommandLine.argc, CommandLine.unsafeArgv))
