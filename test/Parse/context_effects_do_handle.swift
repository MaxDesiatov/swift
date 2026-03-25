// RUN: %target-swift-frontend -dump-parse %s -enable-experimental-feature ContextEffects -disable-experimental-parser-round-trip 2>&1 | %FileCheck %s

// REQUIRES: swift_feature_ContextEffects

protocol Effect {}
protocol FileSystem: Effect {
    mutating func readFile(at path: String) -> String
}
protocol Network: Effect {}

struct MockFS: FileSystem {
    mutating func readFile(at path: String) -> String { "mock" }
}
struct MockNet: Network {}

// Single handle clause
// CHECK: do_handle_stmt
// CHECK: handle_clause
do {
    let _ = 1
} handle FileSystem with MockFS()

// Multiple handle clauses
// CHECK: do_handle_stmt
// CHECK: handle_clause
// CHECK: handle_clause
do {
    let _ = 1
} handle FileSystem with MockFS()
  handle Network with MockNet()

// Nested: do/handle inside do/catch
do {
    do {
        let _ = 1
    } handle FileSystem with MockFS()
} catch {
    let _ = error
}
