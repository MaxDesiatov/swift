// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects

// REQUIRES: swift_feature_ContextEffects

// Effect is a @_marker protocol in the standard library.
// Protocols can conform to it to mark themselves as "effect protocols."

protocol FileSystem: Effect {
    mutating func readFile(at path: String) -> String
}

struct MockFS: FileSystem {
    mutating func readFile(at path: String) -> String { "mock" }
}
