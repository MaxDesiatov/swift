// RUN: %empty-directory(%t)

// RUN: %target-swift-frontend -enable-experimental-feature Embedded -module-name main -O %s -emit-ir | %FileCheck %s --check-prefix=CHECK-IR
// RUN: %target-swift-frontend -enable-experimental-feature Embedded -module-name main -O %s -c -o %t/a.o
// RUN: %target-embedded-link %target-clang-resource-dir-opt %t/a.o %target-embedded-posix-shim -o %t/a.out -dead_strip
// RUN: %llvm-nm --defined-only --format=just-symbols --demangle %t/a.out | sort | %FileCheck %s --check-prefix=CHECK-NM
// RUN: %target-run %t/a.out | %FileCheck %s

// REQUIRES: swift_in_compiler
// REQUIRES: executable_test
// REQUIRES: swift_feature_Embedded

// UNSUPPORTED: OS=emscripten
// emcc emits two artifacts when -o ends in `.out`: a JavaScript launcher named
// exactly `a.out` (text), and the wasm binary at `a.out.wasm`. The CHECK-NM
// step runs `llvm-nm a.out`, which rejects the JS file as "not recognized as a
// valid object file". The dead-strip behaviour the test verifies still applies
// on emscripten; a future emscripten-aware substitution that points llvm-nm at
// `a.out.wasm` (or a per-target output extension) would unblock this test.

public func a_this_is_unused() { }

@used
public func b_this_is_unused_but_explicitly_retained() { }

// CHECK-IR: define {{.*}}@"$e4main16a_this_is_unusedyyF"()
// CHECK-IR: define {{.*}}@"$e4main40b_this_is_unused_but_explicitly_retainedyyF"()

// CHECK-NM-NOT: $e4main14this_is_unusedyyF
// CHECK-NM: $e4main40b_this_is_unused_but_explicitly_retainedyyF

print("Hello")
// CHECK: Hello
