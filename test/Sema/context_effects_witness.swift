// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects -verify-ignore-unrelated
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
  mutating func readFile(at: String) -> String
}

// === Step 1: Unannotated witness for performs(Never) requirement → ERROR ===

protocol PureProtocol {
  func pureMethod() performs(Never) -> Int // expected-note 2 {{protocol requires function 'pureMethod()' with type '() performs(Never) -> Int'}}
}

struct BadWitness: PureProtocol { // expected-error {{type 'BadWitness' does not conform to protocol 'PureProtocol'}} expected-note {{add stubs for conformance}}
  func pureMethod() -> Int { return 42 } // expected-note {{candidate does not satisfy performs('Never') effect restriction of protocol requirement}}
}

// === Step 2: performs(Effect) witness for performs(Never) requirement → ERROR ===

struct OverPerformingWitness: PureProtocol { // expected-error {{type 'OverPerformingWitness' does not conform to protocol 'PureProtocol'}} expected-note {{add stubs for conformance}}
  func pureMethod() performs(FileSystem) -> Int { return 42 } // expected-note {{candidate does not satisfy performs('Never') effect restriction of protocol requirement}}
}

// === Step 3: Accepted cases ===

// performs(Never) witness satisfies unannotated requirement → OK
protocol UnrestrictedProtocol {
  func doSomething() -> Int
}

struct PureWitnessForUnrestricted: UnrestrictedProtocol {
  func doSomething() performs(Never) -> Int { return 42 }
}

// performs(Never) witness satisfies performs(Effect) requirement → OK
protocol EffectProtocol {
  func work() performs(FileSystem) -> Int
}

struct PureWitnessForEffect: EffectProtocol {
  func work() performs(Never) -> Int { return 42 }
}

// performs(Effect) witness satisfies same performs(Effect) requirement → OK
struct MatchingEffectWitness: EffectProtocol {
  func work() performs(FileSystem) -> Int { return 42 }
}

// Unannotated witness satisfies unannotated requirement → OK
struct UnrestrictedWitness: UnrestrictedProtocol {
  func doSomething() -> Int { return 42 }
}

// performs(Never) witness satisfies performs(Never) requirement → OK
struct PureWitnessForPure: PureProtocol {
  func pureMethod() performs(Never) -> Int { return 42 }
}

// Generic call through performs(Never) protocol requirement in restricted context → OK
func callPure<T: PureProtocol>(_ t: T) performs(Never) -> Int {
  return t.pureMethod()
}

// === Step 4: Unannotated witness for performs(Effect) requirement → ERROR ===

protocol EffectReqProtocol {
  func work() performs(FileSystem) // expected-note {{protocol requires function 'work()' with type '() performs(FileSystem) -> ()'}}
}

struct UnannotatedForEffectReq: EffectReqProtocol { // expected-error {{type 'UnannotatedForEffectReq' does not conform to protocol 'EffectReqProtocol'}} expected-note {{add stubs for conformance}}
  func work() {} // expected-note {{candidate does not satisfy performs('FileSystem') effect restriction of protocol requirement}}
}

// === Step 5: Initializer witness for performs(Never) requirement ===

protocol Constructible {
  init(value: Int) performs(Never)
}

struct GoodInit: Constructible {
  init(value: Int) performs(Never) {}
}

// === Step 6: performs(A) witness for performs(B) requirement -- subset check ===

protocol AllocatorProtocol: Effect {}

protocol AllocReqProtocol {
  func work() performs(AllocatorProtocol) // expected-note {{protocol requires function 'work()' with type '() performs(AllocatorProtocol) -> ()'}}
}

// FileSystem does not conform to AllocatorProtocol, so this is rejected.
struct FSWitnessForAllocReq: AllocReqProtocol { // expected-error {{type 'FSWitnessForAllocReq' does not conform to protocol 'AllocReqProtocol'}} expected-note {{add stubs for conformance}}
  func work() performs(FileSystem) {} // expected-note {{candidate does not satisfy performs('AllocatorProtocol') effect restriction of protocol requirement}}
}

// === Step 6b: performs(A) witness for performs(A & B) requirement -- A ⊆ {A, B} → OK ===

protocol NetworkProtocol: Effect {}

protocol MultiEffectProtocol {
  func work() performs(FileSystem & NetworkProtocol)
}

struct SingleEffectWitness: MultiEffectProtocol {
  func work() performs(FileSystem) {} // OK -- FileSystem ⊆ {FileSystem, NetworkProtocol}
}

// === Step 6c: performs(A & B) witness for performs(A) requirement -- {A, B} ⊄ {A} → ERROR ===

protocol SingleEffectReq {
  func work() performs(FileSystem) // expected-note {{protocol requires function 'work()' with type '() performs(FileSystem) -> ()'}}
}

struct MultiEffectWitness: SingleEffectReq { // expected-error {{type 'MultiEffectWitness' does not conform to protocol 'SingleEffectReq'}} expected-note {{add stubs for conformance}}
  func work() performs(FileSystem & NetworkProtocol) {} // expected-note {{candidate does not satisfy performs('FileSystem') effect restriction of protocol requirement}}
}

// === Step 7: Default implementation without performs for performs(Never) requirement ===

protocol DefaultedPure {
  func compute() performs(Never) -> Int // expected-note {{protocol requires function 'compute()' with type '() performs(Never) -> Int'}}
}

extension DefaultedPure {
  func compute() -> Int { return 0 } // expected-note {{candidate does not satisfy performs('Never') effect restriction of protocol requirement}}
}

// Default impl without performs does not satisfy performs(Never) requirement.
struct UsesDefault: DefaultedPure {} // expected-error {{type 'UsesDefault' does not conform to protocol 'DefaultedPure'}} expected-note {{add stubs for conformance}}

// === Step 8: Conditional conformance ===

struct Wrapper<T> { var value: T }

extension Wrapper: PureProtocol where T: PureProtocol {
  func pureMethod() performs(Never) -> Int { return value.pureMethod() }
}

// === Step 9: Property witness with performs ===
// NOTE: Property accessor performs is not yet parseable.
// The parser rejects `get performs(FileSystem)` with
// "expected 'get', 'yielding borrow', or 'set' in a protocol property"
// or "expected '{' to start getter definition".
// The ASTGen bridging (BridgedAccessorDecl_setParsedPerforms) and
// the witness check in checkEffects() are in place, but the parser
// needs to be updated to accept performs on accessor declarations.
// TODO: Fix swift-syntax parser to accept performs on accessors.
