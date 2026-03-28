// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects -verify-ignore-unrelated
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
  mutating func readFile(at path: String) -> String
}
protocol Network: Effect {
  mutating func fetch(url: String) -> String
}
struct MockFS: FileSystem {
  mutating func readFile(at path: String) -> String { "mock: \(path)" }
}

// OK: perform with correct effect available via performs clause
func testPerformOK() performs(FileSystem) {
  let content = perform { (fs: inout FileSystem) in
    fs.readFile(at: "test.txt")
  }
  print("Read:", content)
}

// ERROR: perform with wrong effect
func testPerformWrongEffect() performs(Network) {
  perform { (fs: inout FileSystem) in // expected-error {{effect 'FileSystem' is not available}}
    print(fs.readFile(at: "test.txt"))
  }
}

// ERROR: perform in unannotated function (no handler, no performs clause)
func testPerformNoClause() {
  perform { (fs: inout FileSystem) in // expected-error {{effect 'FileSystem' is not available}}
    print(fs.readFile(at: "test.txt"))
  }
}

// OK: perform inside do...handle (narrowed)
func testPerformNarrowed() {
  do {
    let content = perform { (fs: inout FileSystem) in
      fs.readFile(at: "test.txt")
    }
    print("Narrowed read:", content)
  } handle MockFS() as FileSystem
}

// OK: perform return type propagation — result type is String
func testPerformReturnType() performs(FileSystem) {
  let first = perform { (fs: inout FileSystem) in
    fs.readFile(at: "a.txt")
  }
  let second = perform { (fs: inout FileSystem) in
    fs.readFile(at: "b.txt")
  }
  // Sequencing: both reads happen, results are used
  print("First:", first, "Second:", second)
}

// Closure effect typing is the immediate next step after Phase 1.4 (Phase 1.4b).
// Requires performs on AnyFunctionType, closure body validation, and call-site checking.
// For now, closures are opaque effect boundaries — perform inside a closure
// is not checked, and calling a closure doesn't propagate effects.

// OK: 'some' in perform closure param resolves to existential type
func testPerformSomeOK() performs(FileSystem) -> String {
  perform { (fs: inout some FileSystem) in
    fs.readFile(at: "test.txt")
  }
}

// OK: 'some' in perform closure inside do...handle
func testPerformSomeNarrowed() {
  do {
    let content = perform { (fs: inout some FileSystem) in
      fs.readFile(at: "test.txt")
    }
    print("Narrowed read:", content)
  } handle MockFS() as FileSystem
}

// ERROR: 'some' perform with wrong effect
func testPerformSomeWrongEffect() performs(Network) {
  perform { (fs: inout some FileSystem) in // expected-error {{effect 'FileSystem' is not available}}
    print(fs.readFile(at: "test.txt"))
  }
}
