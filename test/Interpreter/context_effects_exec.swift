// RUN: %target-run-simple-swift(-enable-experimental-feature ContextEffects) | %FileCheck %s
// REQUIRES: executable_test
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

// --- 'some' perform: zero-overhead witness dispatch ---

func readFileSome(at path: String) effects(FileSystem) -> String {
  withEffect { (fs: inout some FileSystem) in
    fs.readFile(at: path)
  }
}

// CHECK-LABEL: testSomePerform
func testSomePerform() {
  print("testSomePerform")
  let content: String
  do {
    content = readFileSome(at: "test.txt")
  } handle MockFS() as FileSystem
  // CHECK: mock: test.txt
  print(content)
}
testSomePerform()

// --- existential perform (no 'some') ---

func readFileExistential(at path: String) effects(FileSystem) -> String {
  withEffect { (fs: inout FileSystem) in
    fs.readFile(at: path)
  }
}

// CHECK-LABEL: testExistentialPerform
func testExistentialPerform() {
  print("testExistentialPerform")
  let content: String
  do {
    content = readFileExistential(at: "hello.txt")
  } handle MockFS() as FileSystem
  // CHECK: mock: hello.txt
  print(content)
}
testExistentialPerform()

// --- nested effects with two protocols ---

func fetchAndSave(url: String, to path: String) effects(FileSystem & Network) -> (String, String) {
  let data = withEffect { (net: inout some Network) in
    net.fetch(url: url)
  }
  let existing = withEffect { (fs: inout some FileSystem) in
    fs.readFile(at: path)
  }
  return (data, existing)
}

// CHECK-LABEL: testNestedHandlers
func testNestedHandlers() {
  print("testNestedHandlers")
  let result: (String, String)
  do {
    do {
      result = fetchAndSave(url: "http://example.com", to: "out.txt")
    } handle MockNet() as Network
  } handle MockFS() as FileSystem
  // CHECK: net: http://example.com -> mock: out.txt
  print(result.0 + " -> " + result.1)
}
testNestedHandlers()

// --- multi-handler single clause ---

// CHECK-LABEL: testMultiHandler
func testMultiHandler() {
  print("testMultiHandler")
  let result: (String, String)
  do {
    result = fetchAndSave(url: "http://api.test", to: "data.txt")
  } handle MockFS() as FileSystem,
    MockNet() as Network
  // CHECK: net: http://api.test -> mock: data.txt
  print(result.0 + " -> " + result.1)
}
testMultiHandler()

// --- handle provides effect for effects(Never) ---

// CHECK-LABEL: testHandleProvides
func testHandleProvides() {
  print("testHandleProvides")
  let content: String
  do {
    content = readFileSome(at: "safe.txt")
  } handle MockFS() as FileSystem
  // CHECK: mock: safe.txt
  print(content)
}
testHandleProvides()

// --- sequencing across multiple perform blocks ---

func readFileSomeAt(_ path: String) effects(FileSystem) -> String {
  withEffect { (fs: inout some FileSystem) in
    fs.readFile(at: path)
  }
}

// CHECK-LABEL: testSequencing
func testSequencing() {
  print("testSequencing")
  var results: [String] = []
  for path in ["a.txt", "b.txt", "c.txt"] {
    let content: String
    do {
      content = readFileSomeAt(path)
    } handle MockFS() as FileSystem
    results.append("\(path) -> \(content)")
  }
  for r in results { print(r) }
}
// CHECK: a.txt -> mock: a.txt
// CHECK: b.txt -> mock: b.txt
// CHECK: c.txt -> mock: c.txt
testSequencing()
