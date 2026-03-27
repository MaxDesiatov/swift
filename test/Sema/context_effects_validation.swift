// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects

// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
    mutating func readFile(at path: String) -> String
}
protocol Network: Effect {
    mutating func fetch(url: String) -> String
}

func fsOnly() performs(FileSystem) {} // expected-note {{declared here}}
func netOnly() performs(Network) {} // expected-note {{declared here}}
func fsBoth() performs(FileSystem, Network) {} // expected-note 3 {{declared here}}
func pureFunc() performs(Never) {}
func unannotated() {}

// OK: exact match
func test1() performs(FileSystem) {
  fsOnly()
}

// OK: superset
func test2() performs(FileSystem, Network) {
  fsOnly()
}

// OK: superset calling both
func test2b() performs(FileSystem, Network) {
  fsBoth()
}

// ERROR: missing Network
func test3() performs(FileSystem) {
  fsBoth() // expected-error {{call to function that performs 'Network' is not allowed; enclosing function only performs 'FileSystem'}}
}

// ERROR: performs(Never) calling performs(FileSystem)
func test4() performs(Never) {
  fsOnly() // expected-error {{call to function that performs effects is not allowed in a 'performs(Never)' context}}
}

// OK: performs(Never) calling performs(Never)
func test5() performs(Never) {
  pureFunc()
}

// OK: performs(Never) calling unannotated
func test6() performs(Never) {
  unannotated()
}

// OK: unannotated calling anything (no restriction)
func test7() {
  fsOnly()
}

// OK: unannotated calling performs(Never)
func test8() {
  pureFunc()
}

// ERROR: Never mixed with other types
func testNeverMixed() performs(Never, FileSystem) {}
// expected-error @-1 {{'Never' cannot be combined with other types in a 'performs' clause}}

// ERROR: multiple missing effects — single compound error
protocol Logging: Effect {}
func needsThree() performs(FileSystem, Network, Logging) {} // expected-note {{declared here}}
func testMultiMissing() performs(FileSystem) {
  needsThree()
  // expected-error @-1 {{call to function that performs 'Network', 'Logging' is not allowed; enclosing function only performs 'FileSystem'}}
}

// ERROR: non-Effect protocol in performs clause
func testNonEffect() performs(Equatable) {}
// expected-error @-1 {{type 'any Equatable' in 'performs' clause does not conform to 'Effect'}}

// ERROR: non-protocol type in performs clause
func testNonProtocol() performs(Int) {}
// expected-error @-1 {{type 'Int' in 'performs' clause does not conform to 'Effect'}}

struct MyStruct {}
func testStruct() performs(MyStruct) {}
// expected-error @-1 {{type 'MyStruct' in 'performs' clause does not conform to 'Effect'}}

// Repeated calls — exercises cache, no duplicate diagnostics
func testRepeatedCalls() performs(FileSystem) {
  fsOnly()    // OK
  fsOnly()    // OK — exercises cache
  fsBoth()    // expected-error {{call to function that performs 'Network' is not allowed; enclosing function only performs 'FileSystem'}}
  fsBoth()    // expected-error {{call to function that performs 'Network' is not allowed; enclosing function only performs 'FileSystem'}}
}

// Autoclosure should be checked in caller's context
func takeAutoclosure(_ x: @autoclosure () -> Void) {}
func testAutoclosure() performs(FileSystem) {
  takeAutoclosure(netOnly())
  // expected-error @-1 {{call to function that performs 'Network' is not allowed; enclosing function only performs 'FileSystem'}}
}

// --- Additional coverage tests ---

// Method calls
struct S {
  func method() performs(FileSystem) {}
  static func staticMethod() performs(Network) {} // expected-note {{declared here}}
}
func testInstanceMethod(_ s: S) performs(FileSystem) {
  s.method()  // OK
}
func testStaticMethod() performs(FileSystem) {
  S.staticMethod()  // expected-error {{call to function that performs 'Network' is not allowed; enclosing function only performs 'FileSystem'}}
}

// Protocol requirements
protocol Performable {
  func doWork() performs(Network) // expected-note {{declared here}}
}
func testProtocolReq<T: Performable>(_ t: T) performs(FileSystem) {
  t.doWork()  // expected-error {{call to function that performs 'Network' is not allowed; enclosing function only performs 'FileSystem'}}
}

// Closure boundary — closures are genuine boundaries
func testClosureBoundary() performs(FileSystem) {
  let c = { netOnly() }  // OK — closure is boundary
  c()                     // OK — c() is opaque, no performs clause
}

// Nested functions
func testNestedFn() performs(FileSystem) {
  func inner() performs(FileSystem, Network) { // expected-note {{declared here}}
    fsBoth()  // OK
  }
  inner()  // expected-error {{call to function that performs 'Network' is not allowed; enclosing function only performs 'FileSystem'}}
}

// Recursive self-call
func testRecursive() performs(FileSystem) {
  testRecursive()  // OK
}

// Empty body
func testEmpty() performs(FileSystem) {}  // OK

// Type alias
typealias FS = FileSystem
func testAlias() performs(FS) {
  fsOnly()  // OK
}

// --- init() performs(...) ---

struct InitPerforms {
  init() performs(FileSystem) { fsOnly() } // expected-note {{declared here}}
}
func testInitPerforms() performs(Never) {
  _ = InitPerforms() // expected-error {{performs effects}}
}
