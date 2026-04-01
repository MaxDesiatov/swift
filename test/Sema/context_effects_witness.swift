// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects -verify-ignore-unrelated
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
  mutating func readFile(at: String) -> String
}

// === Step 1: Unannotated witness for effects(Never) requirement → ERROR ===

protocol PureProtocol {
  func pureMethod() effects(Never) -> Int // expected-note 2 {{protocol requires function 'pureMethod()' with type '() effects(Never) -> Int'}}
}

struct BadWitness: PureProtocol { // expected-error {{type 'BadWitness' does not conform to protocol 'PureProtocol'}} expected-note {{add stubs for conformance}}
  func pureMethod() -> Int { return 42 } // expected-note {{candidate does not satisfy effects('Never') effect restriction of protocol requirement}}
}

// === Step 2: effects(Effect) witness for effects(Never) requirement → ERROR ===

struct OverPerformingWitness: PureProtocol { // expected-error {{type 'OverPerformingWitness' does not conform to protocol 'PureProtocol'}} expected-note {{add stubs for conformance}}
  func pureMethod() effects(FileSystem) -> Int { return 42 } // expected-note {{candidate does not satisfy effects('Never') effect restriction of protocol requirement}}
}

// === Step 3: Accepted cases ===

// effects(Never) witness satisfies unannotated requirement → OK
protocol UnrestrictedProtocol {
  func doSomething() -> Int
}

struct PureWitnessForUnrestricted: UnrestrictedProtocol {
  func doSomething() effects(Never) -> Int { return 42 }
}

// effects(Never) witness satisfies effects(Effect) requirement → OK
protocol EffectProtocol {
  func work() effects(FileSystem) -> Int
}

struct PureWitnessForEffect: EffectProtocol {
  func work() effects(Never) -> Int { return 42 }
}

// effects(Effect) witness satisfies same effects(Effect) requirement → OK
struct MatchingEffectWitness: EffectProtocol {
  func work() effects(FileSystem) -> Int { return 42 }
}

// Unannotated witness satisfies unannotated requirement → OK
struct UnrestrictedWitness: UnrestrictedProtocol {
  func doSomething() -> Int { return 42 }
}

// effects(Never) witness satisfies effects(Never) requirement → OK
struct PureWitnessForPure: PureProtocol {
  func pureMethod() effects(Never) -> Int { return 42 }
}

// Generic call through effects(Never) protocol requirement in restricted context → OK
func callPure<T: PureProtocol>(_ t: T) effects(Never) -> Int {
  return t.pureMethod()
}

// === Step 4: Unannotated witness for effects(Effect) requirement → ERROR ===

protocol EffectReqProtocol {
  func work() effects(FileSystem) // expected-note {{protocol requires function 'work()' with type '() effects(FileSystem) -> ()'}}
}

struct UnannotatedForEffectReq: EffectReqProtocol { // expected-error {{type 'UnannotatedForEffectReq' does not conform to protocol 'EffectReqProtocol'}} expected-note {{add stubs for conformance}}
  func work() {} // expected-note {{candidate does not satisfy effects('FileSystem') effect restriction of protocol requirement}}
}

// === Step 5: Initializer witness for effects(Never) requirement ===

protocol Constructible {
  init(value: Int) effects(Never)
}

struct GoodInit: Constructible {
  init(value: Int) effects(Never) {}
}

// === Step 6: effects(A) witness for effects(B) requirement -- subset check ===

protocol AllocatorProtocol: Effect {}

protocol AllocReqProtocol {
  func work() effects(AllocatorProtocol) // expected-note {{protocol requires function 'work()' with type '() effects(AllocatorProtocol) -> ()'}}
}

// FileSystem does not conform to AllocatorProtocol, so this is rejected.
struct FSWitnessForAllocReq: AllocReqProtocol { // expected-error {{type 'FSWitnessForAllocReq' does not conform to protocol 'AllocReqProtocol'}} expected-note {{add stubs for conformance}}
  func work() effects(FileSystem) {} // expected-note {{candidate does not satisfy effects('AllocatorProtocol') effect restriction of protocol requirement}}
}

// === Step 6b: effects(A) witness for effects(A & B) requirement -- A ⊆ {A, B} → OK ===

protocol NetworkProtocol: Effect {}

protocol MultiEffectProtocol {
  func work() effects(FileSystem & NetworkProtocol)
}

struct SingleEffectWitness: MultiEffectProtocol {
  func work() effects(FileSystem) {} // OK -- FileSystem ⊆ {FileSystem, NetworkProtocol}
}

// === Step 6c: effects(A & B) witness for effects(A) requirement -- {A, B} ⊄ {A} → ERROR ===

protocol SingleEffectReq {
  func work() effects(FileSystem) // expected-note {{protocol requires function 'work()' with type '() effects(FileSystem) -> ()'}}
}

struct MultiEffectWitness: SingleEffectReq { // expected-error {{type 'MultiEffectWitness' does not conform to protocol 'SingleEffectReq'}} expected-note {{add stubs for conformance}}
  func work() effects(FileSystem & NetworkProtocol) {} // expected-note {{candidate does not satisfy effects('FileSystem') effect restriction of protocol requirement}}
}

// === Step 7: Default implementation without performs for effects(Never) requirement ===

protocol DefaultedPure {
  func compute() effects(Never) -> Int // expected-note {{protocol requires function 'compute()' with type '() effects(Never) -> Int'}}
}

extension DefaultedPure {
  func compute() -> Int { return 0 } // expected-note {{candidate does not satisfy effects('Never') effect restriction of protocol requirement}}
}

// Default impl without performs does not satisfy effects(Never) requirement.
struct UsesDefault: DefaultedPure {} // expected-error {{type 'UsesDefault' does not conform to protocol 'DefaultedPure'}} expected-note {{add stubs for conformance}}

// === Step 8: Conditional conformance ===

struct Wrapper<T> { var value: T }

extension Wrapper: PureProtocol where T: PureProtocol {
  func pureMethod() effects(Never) -> Int { return value.pureMethod() }
}

// === Step 9: Property witness with performs ===
// NOTE: Property accessor performs is not yet parseable.
// The parser rejects `get effects(FileSystem)` with
// "expected 'get', 'yielding borrow', or 'set' in a protocol property"
// or "expected '{' to start getter definition".
// The ASTGen bridging (BridgedAccessorDecl_setParsedPerforms) and
// the witness check in checkEffects() are in place, but the parser
// needs to be updated to accept performs on accessor declarations.
// TODO: Fix swift-syntax parser to accept performs on accessors.
