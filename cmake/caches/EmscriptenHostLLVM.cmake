# Cross-build LLVM to run *hosted on* a WebAssembly (Emscripten) runtime
# (host triple wasm32-unknown-emscripten), as opposed to *targeting* wasm.
#
# This cache lives in the Swift repo because Swift's build-script drives the
# Emscripten host build. It is consumed by the build-script product
# EmscriptenHostLLVM (utils/swift_build_support/.../products/emscriptenhostllvm.py),
# which passes it via `emcmake cmake -C ...`. It can also be used standalone:
#   emcmake cmake -G Ninja -S <llvm-project>/llvm -B <build> \
#     -C <swift>/cmake/caches/EmscriptenHostLLVM.cmake -DLLVM_TABLEGEN=<native llvm-tblgen>
#
# The caller supplies the Emscripten toolchain (via `emcmake`, which sets the
# toolchain file + CMAKE_CROSSCOMPILING_EMULATOR=node) and -DLLVM_TABLEGEN
# pointing at a native llvm-tblgen.
#
# Pin the host/default triples explicitly: auto-detection runs config.guess on
# the BUILD machine and bakes the build host, not the wasm cross-target; and the
# default target triple does not reliably inherit the host triple.

set(LLVM_HOST_TRIPLE "wasm32-unknown-emscripten" CACHE STRING "")
set(LLVM_DEFAULT_TARGET_TRIPLE "wasm32-unknown-emscripten" CACHE STRING "")
set(LLVM_TARGETS_TO_BUILD "WebAssembly" CACHE STRING "")
# Intentionally LLVM-only for Phase 1 (no clang). Phase 2 (clang/lld) must add
# to LLVM_ENABLE_PROJECTS here or via -D; do not assume this stays empty.
set(LLVM_ENABLE_PROJECTS "" CACHE STRING "")

set(LLVM_ENABLE_THREADS OFF CACHE BOOL "")
set(LLVM_ENABLE_PLUGINS OFF CACHE BOOL "")
set(LLVM_ENABLE_ZLIB OFF CACHE BOOL "")
set(LLVM_ENABLE_ZSTD OFF CACHE BOOL "")
set(LLVM_ENABLE_LIBXML2 OFF CACHE BOOL "")
set(LLVM_ENABLE_LIBEDIT OFF CACHE BOOL "")

set(LLVM_INCLUDE_TESTS OFF CACHE BOOL "")
set(LLVM_INCLUDE_BENCHMARKS OFF CACHE BOOL "")
set(LLVM_INCLUDE_EXAMPLES OFF CACHE BOOL "")
