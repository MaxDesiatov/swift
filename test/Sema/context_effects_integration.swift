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

// Full pipeline: perform inside performs function
func readFile(at path: String) performs(FileSystem) -> String { // expected-note {{declared here}}
  perform { (fs: inout FileSystem) in
    fs.readFile(at: path)
  }
}

// Callee with perform, handler at call site
func testCallWithHandler() {
  do {
    let content = readFile(at: "test.txt")
    print("Handler provided:", content)
  } handle MockFS() as FileSystem
}

// Nested effects — two performs, two handles with sequencing
func fetchAndSave(url: String, to path: String) performs(FileSystem, Network) -> String {
  let data = perform { (net: inout Network) in
    net.fetch(url: url)
  }
  let existing = perform { (fs: inout FileSystem) in
    fs.readFile(at: path)
  }
  // Verify sequencing: fetch happens before read, both results available
  print("Fetched:", data)
  print("Existing:", existing)
  return data + " -> " + existing
}

func testNestedHandlers() {
  do {
    do {
      let result = fetchAndSave(url: "http://example.com", to: "out.txt")
      print("Combined:", result)
    } handle MockNet() as Network
  } handle MockFS() as FileSystem
}

// Multi-handler single clause — same operations, flat handle syntax
func testMultiHandlerClause() {
  do {
    let result = fetchAndSave(url: "http://example.com", to: "out.txt")
    print("Multi-handler:", result)
  } handle MockFS() as FileSystem,
    MockNet() as Network
}

// Error: perform for unhandled effect
func testUnhandledPerform() performs(FileSystem) {
  perform { (net: inout Network) in // expected-error {{effect 'Network' is not available}}
    print(net.fetch(url: "http://example.com"))
  }
}

// Error: calling performs function without handler in performs(Never)
func testMissingHandler() performs(Never) {
  _ = readFile(at: "test.txt") // expected-error {{performs effects}}
}

// OK: handle provides the effect for performs(Never)
func testHandleProvides() performs(Never) {
  do {
    let content = readFile(at: "test.txt")
    print("Pure + handled:", content)
  } handle MockFS() as FileSystem
}

// Sequencing across multiple perform blocks in same function
func processFiles(paths: [String]) performs(FileSystem) {
  for path in paths {
    let content = perform { (fs: inout FileSystem) in
      fs.readFile(at: path)
    }
    print("Processing:", path, "->", content)
  }
}

func testSequencing() {
  do {
    processFiles(paths: ["a.txt", "b.txt", "c.txt"])
  } handle MockFS() as FileSystem
}
