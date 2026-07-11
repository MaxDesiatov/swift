// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect { mutating func read() -> String }
protocol Network: Effect { mutating func fetch() -> String }

struct MockFS: FileSystem { mutating func read() -> String { "" } }

func forward<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result { body() }

func fsFn() effects(FileSystem) -> Void {}
func nwFn() effects(Network) -> Void {}
func abFn() effects(FileSystem & Network) -> Void {}

// E := FileSystem is NOT available in a Never context.
func badCaller() effects(Never) -> Void {
  forward(fsFn)
  // expected-error@-1 {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}

// Naming the missing protocol pins the inferred row: this fires only if E := Network,
// not if E mis-bound to the caller's FileSystem row (which would be available).
func fsBadName() effects(FileSystem) -> Void {
  forward(nwFn)
  // expected-error@-1 {{call to function that has effects 'Network' is not allowed; enclosing function only has effects 'FileSystem'}}
}

// A composed inferred row partly unavailable: Network missing in a FileSystem context.
func abBadCaller() effects(FileSystem) -> Void {
  forward(abFn)
  // expected-error@-1 {{call to function that has effects 'Network' is not allowed; enclosing function only has effects 'FileSystem'}}
}

// A function-typed value/parameter argument is enforced like a named-function argument.
func viaLetBad() effects(Never) -> Void {
  let f: () effects(FileSystem) -> Void = fsFn
  forward(f)
  // expected-error@-1 {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}

func viaParamComposed(_ g: () effects(FileSystem & Network) -> Void) effects(FileSystem) -> Void {
  forward(g)
  // expected-error@-1 {{call to function that has effects 'Network' is not allowed; enclosing function only has effects 'FileSystem'}}
}

// The inferred row is enforced against a do...handle narrowing scope too.
func okNarrow() {
  do { forward(fsFn) } handle MockFS() as FileSystem
}

func badNarrow() {
  do { forward(nwFn) } handle MockFS() as FileSystem
  // expected-error@-1 {{call to function that has effects 'Network' is not allowed; enclosing function only has effects 'FileSystem'}}
}
