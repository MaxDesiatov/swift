// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect { mutating func read() -> String }
protocol Network: Effect { mutating func fetch() -> String }

func forward<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result { body() }
func concreteFn() effects(FileSystem) -> Void {} // expected-note {{'concreteFn()' declared here}}

struct MockFS: FileSystem {
  init() effects(Never) {}
  mutating func read() -> String { "" }
}
func takesFS(_ f: () effects(FileSystem) -> Void) effects(FileSystem) -> Void { f() } // expected-note {{'takesFS' declared here}}


// Caller and callee share the same abstract effect.
func okForward<E: Effect>(_ b: () effects(E) -> Void) effects(E) -> Void { forward(b) }

// Unrestricted caller: allowed regardless of the argument's abstract effect.
func plainCaller<E: Effect>(_ b: () effects(E) -> Void) { forward(b) }

// The same abstract effect stays available across a nested generic function.
func outerNest<E: Effect>(_ b: () effects(E) -> Void) effects(E) -> Void {
  func innerNest() effects(E) -> Void { forward(b) }
  innerNest()
}

// Abstract E forwarded in an unrelated abstract-F context, F referenced by value.
func badForwardUsed<E: Effect, F: Effect>(_ b: () effects(E) -> Void, _ f: F) effects(F) -> Void {
  forward(b)
  // expected-error@-1 {{call to function that has effects 'E' is not allowed; enclosing function only has effects 'F'}}
}

// The same mismatch with F referenced by metatype.
func badForwardMeta<E: Effect, F: Effect>(_ b: () effects(E) -> Void, _ ft: F.Type) effects(F) -> Void {
  forward(b)
  // expected-error@-1 {{call to function that has effects 'E' is not allowed; enclosing function only has effects 'F'}}
}

// Abstract E forwarded in a concrete context.
func abstractInConcrete<E: Effect>(_ b: () effects(E) -> Void) effects(FileSystem) -> Void {
  forward(b)
  // expected-error@-1 {{call to function that has effects 'E' is not allowed; enclosing function only has effects 'FileSystem'}}
}

// Abstract E forwarded in a Never context.
func abstractInNever<E: Effect>(_ b: () effects(E) -> Void, _ marker: E) effects(Never) -> Void {
  forward(b)
  // expected-error@-1 {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}

// Concrete callee in an abstract-E context: names the abstract row, not a 'Never' context.
func abstractCallingConcrete<E: Effect>(_ b: () effects(E) -> Void) effects(E) -> Void {
  concreteFn()
  // expected-error@-1 {{call to function that has effects 'FileSystem' is not allowed; enclosing function only has effects 'E'}}
}

// A 'do effects(...)' block isolates to its declared concrete effects, so the outer
// abstract E is not available inside its body.
func abstractInDoEffects<E: Effect>(_ b: () effects(E) -> Void) effects(E) -> Void {
  do effects(FileSystem) {
    forward(b)
    // expected-error@-1 {{call to function that has effects 'E' is not allowed; enclosing function only has effects 'FileSystem'}}
  } handle MockFS() as FileSystem
}

// A concrete-effect closure body narrows to its own row, so the outer abstract E is
// not available inside it. The enclosing takesFS call is itself unavailable here.
func abstractInClosure<E: Effect>(_ b: () effects(E) -> Void) effects(E) -> Void {
  takesFS { // expected-error {{call to function that has effects 'FileSystem' is not allowed; enclosing function only has effects 'E'}}
    forward(b)
    // expected-error@-1 {{call to function that has effects 'E' is not allowed; enclosing function only has effects 'FileSystem'}}
  }
}

