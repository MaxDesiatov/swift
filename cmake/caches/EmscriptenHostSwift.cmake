# Cross-build `swift-frontend` to run *hosted on* a WebAssembly (Emscripten)
# runtime (host triple wasm32-unknown-emscripten), as opposed to *targeting*
# wasm. This is the Swift half of the wasm-hosted toolchain; the LLVM/clang
# half uses EmscriptenHostLLVM.cmake.
#
# This cache is consumed by the build-script product EmscriptenHostSwift
# (utils/swift_build_support/.../products/emscriptenhostswift.py), which passes
# it via `emcmake cmake -C ...` along with the path-dependent -D flags
# (LLVM_DIR, Clang_DIR, the SDK/sysroot paths, the native tblgen/tools paths,
# and the EmscriptenHostSwiftLLDShim.cmake top-level include). It can also be
# used standalone, supplying those -D flags by hand.
#
# The caller supplies the Emscripten toolchain (via `emcmake`, which sets the
# toolchain file + CMAKE_CROSSCOMPILING_EMULATOR=node).
#
# NOTE (no-FORCE footgun): these `set(... CACHE ...)` entries are no-FORCE.
# They stick on a FRESH build dir (they run before CMake's builtin defaults),
# but editing this file does NOT take effect on an existing build dir even with
# --reconfigure. Remove the build dir (fresh configure) after changing it.

# Build the Swift-in-Swift compiler sources. We set BOOTSTRAPPING_MODE to
# BOOTSTRAPPING, but because the product also passes
# SWIFT_NATIVE_SWIFT_TOOLS_PATH (a prebuilt native swiftc), swift's build
# converts the effective mode to CROSSCOMPILE (CMakeLists.txt:1046-1054):
# it reuses that native swiftc to compile SwiftCompilerSources instead of
# building in-tree bootstrapping stages. swift-syntax / Swift-parser
# integration is OFF because it is not ported to the wasm host (the configure
# reports "Not building swiftASTGen ... swift-syntax is not available").
set(SWIFT_ENABLE_SWIFT_IN_SWIFT ON CACHE BOOL "")
set(SWIFT_BUILD_SWIFT_SYNTAX OFF CACHE BOOL "")
set(BOOTSTRAPPING_MODE "BOOTSTRAPPING" CACHE STRING "")

# Host variant: the compiler binary runs on wasm32 Emscripten.
set(SWIFT_HOST_VARIANT_SDK "EMSCRIPTEN" CACHE STRING "")
set(SWIFT_HOST_VARIANT_ARCH "wasm32" CACHE STRING "")

# Frontend tools only; no immediate (JIT) mode on wasm.
set(SWIFT_INCLUDE_TOOLS ON CACHE BOOL "")
set(SWIFT_BUILD_IMMEDIATE_MODE OFF CACHE BOOL "")

# Trim auxiliary tool libraries that we don't run on the wasm host.
set(SWIFT_TOOL_LIBSWIFTSCAN_BUILD OFF CACHE BOOL "")
set(SWIFT_TOOL_LIBSTATICMIRROR_BUILD OFF CACHE BOOL "")
set(SWIFT_TOOL_LIBMOCKPLUGIN_BUILD OFF CACHE BOOL "")

# The target stdlib / overlays / SourceKit are provided as prebuilt inputs (or
# out of scope); this build produces the frontend, not the runtime.
set(SWIFT_BUILD_DYNAMIC_STDLIB OFF CACHE BOOL "")
set(SWIFT_BUILD_STATIC_STDLIB OFF CACHE BOOL "")
set(SWIFT_BUILD_REMOTE_MIRROR OFF CACHE BOOL "")
set(SWIFT_BUILD_SOURCEKIT OFF CACHE BOOL "")
set(SWIFT_BUILD_CLANG_OVERLAYS OFF CACHE BOOL "")
set(SWIFT_BUILD_DYNAMIC_SDK_OVERLAY OFF CACHE BOOL "")

set(SWIFT_INCLUDE_TESTS OFF CACHE BOOL "")
set(SWIFT_INCLUDE_DOCS OFF CACHE BOOL "")

# Emscripten link flags for the swift-frontend executable: grow memory up to
# 4 GiB (wasm32 max), run as a plain Node CLI over the real filesystem
# (NODERAWFS), and emit DWARF into a sidecar so the main module stays under
# V8's 1 GiB/module wasm limit.
set(CMAKE_EXE_LINKER_FLAGS
    "-sALLOW_MEMORY_GROWTH=1 -sMAXIMUM_MEMORY=4294967296 -sSTACK_SIZE=8388608 -sINITIAL_MEMORY=134217728 -sNODERAWFS=1 -sENVIRONMENT=node -gseparate-dwarf"
    CACHE STRING "")
