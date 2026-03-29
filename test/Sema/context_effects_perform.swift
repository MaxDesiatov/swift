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
  _ = content
}

// ERROR: perform with wrong effect
func testPerformWrongEffect() performs(Network) {
  perform { (fs: inout FileSystem) in // expected-error {{effect 'FileSystem' is not available}}
    _ = fs.readFile(at: "test.txt")
  }
}

// ERROR: perform in unannotated function (no handler, no performs clause)
func testPerformNoClause() {
  perform { (fs: inout FileSystem) in // expected-error {{effect 'FileSystem' is not available}}
    _ = fs.readFile(at: "test.txt")
  }
}

// OK: perform inside do...handle (narrowed)
func testPerformNarrowed() {
  do {
    let content = perform { (fs: inout FileSystem) in
      fs.readFile(at: "test.txt")
    }
    _ = content
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
  _ = (first, second)
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
    _ = content
  } handle MockFS() as FileSystem
}

// ERROR: 'some' perform with wrong effect
func testPerformSomeWrongEffect() performs(Network) {
  perform { (fs: inout some FileSystem) in // expected-error {{effect 'FileSystem' is not available}}
    _ = fs.readFile(at: "test.txt")
  }
}

// ERROR: 'some' in standalone closure variable (not a perform expression)
func testSomeStandaloneClosure() performs(FileSystem) {
  let _ = { (fs: inout some FileSystem) in // expected-error {{'some' in closure parameters is only allowed in 'perform' expressions}}
    print(fs)
  }
}

// ERROR: 'some' in closure passed as argument (not perform)
func takeClosure(_ f: (inout any FileSystem) -> Void) performs(Never) {}
func testSomeClosureArg() performs(FileSystem) {
  takeClosure { (fs: inout some FileSystem) in // expected-error {{'some' in closure parameters is only allowed in 'perform' expressions}}
    print(fs)
  }
}

// ERROR: 'some' in closure inside do...handle (not via perform)
func testSomeInDoHandle() {
  do {
    let _ = { (fs: inout some FileSystem) in // expected-error {{'some' in closure parameters is only allowed in 'perform' expressions}}
      print(fs)
    }
  } handle MockFS() as FileSystem
}

struct MockNetwork: Network {
  mutating func fetch(url: String) -> String { "mock: \(url)" }
}

// OK: nested perform — inner closure IS a perform closure
func testNestedPerform() performs(FileSystem & Network) {
  perform { (net: inout Network) in
    let _ = perform { (fs: inout some FileSystem) in
      fs.readFile(at: "test.txt")
    }
    print(net.fetch(url: "http://example.com"))
  }
}

// OK: perform with 'some' but no 'inout' specifier
func testPerformSomeNoInout() performs(FileSystem) {
  perform { (fs: some FileSystem) in
    print(fs)
  }
}

// OK: perform with multiple 'some' params
func testPerformMultipleSomeParams() performs(FileSystem & Network) {
  perform { (fs: inout some FileSystem) in
    print(fs.readFile(at: "test.txt"))
  }
}

// ERROR: 'some' with non-protocol type
func testSomeNonProtocol() performs(FileSystem) {
  let _ = { (x: some Int) in // expected-error {{'some' types are only permitted in properties, subscripts, and functions}}
    print(x)
  }
}
