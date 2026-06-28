# swift_build_support/products/emscriptenhostllvm.py ------------*- python -*-
#
# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
#
# ----------------------------------------------------------------------------

import os
import shutil
import sys

from . import llvm
from . import product
from .. import shell


class EmscriptenHostLLVM(product.Product):
    """Cross-compiles LLVM static libraries that run *hosted on* a WebAssembly
    runtime (wasm32-unknown-emscripten). Distinct from EmscriptenStdlib /
    EmscriptenSysroot, which build the Swift stdlib *for* the wasm target.

    Reuses the native llvm-tblgen produced by the build's native LLVM product
    and drives an `emcmake cmake` configure + build using the in-tree
    swift/cmake/caches/EmscriptenHostLLVM.cmake cache file.
    """

    @classmethod
    def product_source_name(cls):
        # Cross-compile the same LLVM source the native build uses.
        return os.path.join("llvm-project", "llvm")

    @classmethod
    def is_build_script_impl_product(cls):
        return False

    @classmethod
    def is_before_build_script_impl_product(cls):
        return False

    @classmethod
    def get_dependencies(cls):
        # Native LLVM provides llvm-tblgen (built minimally under
        # --skip-build-llvm) and fixes build ordering before this product.
        return [llvm.LLVM]

    def should_build(self, host_target):
        # Build the wasm-host LLVM once on the native build host: emcc is the
        # cross compiler, and the reused llvm-tblgen must run on the build
        # machine, so cross-compile-host iterations are skipped.
        return self.args.build_emscripten_host_llvm and \
            not self.is_cross_compile_target(host_target)

    def should_test(self, host_target):
        return False

    def should_install(self, host_target):
        return False

    def build(self, host_target):
        emcmake = self._emcmake_path()
        cache_file = self._cache_file_path()
        llvm_tblgen = self._native_llvm_tblgen(host_target)
        clang_tblgen = self._native_clang_tblgen(host_target)

        # Validate filesystem preconditions with actionable messages. Skipped
        # under --dry-run, where these artifacts need not exist yet.
        if not self.args.dry_run:
            if not os.path.isfile(cache_file):
                print('error: EmscriptenHostLLVM.cmake cache not found at %s'
                      % cache_file, file=sys.stderr)
                sys.exit(1)
            if not os.path.isfile(llvm_tblgen):
                print('error: native llvm-tblgen not found at %s; build native '
                      'LLVM (e.g. --llvm-ninja-targets=llvm-tblgen) or pass '
                      '--native-llvm-tools-path' % llvm_tblgen, file=sys.stderr)
                sys.exit(1)
            if not os.path.isfile(clang_tblgen):
                print('error: native clang-tblgen not found at %s; build it (e.g. '
                      '--llvm-ninja-targets clang-tblgen) or pass '
                      '--native-clang-tools-path' % clang_tblgen, file=sys.stderr)
                sys.exit(1)

        configure_cmd = [
            emcmake, self.toolchain.cmake,
            '-G', 'Ninja',
            '-S', self.source_dir,
            '-B', self.build_dir,
            '-C', cache_file,
            '-DLLVM_TABLEGEN=' + llvm_tblgen,
            '-DCLANG_TABLEGEN=' + clang_tblgen,
            '-DCMAKE_BUILD_TYPE=' + self.args.llvm_build_variant,
        ]

        # Reconfigure when asked, or when either the cache or the generator
        # output is missing (a half-finished configure leaves CMakeCache.txt
        # without build.ninja and would otherwise wedge every later build).
        # NOTE: this mirrors the repo-standard cmake_product.py guard and checks
        # only existence, not mtime. EmscriptenHostLLVM.cmake is a CMake `-C`
        # initial cache whose `set(... CACHE ...)` is no-FORCE, so editing it does
        # NOT take effect on an existing build dir even with --reconfigure; remove
        # the build dir (fresh configure) after changing the cache file.
        cmake_cache = os.path.join(self.build_dir, 'CMakeCache.txt')
        build_ninja = os.path.join(self.build_dir, 'build.ninja')
        if self.args.reconfigure or not os.path.isfile(cmake_cache) \
                or not os.path.isfile(build_ninja):
            shell.makedirs(self.build_dir)
            shell.call(configure_cmd)

        if self.args.skip_build:
            return

        # Build the wasm-host toolchain. The WebAssembly target and the
        # clang;lld projects are enabled by the cache file.
        build_args = ['-j', str(self.args.build_jobs)]
        if self.args.verbose_build:
            build_args.append('-v')
        # One multicall executable packing clang + wasm-ld (+ utils), argv[0]-dispatched.
        # Building llvm-driver transitively builds the clang/lld object libs and the
        # LLVM libs the Phase-1 milestone built standalone.
        build_targets = ['llvm-driver']
        shell.call([self.toolchain.cmake, '--build', self.build_dir, '--']
                   + build_args + build_targets)

    def _emcmake_path(self):
        # An explicit --emscripten-path is authoritative (matches
        # EmscriptenSysroot); only fall back to PATH when it is unset.
        if self.args.emscripten_path:
            candidate = os.path.join(self.args.emscripten_path, 'emcmake')
            if os.path.isfile(candidate) or self.args.dry_run:
                return candidate
            print('error: emcmake not found at %s (from --emscripten-path)'
                  % candidate, file=sys.stderr)
            sys.exit(1)
        found = shutil.which('emcmake')
        if found is not None:
            return found
        if self.args.dry_run:
            return 'emcmake'
        print('error: `emcmake` not found; pass --emscripten-path pointing at '
              'the Emscripten checkout, or put emcmake on PATH', file=sys.stderr)
        sys.exit(1)

    def _cache_file_path(self):
        # The cache lives in the Swift repo (Swift's build-script drives this
        # build), not in the LLVM checkout. self.source_dir is
        # <source_root>/llvm-project/llvm, so the Swift repo is a sibling.
        source_root = os.path.dirname(os.path.dirname(self.source_dir))
        return os.path.join(source_root, 'swift', 'cmake', 'caches',
                            'EmscriptenHostLLVM.cmake')

    def _native_llvm_tblgen(self, host_target):
        llvm_bin = os.path.join(self._host_llvm_build_dir(host_target), 'bin')
        native = self.args.native_llvm_tools_path or llvm_bin
        return os.path.join(native, 'llvm-tblgen')

    def _native_clang_tblgen(self, host_target):
        llvm_bin = os.path.join(self._host_llvm_build_dir(host_target), 'bin')
        native = self.args.native_clang_tools_path or llvm_bin
        return os.path.join(native, 'clang-tblgen')

    def _host_llvm_build_dir(self, host_target):
        # Same target dir as emscriptenstdlib.py / wasistdlib.py's helper, minus
        # their no-op '..' prefix (build_root is absolute, so the path is used
        # absolutely here rather than relative to a pushd(build_dir) context).
        build_root = os.path.dirname(self.build_dir)
        return os.path.join(build_root, '%s-%s' % ('llvm', host_target))
