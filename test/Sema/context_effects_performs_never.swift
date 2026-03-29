// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects -verify-ignore-unrelated
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
  mutating func readFile(at: String) -> String
}

// --- async/throws + performs(Never) declaration validation ---

func f1() performs(Never) async -> Int { 42 }
// expected-error @-1 {{'async' cannot be combined with 'performs(Never)' because async execution requires allocation}}

func f2() performs(Never) throws -> Int { 42 }
// expected-error @-1 {{'throws' without a concrete error type cannot be combined with 'performs(Never)'; use typed 'throws(ConcreteError)' instead}}

struct DivByZero: Error {}
func f3() performs(Never) throws(DivByZero) -> Int { 42 } // OK

func f4() performs(Never) -> Int { 42 } // OK

func f5() performs(Never) throws(Never) -> Int { 42 } // OK

func f6() performs(Never) async throws -> Int { 42 }
// expected-error @-1 {{'async' cannot be combined with 'performs(Never)' because async execution requires allocation}}
// expected-error @-2 {{'throws' without a concrete error type cannot be combined with 'performs(Never)'; use typed 'throws(ConcreteError)' instead}}

func f7() performs(Never) async throws(DivByZero) -> Int { 42 }
// expected-error @-1 {{'async' cannot be combined with 'performs(Never)' because async execution requires allocation}}

struct PureStruct {
  init() performs(Never) {}
}

// --- Unannotated callee rejection ---

func unannotated() {}
func pureCallee() performs(Never) -> Int { 42 }
func fsCallee() performs(FileSystem) {}

// performs(Never) calling unannotated — ERROR
func testNeverCallsUnannotated() performs(Never) {
  unannotated() // expected-error {{call to 'unannotated()' is not allowed in a restricted effect context because it has no 'performs' clause}}
}

// performs(Never) calling performs(Never) — OK
func testNeverCallsPure() performs(Never) {
  _ = pureCallee()
}

// performs(FileSystem) calling unannotated — ERROR
func testFSCallsUnannotated() performs(FileSystem) {
  unannotated() // expected-error {{call to 'unannotated()' is not allowed in a restricted effect context because it has no 'performs' clause}}
}

// performs(FileSystem) calling performs(FileSystem) — OK
func testFSCallsFS() performs(FileSystem) {
  fsCallee()
}

// performs(FileSystem) calling performs(Never) — OK (subset)
func testFSCallsPure() performs(FileSystem) {
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
    init() performs(Never) {}
    mutating func readFile(at: String) -> String { "" }
  }
  do {
    unannotated() // expected-error {{call to 'unannotated()' is not allowed in a restricted effect context because it has no 'performs' clause}}
  } handle MockFS() as FileSystem
}
