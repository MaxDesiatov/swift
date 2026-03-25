// RUN: %target-swift-frontend -dump-parse %s -enable-experimental-feature ContextEffects 2>&1 | %FileCheck %s

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
} handle MockFS() as FileSystem

// Multiple handle clauses (comma separated)
// CHECK: do_handle_stmt
// CHECK: handle_clause
// CHECK: handle_clause
do {
    let _ = 1
} handle MockFS() as FileSystem,
         MockNet() as Network

// Nested: do/handle inside do/catch
do {
    do {
        let _ = 1
    } handle MockFS() as FileSystem
} catch {
    let _ = error
}
