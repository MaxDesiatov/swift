// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects

// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
    mutating func readFile(at path: String) -> String
}
protocol Network: Effect {
    mutating func fetch(url: String) -> String
}

func fsOnly() performs(FileSystem) {} // expected-note 2 {{declared here}}
func netOnly() performs(Network) {} // expected-note 5 {{declared here}}
func fsBoth() performs(FileSystem & Network) {} // expected-note 3 {{declared here}}
func pureFunc() performs(Never) {}
func unannotated() {}

// OK: exact match
func test1() performs(FileSystem) {
  fsOnly()
}

// OK: superset
func test2() performs(FileSystem & Network) {
  fsOnly()
}

// OK: superset calling both
func test2b() performs(FileSystem & Network) {
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

// ERROR: performs(Never) calling unannotated
func test6() performs(Never) {
  unannotated() // expected-error {{call to 'unannotated()' is not allowed in a restricted effect context because it has no 'performs' clause}}
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
func testNeverMixed() performs(Never & FileSystem) {}
// expected-error @-1 {{non-protocol, non-class type 'Never' cannot be used within a protocol-constrained type}}

// ERROR: multiple missing effects — single compound error
protocol Logging: Effect {}
func needsThree() performs(FileSystem & Network & Logging) {} // expected-note {{declared here}}
func testMultiMissing() performs(FileSystem) {
  needsThree()
  // expected-error @-1 {{call to function that performs 'Logging', 'Network' is not allowed; enclosing function only performs 'FileSystem'}}
}

// ERROR: non-Effect protocol in performs clause
func testNonEffect() performs(Equatable) {}
// expected-error @-1 {{type 'Equatable' in 'performs' clause does not conform to 'Effect'}}

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
func takeAutoclosure(_ x: @autoclosure () -> Void) performs(FileSystem) {}
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
  func inner() performs(FileSystem & Network) { // expected-note {{declared here}}
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
  init() performs(Never) {}
  mutating func readFile(at path: String) -> String { "mock" }
}
struct MockNet: Network {
  init() performs(Never) {}
  mutating func fetch(url: String) -> String { "mock" }
}

// Closure body with performs is checked for context effects
func testClosureBodyChecked() performs(FileSystem) {
  let c: () performs(FileSystem) -> Void = {
    netOnly()  // expected-error {{performs 'Network'}}
  }
  c()
}

// OK: closure body effects match
func testClosureBodyOK() performs(FileSystem) {
  let c: () performs(FileSystem) -> Void = {
    fsOnly()  // OK
  }
  c()
}

// Closure with performs(Never) — no effects allowed in body
func testClosureBodyNever() performs(FileSystem) {
  let c: () performs(Never) -> Void = {
    fsOnly()  // expected-error {{performs effects}}
  }
  c()
}

// Higher-order: closure passed as performs parameter
func takesPerformsParam(_ f: () performs(FileSystem) -> Void) performs(FileSystem) { f() }
func testHigherOrderClosure() performs(FileSystem) {
  takesPerformsParam {
    netOnly()  // expected-error {{performs 'Network'}}
  }
}

// OK: higher-order with matching effects
func testHigherOrderClosureOK() performs(FileSystem) {
  takesPerformsParam {
    fsOnly()  // OK
  }
}

// Escaping closure allocates in performs(Never)
func testEscapingClosureAllocates() performs(Never) {
  let _ = { print("escaping") }
  // expected-error @-1 {{escaping closure requires allocation, which is not available in the current effect context}}
}

// Noescape closure doesn't allocate
func takeNoescape(_ f: () performs(Never) -> Void) performs(Never) { f() }
func testNoescapeClosure() performs(Never) {
  takeNoescape { _ = 42 }  // OK
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
  _ f: () performs(FileSystem & Network) -> Void
) performs(FileSystem) {
  f() // expected-error {{performs 'Network'}}
}

// Superset context calling multi-effect closure — OK
func testMultiEffectFnTypeOK(
  _ f: () performs(FileSystem & Network) -> Void
) performs(FileSystem & Network) {
  f()
}

// Superset caller calling subset closure — OK
func testSupersetCallerSubsetClosure(
  _ f: () performs(FileSystem) -> Void
) performs(FileSystem & Network) {
  f() // OK — caller has FileSystem + Network, closure only needs FileSystem
}

// --- Nested closure effects (validates save/restore) ---

func testNestedClosureEffects() performs(FileSystem & Network) {
  let outer: () performs(FileSystem & Network) -> Void = {
    let inner: () performs(FileSystem) -> Void = {
      netOnly()  // expected-error {{performs 'Network'}}
    }
    inner()
    netOnly()  // OK — outer has FileSystem + Network, restore worked
  }
  outer()
}

// --- Multi-expression closure body ---

func testClosureBodyMultiExpr() performs(FileSystem & Network) {
  let c: () performs(FileSystem) -> Void = {
    fsOnly()    // OK
    netOnly()   // expected-error {{performs 'Network'}}
    fsOnly()    // OK — checking continues after error
  }
  c()
}

// --- Closure with wider effects than enclosing function ---

func testClosureWiderThanEnclosing() performs(FileSystem) {
  let c: () performs(FileSystem & Network) -> Void = {
    fsBoth()  // OK — closure has both FileSystem and Network
  }
  _ = c
}

// --- Escaping closure with performs in Never context ---

func testEscapingClosureWithPerformsInNever() performs(Never) {
  let _: () performs(FileSystem) -> Void = {
    // expected-error @-1 {{escaping closure requires allocation, which is not available in the current effect context}}
    fsOnly()  // OK within closure's performs(FileSystem) context
  }
}

// --- Combined effect specifiers ---

// performs with async and throws on function types — verify parsing+resolution
func testCombinedEffectsType(
  _ f: () performs(FileSystem) async throws -> Void
) {}
