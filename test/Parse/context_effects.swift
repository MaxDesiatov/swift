// RUN: %target-swift-frontend -dump-parse %s -enable-experimental-feature ContextEffects 2>&1 | %FileCheck %s

// REQUIRES: swift_feature_ContextEffects

protocol Effect {}

protocol FileSystem: Effect {
    mutating func readFile(at path: String) -> String
}

struct MockFS: FileSystem {
    mutating func readFile(at path: String) -> String { "mock" }
}

// CHECK: func_decl{{.*}}"readFile(at:)"
func readFile(at path: String) performs(FileSystem) -> String {
    // CHECK: perform_expr
    perform { (fs: inout FileSystem) in
        fs.readFile(at: path)
    }
}

// CHECK: func_decl{{.*}}"pureAdd
func pureAdd(_ a: Int, _ b: Int) performs(Never) -> Int { a + b }

// CHECK: do_handle_stmt
// CHECK: handle_clause
do {
    let _ = readFile(at: "test.txt")
} handle MockFS() as FileSystem

// Function type with performs clause
// CHECK: type_function
let _: () performs(FileSystem) -> Void

// Function taking a performs-annotated function type parameter
// CHECK: func_decl{{.*}}"takesPerformsFS
func takesPerformsFS(_ f: () performs(FileSystem) -> Void) {}

