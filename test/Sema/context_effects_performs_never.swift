// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects -verify-ignore-unrelated
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
  mutating func readFile(at: String) -> String
}

// --- async/throws + effects(Never) declaration validation ---

func f1() effects(Never) async -> Int { 42 }
// expected-error @-1 {{'async' cannot be combined with 'effects(Never)' because async execution requires allocation}}

func f2() effects(Never) throws -> Int { 42 }
// expected-error @-1 {{'throws' without a concrete error type cannot be combined with 'effects(Never)'; use typed 'throws(ConcreteError)' instead}}

struct DivByZero: Error {}
func f3() effects(Never) throws(DivByZero) -> Int { 42 } // OK

func f4() effects(Never) -> Int { 42 } // OK

func f5() effects(Never) throws(Never) -> Int { 42 } // OK

func f6() effects(Never) async throws -> Int { 42 }
// expected-error @-1 {{'async' cannot be combined with 'effects(Never)' because async execution requires allocation}}
// expected-error @-2 {{'throws' without a concrete error type cannot be combined with 'effects(Never)'; use typed 'throws(ConcreteError)' instead}}

func f7() effects(Never) async throws(DivByZero) -> Int { 42 }
// expected-error @-1 {{'async' cannot be combined with 'effects(Never)' because async execution requires allocation}}

struct PureStruct {
  init() effects(Never) {}
}

// --- Unannotated callee rejection ---

func unannotated() {}
func pureCallee() effects(Never) -> Int { 42 }
func fsCallee() effects(FileSystem) {}

// effects(Never) calling unannotated — ERROR
func testNeverCallsUnannotated() effects(Never) {
  unannotated() // expected-error {{call to 'unannotated()' is not allowed in a restricted effect context because it has no 'effects' clause}}
}

// effects(Never) calling effects(Never) — OK
func testNeverCallsPure() effects(Never) {
  _ = pureCallee()
}

// effects(FileSystem) calling unannotated — ERROR
func testFSCallsUnannotated() effects(FileSystem) {
  unannotated() // expected-error {{call to 'unannotated()' is not allowed in a restricted effect context because it has no 'effects' clause}}
}

// effects(FileSystem) calling effects(FileSystem) — OK
func testFSCallsFS() effects(FileSystem) {
  fsCallee()
}

// effects(FileSystem) calling effects(Never) — OK (subset)
func testFSCallsPure() effects(FileSystem) {
  _ = pureCallee()
}

// Unannotated calling anything — OK (unrestricted)
func testUnrestrictedCallsAll() {
  unannotated()
  _ = pureCallee()
  fsCallee()
}

// do...handle body calling unannotated — ERROR (narrowing scope is restricted)
func testDoHandleCallsUnannotated() {
  struct MockFS: FileSystem {
    init() effects(Never) {}
    mutating func readFile(at: String) -> String { "" }
  }
  do {
    unannotated() // expected-error {{call to 'unannotated()' is not allowed in a restricted effect context because it has no 'effects' clause}}
  } handle MockFS() as FileSystem
}
