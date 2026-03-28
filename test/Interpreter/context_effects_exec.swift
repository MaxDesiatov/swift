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
  mutating func readFile(at path: String) -> String { "mock: \(path)" }
}
struct MockNet: Network {
  mutating func fetch(url: String) -> String { "net: \(url)" }
}

// --- 'some' perform: zero-overhead witness dispatch ---

func readFileSome(at path: String) performs(FileSystem) -> String {
  perform { (fs: inout some FileSystem) in
    fs.readFile(at: path)
  }
}

// CHECK-LABEL: testSomePerform
func testSomePerform() {
  print("testSomePerform")
  do {
    let content = readFileSome(at: "test.txt")
    // CHECK: mock: test.txt
    print(content)
  } handle MockFS() as FileSystem
}
testSomePerform()

// --- existential perform (no 'some') ---

func readFileExistential(at path: String) performs(FileSystem) -> String {
  perform { (fs: inout FileSystem) in
    fs.readFile(at: path)
  }
}

// CHECK-LABEL: testExistentialPerform
func testExistentialPerform() {
  print("testExistentialPerform")
  do {
    let content = readFileExistential(at: "hello.txt")
    // CHECK: mock: hello.txt
    print(content)
  } handle MockFS() as FileSystem
}
testExistentialPerform()

// --- nested effects with two protocols ---

func fetchAndSave(url: String, to path: String) performs(FileSystem, Network) -> String {
  let data = perform { (net: inout some Network) in
    net.fetch(url: url)
  }
  let existing = perform { (fs: inout some FileSystem) in
    fs.readFile(at: path)
  }
  return data + " -> " + existing
}

// CHECK-LABEL: testNestedHandlers
func testNestedHandlers() {
  print("testNestedHandlers")
  do {
    do {
      let result = fetchAndSave(url: "http://example.com", to: "out.txt")
      // CHECK: net: http://example.com -> mock: out.txt
      print(result)
    } handle MockNet() as Network
  } handle MockFS() as FileSystem
}
testNestedHandlers()

// --- multi-handler single clause ---

// CHECK-LABEL: testMultiHandler
func testMultiHandler() {
  print("testMultiHandler")
  do {
    let result = fetchAndSave(url: "http://api.test", to: "data.txt")
    // CHECK: net: http://api.test -> mock: data.txt
    print(result)
  } handle MockFS() as FileSystem,
    MockNet() as Network
}
testMultiHandler()

// --- handle provides effect for performs(Never) ---

// CHECK-LABEL: testHandleProvides
func testHandleProvides() {
  print("testHandleProvides")
  do {
    let content = readFileSome(at: "safe.txt")
    // CHECK: mock: safe.txt
    print(content)
  } handle MockFS() as FileSystem
}
testHandleProvides()

// --- sequencing across multiple perform blocks ---

func processFiles(paths: [String]) performs(FileSystem) {
  for path in paths {
    let content = perform { (fs: inout some FileSystem) in
      fs.readFile(at: path)
    }
    print(path, "->", content)
  }
}

// CHECK-LABEL: testSequencing
func testSequencing() {
  print("testSequencing")
  do {
    processFiles(paths: ["a.txt", "b.txt", "c.txt"])
  } handle MockFS() as FileSystem
}
// CHECK: a.txt -> mock: a.txt
// CHECK: b.txt -> mock: b.txt
// CHECK: c.txt -> mock: c.txt
testSequencing()
