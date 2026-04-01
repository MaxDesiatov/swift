// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects

// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
    mutating func readFile(at path: String) -> String
}
protocol Network: Effect {
    mutating func fetch(url: String) -> String
}

func fsOnly() effects(FileSystem) {} // expected-note 2 {{declared here}}
func netOnly() effects(Network) {} // expected-note 5 {{declared here}}
func fsBoth() effects(FileSystem & Network) {} // expected-note 3 {{declared here}}
func pureFunc() effects(Never) {}
func unannotated() {}

// OK: exact match
func test1() effects(FileSystem) {
  fsOnly()
}

// OK: superset
func test2() effects(FileSystem & Network) {
  fsOnly()
}

// OK: superset calling both
func test2b() effects(FileSystem & Network) {
  fsBoth()
}

// ERROR: missing Network
func test3() effects(FileSystem) {
  fsBoth() // expected-error {{call to function that effects 'Network' is not allowed; enclosing function only effects 'FileSystem'}}
}

// ERROR: effects(Never) calling effects(FileSystem)
func test4() effects(Never) {
  fsOnly() // expected-error {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}

// OK: effects(Never) calling effects(Never)
func test5() effects(Never) {
  pureFunc()
}

// ERROR: effects(Never) calling unannotated
func test6() effects(Never) {
  unannotated() // expected-error {{call to 'unannotated()' is not allowed in a restricted effect context because it has no 'effects' clause}}
}

// OK: unannotated calling anything (no restriction)
func test7() {
  fsOnly()
}

// OK: unannotated calling effects(Never)
func test8() {
  pureFunc()
}

// ERROR: Never mixed with other types
func testNeverMixed() effects(Never & FileSystem) {}
// expected-error @-1 {{non-protocol, non-class type 'Never' cannot be used within a protocol-constrained type}}

// ERROR: multiple missing effects — single compound error
protocol Logging: Effect {}
func needsThree() effects(FileSystem & Network & Logging) {} // expected-note {{declared here}}
func testMultiMissing() effects(FileSystem) {
  needsThree()
  // expected-error @-1 {{call to function that effects 'Logging', 'Network' is not allowed; enclosing function only effects 'FileSystem'}}
}

// ERROR: non-Effect protocol in performs clause
func testNonEffect() effects(Equatable) {}
// expected-error @-1 {{type 'Equatable' in 'effects' clause does not conform to 'Effect'}}

// ERROR: non-protocol type in performs clause
func testNonProtocol() effects(Int) {}
// expected-error @-1 {{type 'Int' in 'effects' clause does not conform to 'Effect'}}

struct MyStruct {}
func testStruct() effects(MyStruct) {}
// expected-error @-1 {{type 'MyStruct' in 'effects' clause does not conform to 'Effect'}}

// Repeated calls — exercises cache, no duplicate diagnostics
func testRepeatedCalls() effects(FileSystem) {
  fsOnly()    // OK
  fsOnly()    // OK — exercises cache
  fsBoth()    // expected-error {{call to function that effects 'Network' is not allowed; enclosing function only effects 'FileSystem'}}
  fsBoth()    // expected-error {{call to function that effects 'Network' is not allowed; enclosing function only effects 'FileSystem'}}
}

// Autoclosure should be checked in caller's context
func takeAutoclosure(_ x: @autoclosure () -> Void) effects(FileSystem) {}
func testAutoclosure() effects(FileSystem) {
  takeAutoclosure(netOnly())
  // expected-error @-1 {{call to function that effects 'Network' is not allowed; enclosing function only effects 'FileSystem'}}
}

// --- Additional coverage tests ---

// Method calls
struct S {
  func method() effects(FileSystem) {}
  static func staticMethod() effects(Network) {} // expected-note {{declared here}}
}
func testInstanceMethod(_ s: S) effects(FileSystem) {
  s.method()  // OK
}
func testStaticMethod() effects(FileSystem) {
  S.staticMethod()  // expected-error {{call to function that effects 'Network' is not allowed; enclosing function only effects 'FileSystem'}}
}

// Protocol requirements
protocol Performable {
  func doWork() effects(Network) // expected-note {{declared here}}
}
func testProtocolReq<T: Performable>(_ t: T) effects(FileSystem) {
  t.doWork()  // expected-error {{call to function that effects 'Network' is not allowed; enclosing function only effects 'FileSystem'}}
}

// Closure boundary — unannotated closures are restricted in restricted contexts
func testClosureBoundary() effects(FileSystem) {
  let c = { netOnly() }  // OK — closure body is unannotated, not checked
  c()  // expected-error {{call to function without 'effects' clause is not allowed in a restricted effect context}}
}

// Nested functions
func testNestedFn() effects(FileSystem) {
  func inner() effects(FileSystem & Network) { // expected-note {{declared here}}
    fsBoth()  // OK
  }
  inner()  // expected-error {{call to function that effects 'Network' is not allowed; enclosing function only effects 'FileSystem'}}
}

// Recursive self-call
func testRecursive() effects(FileSystem) {
  testRecursive()  // OK
}

// Empty body
func testEmpty() effects(FileSystem) {}  // OK

// Type alias
typealias FS = FileSystem
func testAlias() effects(FS) {
  fsOnly()  // OK
}

// --- init() effects(...) ---

struct InitPerforms {
  init() effects(FileSystem) { fsOnly() } // expected-note {{declared here}}
}
func testInitPerforms() effects(Never) {
  _ = InitPerforms() // expected-error {{has effects}}
}

// --- Closure effect typing ---

// Calling a closure parameter with performs requires the effect
func testClosureCallParam(_ f: () effects(FileSystem) -> Void) effects(Never) {
  f() // expected-error {{has effects}}
}

// OK: calling in sufficient context
func testClosureCallOK(_ f: () effects(FileSystem) -> Void) effects(FileSystem) {
  f()
}

// OK: calling inside do...handle
func testClosureCallInDoHandle(_ f: () effects(FileSystem) -> Void) effects(Never) {
  do {
    f()
  } handle MockFS() as FileSystem
}

struct MockFS: FileSystem {
  init() effects(Never) {}
  mutating func readFile(at path: String) -> String { "mock" }
}
struct MockNet: Network {
  init() effects(Never) {}
  mutating func fetch(url: String) -> String { "mock" }
}

// Closure body with performs is checked for context effects
func testClosureBodyChecked() effects(FileSystem) {
  let c: () effects(FileSystem) -> Void = {
    netOnly()  // expected-error {{effects 'Network'}}
  }
  c()
}

// OK: closure body effects match
func testClosureBodyOK() effects(FileSystem) {
  let c: () effects(FileSystem) -> Void = {
    fsOnly()  // OK
  }
  c()
}

// Closure with effects(Never) — no effects allowed in body
func testClosureBodyNever() effects(FileSystem) {
  let c: () effects(Never) -> Void = {
    fsOnly()  // expected-error {{has effects}}
  }
  c()
}

// Higher-order: closure passed as performs parameter
func takesPerformsParam(_ f: () effects(FileSystem) -> Void) effects(FileSystem) { f() }
func testHigherOrderClosure() effects(FileSystem) {
  takesPerformsParam {
    netOnly()  // expected-error {{effects 'Network'}}
  }
}

// OK: higher-order with matching effects
func testHigherOrderClosureOK() effects(FileSystem) {
  takesPerformsParam {
    fsOnly()  // OK
  }
}

// Escaping closure allocates in effects(Never)
func testEscapingClosureAllocates() effects(Never) {
  let _ = { print("escaping") }
  // expected-error @-1 {{escaping closure requires allocation, which is not available in the current effect context}}
}

// Noescape closure doesn't allocate
func takeNoescape(_ f: () effects(Never) -> Void) effects(Never) { f() }
func testNoescapeClosure() effects(Never) {
  takeNoescape { _ = 42 }  // OK
}

// --- Function type performs validation ---

// ERROR: non-Effect protocol in function type performs clause
func testFnTypeNonEffect(_ f: () effects(Equatable) -> Void) {}
// expected-error @-1 {{does not conform to 'Effect'}}

// ERROR: non-protocol type in function type performs clause
func testFnTypeNonProtocol(_ f: () effects(Int) -> Void) {}
// expected-error @-1 {{does not conform to 'Effect'}}

// ERROR: struct type in function type performs clause
func testFnTypeStruct(_ f: () effects(MyStruct) -> Void) {}
// expected-error @-1 {{does not conform to 'Effect'}}

// --- Unannotated function type soundness ---

// ERROR: calling unannotated fn type from restricted context
func testUnrestrictedEscapingFnType(_ f: @escaping () -> Void) effects(Never) {
  f() // expected-error {{call to function without 'effects' clause is not allowed in a restricted effect context}}
}

// ERROR: even noescape unannotated fn type is restricted
func testUnrestrictedNoescapeFnType(_ f: () -> Void) effects(Never) {
  f() // expected-error {{call to function without 'effects' clause is not allowed in a restricted effect context}}
}

// OK: explicitly annotated effects(Never)
func testRestrictedFnType(_ f: () effects(Never) -> Void) effects(Never) {
  f() // OK
}

// --- Multi-effect function types ---

// Multiple effects in function type — missing one effect
func testMultiEffectFnType(
  _ f: () effects(FileSystem & Network) -> Void
) effects(FileSystem) {
  f() // expected-error {{effects 'Network'}}
}

// Superset context calling multi-effect closure — OK
func testMultiEffectFnTypeOK(
  _ f: () effects(FileSystem & Network) -> Void
) effects(FileSystem & Network) {
  f()
}

// Superset caller calling subset closure — OK
func testSupersetCallerSubsetClosure(
  _ f: () effects(FileSystem) -> Void
) effects(FileSystem & Network) {
  f() // OK — caller has FileSystem + Network, closure only needs FileSystem
}

// --- Nested closure effects (validates save/restore) ---

func testNestedClosureEffects() effects(FileSystem & Network) {
  let outer: () effects(FileSystem & Network) -> Void = {
    let inner: () effects(FileSystem) -> Void = {
      netOnly()  // expected-error {{effects 'Network'}}
    }
    inner()
    netOnly()  // OK — outer has FileSystem + Network, restore worked
  }
  outer()
}

// --- Multi-expression closure body ---

func testClosureBodyMultiExpr() effects(FileSystem & Network) {
  let c: () effects(FileSystem) -> Void = {
    fsOnly()    // OK
    netOnly()   // expected-error {{effects 'Network'}}
    fsOnly()    // OK — checking continues after error
  }
  c()
}

// --- Closure with wider effects than enclosing function ---

func testClosureWiderThanEnclosing() effects(FileSystem) {
  let c: () effects(FileSystem & Network) -> Void = {
    fsBoth()  // OK — closure has both FileSystem and Network
  }
  _ = c
}

// --- Escaping closure with performs in Never context ---

func testEscapingClosureWithPerformsInNever() effects(Never) {
  let _: () effects(FileSystem) -> Void = {
    // expected-error @-1 {{escaping closure requires allocation, which is not available in the current effect context}}
    fsOnly()  // OK within closure's effects(FileSystem) context
  }
}

// --- Combined effect specifiers ---

// performs with async and throws on function types — verify parsing+resolution
func testCombinedEffectsType(
  _ f: () effects(FileSystem) async throws -> Void
) {}
