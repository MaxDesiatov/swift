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
  func pureMethod() -> Int { return 42 } // expected-note {{candidate does not satisfy effect restriction 'performs(Never)' of protocol requirement}}
}

// === Step 2: performs(Effect) witness for performs(Never) requirement → ERROR ===

struct OverPerformingWitness: PureProtocol { // expected-error {{type 'OverPerformingWitness' does not conform to protocol 'PureProtocol'}} expected-note {{add stubs for conformance}}
  func pureMethod() performs(FileSystem) -> Int { return 42 } // expected-note {{candidate does not satisfy effect restriction 'performs(Never)' of protocol requirement}}
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
