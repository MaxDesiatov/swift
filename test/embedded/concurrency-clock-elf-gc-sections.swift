// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -target armv7em-none-none-eabi -enable-experimental-feature Embedded -parse-as-library %s -c -o %t/main.o
// RUN: %clang -target armv7em-none-none-eabi -fuse-ld=lld -nostdlib -Wl,--gc-sections -Wl,--unresolved-symbols=ignore-all -Wl,-e,main %t/main.o -L%swift_obj_root/lib/swift/embedded/armv7em-none-none-eabi -lswift_Concurrency -lswift_ConcurrencyDefaultExecutor -o %t/a.out
// RUN: %llvm-nm -u %t/a.out | %FileCheck %s --implicit-check-not=_swift_clockContinuous

// REQUIRES: OS=macosx
// REQUIRES: optimized_stdlib
// REQUIRES: CODEGENERATOR=ARM
// REQUIRES: embedded_stdlib_cross_compiling
// REQUIRES: swift_feature_Embedded
// REQUIRES: ld.lld

// CHECK-DAG: _swift_clockSuspending_getTime
// CHECK-DAG: _swift_clock_sleep

import _Concurrency

@main
struct Main {
  static func main() async {
    let task = Task { 42 }
    _ = await task.value
  }
}
