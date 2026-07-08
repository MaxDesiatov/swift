// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects -verify-ignore-unrelated
// REQUIRES: swift_feature_ContextEffects

class C {}

func usesLocking(_ c: C) effects(Locking) -> C { return c }
