// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect { mutating func read() -> String }
protocol Network: Effect { mutating func fetch() -> String }

func forward<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result { body() }

func pure() effects(Never) -> Void {}
func fsFn() effects(FileSystem) -> Void {}
func abFn() effects(FileSystem & Network) -> Void {}

func pureCaller() effects(Never) -> Void { forward(pure) }              // E := Never
func fsCaller() effects(FileSystem) -> Void { forward(fsFn) }           // E := FileSystem
func fsCallerPure() effects(FileSystem) -> Void { forward(pure) }       // Never <: FileSystem
func abCaller() effects(FileSystem & Network) -> Void { forward(abFn) } // E := FileSystem & Network
func anyCaller() { forward(fsFn) }                                      // unrestricted caller

// A function-typed value or parameter argument (a plain declref, distinct from the
// function-conversion of an unapplied named-function declref) infers E the same way.
func viaLetValue() effects(FileSystem) -> Void {
  let f: () effects(FileSystem) -> Void = fsFn
  forward(f)
}
func viaParameter(_ g: () effects(FileSystem) -> Void) effects(FileSystem) -> Void { forward(g) }
