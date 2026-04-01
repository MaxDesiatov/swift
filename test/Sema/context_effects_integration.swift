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

// Full pipeline: withEffect inside effects function
func readFile(at path: String) effects(FileSystem) -> String { // expected-note {{declared here}}
  withEffect { (fs: inout FileSystem) in
    fs.readFile(at: path)
  }
}

// Callee with perform, handler at call site
func testCallWithHandler() {
  do {
    let content = readFile(at: "test.txt")
    _ = content
  } handle MockFS() as FileSystem
}

// Nested effects — two effects, two handles with sequencing
func fetchAndSave(url: String, to path: String) effects(FileSystem & Network) -> (String, String) {
  let data = withEffect { (net: inout Network) in
    net.fetch(url: url)
  }
  let existing = withEffect { (fs: inout FileSystem) in
    fs.readFile(at: path)
  }
  return (data, existing)
}

func testNestedHandlers() {
  do {
    do {
      let result = fetchAndSave(url: "http://example.com", to: "out.txt")
      _ = result
    } handle MockNet() as Network
  } handle MockFS() as FileSystem
}

// Multi-handler single clause — same operations, flat handle syntax
func testMultiHandlerClause() {
  do {
    let result = fetchAndSave(url: "http://example.com", to: "out.txt")
    _ = result
  } handle MockFS() as FileSystem,
    MockNet() as Network
}

// Error: perform for unhandled effect
func testUnhandledPerform() effects(FileSystem) {
  withEffect { (net: inout Network) in // expected-error {{effect 'Network' is not available}}
    print(net.fetch(url: "http://example.com"))
  }
}

// Error: calling effects function without handler in effects(Never)
func testMissingHandler() effects(Never) {
  _ = readFile(at: "test.txt") // expected-error {{has effects}}
}

// OK: handle provides the effect for effects(Never)
func testHandleProvides() effects(Never) {
  do {
    let content = readFile(at: "test.txt")
    _ = content
  } handle MockFS() as FileSystem
}

// Sequencing across multiple perform blocks in same function
func processFiles(paths: [String]) effects(FileSystem) {
  for path in paths {
    let content = withEffect { (fs: inout FileSystem) in
      fs.readFile(at: path)
    }
    _ = (path, content)
  }
}

func testSequencing() {
  do {
    processFiles(paths: ["a.txt", "b.txt", "c.txt"])
  } handle MockFS() as FileSystem
}
