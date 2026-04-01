// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects -verify-ignore-unrelated
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
  mutating func readFile(at path: String) -> String
}
protocol Network: Effect {
  mutating func fetch(url: String) -> String
}
struct MockFS: FileSystem {
  init() effects(Never) {}
  mutating func readFile(at path: String) -> String { "mock: \(path)" }
}
struct MockNet: Network {
  init() effects(Never) {}
  mutating func fetch(url: String) -> String { "net: \(url)" }
}

func readViaFS(path: String) effects(FileSystem) -> String { "" } // expected-note {{declared here}}
func fetchViaNet(url: String) effects(Network) -> String { "" }
func readAndFetch(path: String, url: String) effects(FileSystem & Network) -> String { "" } // expected-note 2 {{declared here}}
func createFSFromNet() effects(Network) -> MockFS { MockFS() } // expected-note {{declared here}}

// --- ASTGen bridging (no crash) ---

func testBasic() {
  do {
    _ = "inside do...handle"
  } handle MockFS() as FileSystem
}

// --- Handler conformance ---

struct NotFileSystem {}
func testBadHandler() {
  do {
    _ = "bad handler body"
  } handle NotFileSystem() as FileSystem // expected-error {{handler of type 'NotFileSystem' does not conform to 'FileSystem'}}
}

func testNonEffect() {
  do {
    _ = "non-effect body"
  } handle "" as Equatable
  // expected-error @-1 {{type 'any Equatable' in handle clause does not conform to 'Effect'}}
}

// --- Effect narrowing via do...handle ---

// Narrowing in unannotated function
func testNarrowing() {
  do {
    let content = readViaFS(path: "test.txt")
    _ = content
  } handle MockFS() as FileSystem
}

// Narrowing in effects(Never) function
func testNarrowingInNever() effects(Never) {
  do {
    let content = readViaFS(path: "test.txt")
    _ = content
  } handle MockFS() as FileSystem
}

// Error without narrowing in effects(Never)
func testMissingNarrowing() effects(Never) {
  _ = readViaFS(path: "test.txt") // expected-error {{has effects}}
}

// Nested narrowing (inner + outer handle blocks)
func testNestedNarrowing() effects(Never) {
  do {
    do {
      let result = readAndFetch(path: "f.txt", url: "http://x.com")
      _ = result
    } handle MockFS() as FileSystem
  } handle MockNet() as Network
}

// Partial narrowing — only Network handled, FileSystem missing
func testPartialNarrowing() effects(Never) {
  do {
    _ = readAndFetch(path: "f.txt", url: "http://x.com")
    // expected-error @-1 {{effects 'FileSystem'}}
  } handle MockNet() as Network
}

// Multiple handlers in one handle clause
func testMultipleHandlers() effects(Never) {
  do {
    let result = readAndFetch(path: "f.txt", url: "http://x.com")
    _ = result
  } handle MockFS() as FileSystem,
    MockNet() as Network
}

// Nested do...handle same effect — inner overrides outer
func testSameEffectNested() effects(Never) {
  do {
    do {
      let content = readViaFS(path: "test.txt")
      _ = content
    } handle MockFS() as FileSystem
  } handle MockFS() as FileSystem
}

// --- Handler expression effect checking ---

// Handler expression that has effects should be checked in outer context
func testHandlerExprPerforms() effects(Never) {
  do {
    let content = readViaFS(path: "test.txt")
    _ = content
  } handle createFSFromNet() as FileSystem
  // expected-error @-1 {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}

// --- Labeled do...handle ---

func testLabeledDoHandle() {
  label: do {
    let content = readViaFS(path: "test.txt")
    _ = content
  } handle MockFS() as FileSystem
}

// --- Empty do...handle body ---

func testEmptyDoHandle() {
  do { } handle MockFS() as FileSystem
}

// --- do effects(E) — constrains the body ---

func testDoPerforms() effects(Never) {
  do effects(FileSystem) {
    let content = readViaFS(path: "test.txt")
    _ = content
  } handle MockFS() as FileSystem
}

// do effects(E) — body uses undeclared effect → error
func testDoPerformsUndeclared() effects(Never) {
  do effects(FileSystem) {
    _ = readAndFetch(path: "f.txt", url: "http://x.com")
    // expected-error @-1 {{effects 'Network'}}
  } handle MockFS() as FileSystem,
    MockNet() as Network
}

// do effects(E) — missing handler for declared effect → error
func testDoPerformsMissingHandler() effects(Never) {
  do effects(FileSystem & Network) { // expected-error {{effect 'Network' declared in 'effects' clause has no handler}}
    let content = readViaFS(path: "test.txt")
    _ = content
  } handle MockFS() as FileSystem
}
