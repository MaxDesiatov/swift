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

// Closure boundary — unannotated closures are restricted in restricted contexts
func testClosureBoundary() performs(FileSystem) {
  let c = { netOnly() }  // OK — closure body is unannotated, not checked
  c()  // expected-error {{call to function without 'performs' clause is not allowed in a restricted effect context}}
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

// --- Closure effect typing ---

// Calling a closure parameter with performs requires the effect
func testClosureCallParam(_ f: () performs(FileSystem) -> Void) performs(Never) {
  f() // expected-error {{performs effects}}
}

// OK: calling in sufficient context
func testClosureCallOK(_ f: () performs(FileSystem) -> Void) performs(FileSystem) {
  f()
}

// OK: calling inside do...handle
func testClosureCallInDoHandle(_ f: () performs(FileSystem) -> Void) performs(Never) {
  do {
    f()
  } handle MockFS() as FileSystem
}

struct MockFS: FileSystem {
  mutating func readFile(at path: String) -> String { "mock" }
}
struct MockNet: Network {
  mutating func fetch(url: String) -> String { "mock" }
}

// Closure body with performs is checked for context effects
// NOTE: This requires constraint solver support for performedEffects
// propagation to closures, which is Phase 1.4c work.
// func testClosureBodyChecked() {
//   let _: () performs(FileSystem) -> Void = {
//     netOnly()
//   }
// }

// Escaping closure allocates in performs(Never)
func testEscapingClosureAllocates() performs(Never) {
  let _ = { print("escaping") }
  // expected-error @-1 {{escaping closure requires allocation, which is not available in the current effect context}}
}

// Noescape closure doesn't allocate
func takeNoescape(_ f: () performs(Never) -> Void) performs(Never) { f() }
func testNoescapeClosure() performs(Never) {
  takeNoescape { print("noescape") }  // OK
}

// --- Function type performs validation ---

// ERROR: non-Effect protocol in function type performs clause
func testFnTypeNonEffect(_ f: () performs(Equatable) -> Void) {}
// expected-error @-1 {{does not conform to 'Effect'}}

// ERROR: non-protocol type in function type performs clause
func testFnTypeNonProtocol(_ f: () performs(Int) -> Void) {}
// expected-error @-1 {{does not conform to 'Effect'}}

// ERROR: struct type in function type performs clause
func testFnTypeStruct(_ f: () performs(MyStruct) -> Void) {}
// expected-error @-1 {{does not conform to 'Effect'}}

// --- Unannotated function type soundness ---

// ERROR: calling unannotated fn type from restricted context
func testUnrestrictedEscapingFnType(_ f: @escaping () -> Void) performs(Never) {
  f() // expected-error {{call to function without 'performs' clause is not allowed in a restricted effect context}}
}

// ERROR: even noescape unannotated fn type is restricted
func testUnrestrictedNoescapeFnType(_ f: () -> Void) performs(Never) {
  f() // expected-error {{call to function without 'performs' clause is not allowed in a restricted effect context}}
}

// OK: explicitly annotated performs(Never)
func testRestrictedFnType(_ f: () performs(Never) -> Void) performs(Never) {
  f() // OK
}

// --- Multi-effect function types ---

// Multiple effects in function type — missing one effect
func testMultiEffectFnType(
  _ f: () performs(FileSystem, Network) -> Void
) performs(FileSystem) {
  f() // expected-error {{performs 'Network'}}
}

// Superset context calling multi-effect closure — OK
func testMultiEffectFnTypeOK(
  _ f: () performs(FileSystem, Network) -> Void
) performs(FileSystem, Network) {
  f()
}

// Superset caller calling subset closure — OK
func testSupersetCallerSubsetClosure(
  _ f: () performs(FileSystem) -> Void
) performs(FileSystem, Network) {
  f() // OK — caller has FileSystem + Network, closure only needs FileSystem
}

// --- Combined effect specifiers ---

// performs with async and throws on function types — verify parsing+resolution
func testCombinedEffectsType(
  _ f: () performs(FileSystem) async throws -> Void
) {}
