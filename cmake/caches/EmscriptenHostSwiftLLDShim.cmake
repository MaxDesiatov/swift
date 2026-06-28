# Pre-define the lld imported targets that the wasm-targeting clang build's
# clangInterpreter (clang-repl's Wasm.cpp) lists in its exported
# ClangTargets.cmake. That dependency is added by
# clang/lib/Interpreter/CMakeLists.txt only when `EMSCRIPTEN AND lld IN
# LLVM_ENABLE_PROJECTS` -- both true for our cross-LLVM (EmscriptenHostLLVM) --
# so it does not appear in a native clang build.
#
# find_package(Clang) runs an existence check over ALL exported targets, so the
# unresolved lldWasm/lldCommon references would make Clang_FOUND=FALSE even
# though swift-frontend never links clangInterpreter (clang-repl). These
# imported targets satisfy the check; they point at the real cross-built wasm
# archives so that any (unexpected) link still resolves correctly.
#
# Injected via CMAKE_PROJECT_TOP_LEVEL_INCLUDES, which runs during the first
# project() call, before swift's find_package(Clang). The cross-LLVM lib dir is
# supplied by the EmscriptenHostSwift product as the command-line cache var
# SWIFT_EMSCRIPTEN_HOST_LLVM_LIB_DIR (a -D lands in the cache before project()
# runs, so it is visible here).

if(NOT SWIFT_EMSCRIPTEN_HOST_LLVM_LIB_DIR)
  message(FATAL_ERROR
    "SWIFT_EMSCRIPTEN_HOST_LLVM_LIB_DIR is not set. This top-level include "
    "expects -DSWIFT_EMSCRIPTEN_HOST_LLVM_LIB_DIR=<emscriptenhostllvm>/lib, "
    "pointing at the EmscriptenHostLLVM build's lib directory (the one "
    "containing liblldWasm.a / liblldCommon.a).")
endif()

foreach(_lldlib lldWasm lldCommon)
  if(NOT TARGET ${_lldlib})
    add_library(${_lldlib} STATIC IMPORTED GLOBAL)
    set_target_properties(${_lldlib} PROPERTIES
      IMPORTED_LOCATION
        "${SWIFT_EMSCRIPTEN_HOST_LLVM_LIB_DIR}/lib${_lldlib}.a")
  endif()
endforeach()
