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
struct MockNet: Network {
  mutating func fetch(url: String) -> String { "net: \(url)" }
}

func readViaFS(path: String) performs(FileSystem) -> String { "" } // expected-note {{declared here}}
func fetchViaNet(url: String) performs(Network) -> String { "" }
func readAndFetch(path: String, url: String) performs(FileSystem, Network) -> String { "" } // expected-note {{declared here}}

// --- ASTGen bridging (no crash) ---

func testBasic() {
  do {
    print("inside do...handle")
  } handle MockFS() as FileSystem
}

// --- Handler conformance ---

struct NotFileSystem {}
func testBadHandler() {
  do {
    print("bad handler body")
  } handle NotFileSystem() as FileSystem // expected-error {{handler of type 'NotFileSystem' does not conform to 'FileSystem'}}
}

func testNonEffect() {
  do {
    print("non-effect body")
  } handle "" as Equatable
  // expected-error @-1 {{type 'any Equatable' in handle clause does not conform to 'Effect'}}
}

// --- Effect narrowing via do...handle ---

// Narrowing in unannotated function
func testNarrowing() {
  do {
    let content = readViaFS(path: "test.txt")
    print("Narrowed:", content)
  } handle MockFS() as FileSystem
}

// Narrowing in performs(Never) function
func testNarrowingInNever() performs(Never) {
  do {
    let content = readViaFS(path: "test.txt")
    print("Pure context, narrowed:", content)
  } handle MockFS() as FileSystem
}

// Error without narrowing in performs(Never)
func testMissingNarrowing() performs(Never) {
  _ = readViaFS(path: "test.txt") // expected-error {{performs effects}}
}

// Nested narrowing (inner + outer handle blocks)
func testNestedNarrowing() performs(Never) {
  do {
    do {
      let result = readAndFetch(path: "f.txt", url: "http://x.com")
      print("Both handled:", result)
    } handle MockFS() as FileSystem
  } handle MockNet() as Network
}

// Partial narrowing — only Network handled, FileSystem missing
func testPartialNarrowing() performs(Never) {
  do {
    _ = readAndFetch(path: "f.txt", url: "http://x.com")
    // expected-error @-1 {{performs 'FileSystem'}}
  } handle MockNet() as Network
}

// Multiple handlers in one handle clause
func testMultipleHandlers() performs(Never) {
  do {
    let result = readAndFetch(path: "f.txt", url: "http://x.com")
    print("Multi-handler:", result)
  } handle MockFS() as FileSystem,
    MockNet() as Network
}

// Nested do...handle same effect — inner overrides outer
func testSameEffectNested() performs(Never) {
  do {
    do {
      let content = readViaFS(path: "test.txt")
      print("Inner handler:", content)
    } handle MockFS() as FileSystem
  } handle MockFS() as FileSystem
}
