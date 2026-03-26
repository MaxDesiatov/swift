// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects

// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
    mutating func readFile(at path: String) -> String
}
protocol Network: Effect {
    mutating func fetch(url: String) -> String
}

func fsOnly() performs(FileSystem) {} // expected-note {{declared here}}
func netOnly() performs(Network) {}
func fsBoth() performs(FileSystem, Network) {} // expected-note {{declared here}}
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
  fsBoth() // expected-error {{call to function that performs 'Network' is not allowed; enclosing function only performs FileSystem}}
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
