# swift_build_support/products/wasmswiftsdkhelpers.py ------------*- python -*-
#
# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
#
# ----------------------------------------------------------------------------

"""
Shared helpers for building WebAssembly Swift SDK bundles.

These functions are used by both WasmSwiftSDK (WASI) and
EmscriptenSwiftSDK products. Platform-specific CMake options are
injected via the ``append_platform_cmake_options`` callable, which
has the signature::

    def append_platform_cmake_options(cmake_options, extra_swift_flags):
        ...
"""

import json
import os

from .cmake_product import CMakeProduct
from .. import shell


def target_package_path(build_dir, swift_host_triple):
    """Return the directory where the target package for a triple is assembled."""
    return os.path.join(build_dir, 'Toolchains', swift_host_triple)


def install_stdlib_and_resources(cmake_path, stdlib_build_path,
                                 resource_dir, dest_dir):
    """Install the stdlib into *dest_dir* and copy clang resource directories."""
    shell.rmtree(dest_dir)
    shell.makedirs(dest_dir)

    # cmake --install the stdlib (uses CMAKE_INSTALL_PREFIX=/usr set at
    # configure time, so DESTDIR gives us <dest_dir>/usr/lib/...).
    with shell.pushd(stdlib_build_path):
        shell.call([cmake_path, '--install', '.'],
                   env={'DESTDIR': dest_dir})

    # Copy clang resource dir into the three locations the toolchain expects.
    for dirname in ['clang', 'swift/clang', 'swift_static/clang']:
        dest_clang_resource_dir = os.path.join(
            dest_dir, 'usr', 'lib', dirname)
        shell.makedirs(dest_clang_resource_dir)
        resource_lib_dir = os.path.join(dest_clang_resource_dir, 'lib')
        # Remove existing (empty) lib directory created by the stdlib
        # CMake install step.
        shell.rmtree(resource_lib_dir)
        shell.copytree(os.path.join(resource_dir, 'lib'), resource_lib_dir)


def build_libxml2(args, toolchain, source_dir, build_dir,
                  swift_host_triple, clang_multiarch_triple,
                  has_pthread, sysroot,
                  append_platform_cmake_options):
    """Build libxml2 for a WebAssembly target and install into *sysroot*."""
    libxml2 = CMakeProduct(
        args=args,
        toolchain=toolchain,
        source_dir=os.path.join(
            os.path.dirname(source_dir), 'libxml2'),
        build_dir=os.path.join(build_dir, 'libxml2', swift_host_triple))
    append_platform_cmake_options(libxml2.cmake_options, [])
    libxml2.cmake_options.define('LIBXML2_WITH_C14N', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_CATALOG', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_DEBUG', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_DOCB', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_FTP', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_HTML', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_HTTP', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_ICONV', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_ICU', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_ISO8859X', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_LEGACY', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_LZMA', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_MEM_DEBUG', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_MODULES', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_OUTPUT', 'TRUE')
    libxml2.cmake_options.define('LIBXML2_WITH_PATTERN', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_PROGRAMS', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_PUSH', 'TRUE')
    libxml2.cmake_options.define('LIBXML2_WITH_PYTHON', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_READER', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_REGEXPS', 'TRUE')
    libxml2.cmake_options.define('LIBXML2_WITH_RUN_DEBUG', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_SAX1', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_SCHEMAS', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_SCHEMATRON', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_TESTS', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_TREE', 'TRUE')
    libxml2.cmake_options.define('LIBXML2_WITH_VALID', 'TRUE')
    libxml2.cmake_options.define('LIBXML2_WITH_WRITER', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_XINCLUDE', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_XPATH', 'TRUE')
    libxml2.cmake_options.define('LIBXML2_WITH_XPTR', 'FALSE')
    libxml2.cmake_options.define('LIBXML2_WITH_ZLIB', 'FALSE')
    libxml2.cmake_options.define('BUILD_SHARED_LIBS', 'FALSE')
    # Install libxml2.a under <sysroot>/lib/<clang_multiarch_triple>
    # because Clang driver only passes arch-specific library paths as
    # search paths to the linker for WebAssembly targets.
    libxml2.cmake_options.define('CMAKE_INSTALL_LIBDIR',
                                 f'lib/{clang_multiarch_triple}')

    cmake_thread_enabled = 'TRUE' if has_pthread else 'FALSE'
    libxml2.cmake_options.define('LIBXML2_WITH_THREAD_ALLOC',
                                 cmake_thread_enabled)
    libxml2.cmake_options.define('LIBXML2_WITH_THREADS',
                                 cmake_thread_enabled)
    libxml2.cmake_options.define('HAVE_PTHREAD_H', cmake_thread_enabled)

    libxml2.build_with_cmake(
        [], args.build_variant, [],
        prefer_native_toolchain=not args.build_runtime_with_host_compiler,
        ignore_extra_cmake_options=True)
    with shell.pushd(libxml2.build_dir):
        shell.call(
            [toolchain.cmake, '--install', '.', '--prefix', '/',
             '--component', 'development'],
            env={'DESTDIR': sysroot})


def build_foundation(args, toolchain, source_dir, build_dir,
                     swift_host_triple, clang_multiarch_triple,
                     sysroot, dest_dir, host_toolchain_path,
                     append_platform_cmake_options):
    """Build swift-corelibs-foundation and install into *dest_dir*."""
    source_root = os.path.dirname(source_dir)

    foundation = CMakeProduct(
        args=args,
        toolchain=toolchain,
        source_dir=os.path.join(source_root, 'swift-corelibs-foundation'),
        build_dir=os.path.join(build_dir, 'foundation', swift_host_triple))
    append_platform_cmake_options(foundation.cmake_options, [])
    foundation.cmake_options.define('BUILD_SHARED_LIBS', 'FALSE')
    foundation.cmake_options.define('FOUNDATION_BUILD_TOOLS', 'FALSE')
    foundation.cmake_options.define(
        '_SwiftCollections_SourceDIR',
        os.path.join(source_root, 'swift-collections'))
    foundation.cmake_options.define(
        '_SwiftFoundation_SourceDIR',
        os.path.join(source_root, 'swift-foundation'))
    foundation.cmake_options.define(
        '_SwiftFoundationICU_SourceDIR',
        os.path.join(source_root, 'swift-foundation-icu'))
    foundation.cmake_options.define(
        'SwiftFoundation_MACRO',
        os.path.join(host_toolchain_path, 'lib', 'swift', 'host', 'plugins'))
    # Teach CMake to use the sysroot for finding packages through
    # ``find_package``.  With ``CMAKE_LIBRARY_ARCHITECTURE``, CMake will
    # search in ``<sysroot>/lib/<clang_multiarch_triple>/cmake/...``.
    foundation.cmake_options.define('CMAKE_PREFIX_PATH', sysroot)
    foundation.cmake_options.define('CMAKE_LIBRARY_ARCHITECTURE',
                                    clang_multiarch_triple)

    foundation.build_with_cmake(
        [], args.build_variant, [],
        prefer_native_toolchain=not args.build_runtime_with_host_compiler,
        ignore_extra_cmake_options=True)

    with shell.pushd(foundation.build_dir):
        shell.call([toolchain.cmake, '--install', '.', '--prefix', '/usr'],
                   env={'DESTDIR': dest_dir})


def build_swift_testing(args, toolchain, source_dir, build_dir,
                        swift_host_triple, dest_dir,
                        append_platform_cmake_options):
    """Build swift-testing and install into *dest_dir*."""
    swift_testing = CMakeProduct(
        args=args,
        toolchain=toolchain,
        source_dir=os.path.join(
            os.path.dirname(source_dir), 'swift-testing'),
        build_dir=os.path.join(build_dir, 'swift-testing', swift_host_triple))
    # For statically linked objects in an archive, we have to use
    # singlethreaded LLVM codegen unit to prevent runtime metadata
    # sections from being stripped at link-time.
    append_platform_cmake_options(
        swift_testing.cmake_options,
        ['-Xfrontend', '-enable-single-module-llvm-emission'])
    swift_testing.cmake_options.define('BUILD_SHARED_LIBS', 'FALSE')
    swift_testing.cmake_options.define(
        'CMAKE_Swift_COMPILATION_MODE', 'wholemodule')
    swift_testing.cmake_options.define('SwiftTesting_MACRO', 'NO')

    swift_testing.build_with_cmake(
        [], args.build_variant, [],
        prefer_native_toolchain=not args.build_runtime_with_host_compiler,
        ignore_extra_cmake_options=True)
    with shell.pushd(swift_testing.build_dir):
        shell.call([toolchain.cmake, '--install', '.', '--prefix', '/usr'],
                   env={'DESTDIR': dest_dir})


def build_xctest(args, toolchain, source_dir, build_dir,
                 swift_host_triple, dest_dir,
                 append_platform_cmake_options):
    """Build swift-corelibs-xctest and install into *dest_dir*."""
    xctest = CMakeProduct(
        args=args,
        toolchain=toolchain,
        source_dir=os.path.join(
            os.path.dirname(source_dir), 'swift-corelibs-xctest'),
        build_dir=os.path.join(build_dir, 'xctest', swift_host_triple))
    append_platform_cmake_options(xctest.cmake_options, [])
    xctest.cmake_options.define('BUILD_SHARED_LIBS', 'FALSE')

    xctest.build_with_cmake(
        [], args.build_variant, [],
        prefer_native_toolchain=not args.build_runtime_with_host_compiler,
        ignore_extra_cmake_options=True)
    with shell.pushd(xctest.build_dir):
        shell.call([toolchain.cmake, '--install', '.', '--prefix', '/usr'],
                   env={'DESTDIR': dest_dir})


def find_swift_run(args, toolchain, host_target, install_toolchain_path):
    """Locate the ``swift-run`` binary."""
    if args.build_swift and args.build_swiftpm and args.install_swiftpm:
        return os.path.join(install_toolchain_path, 'bin', 'swift-run')
    else:
        swiftc_path = os.path.abspath(toolchain.swiftc)
        toolchain_path = os.path.dirname(os.path.dirname(swiftc_path))
        return os.path.join(toolchain_path, 'bin', 'swift-run')


def generate_swift_sdk(swift_run, source_dir, build_dir,
                       target_packages, swift_version):
    """Write a recipe JSON file and invoke swift-sdk-generator.

    *target_packages* is a list of ``(triple, sysroot, package_path)``
    tuples.
    """
    recipe = {
        'schemaVersion': '0.2',
        'recipeType': 'wasm',
        'swiftVersion': swift_version,
        'targets': [
            {
                'triple': triple,
                'sysroot': sysroot,
                'swiftPackagePath': package_path,
            }
            for triple, sysroot, package_path in target_packages
        ],
    }
    recipe_path = os.path.join(build_dir, 'wasm-sdk-recipe.json')
    with open(recipe_path, 'w') as f:
        json.dump(recipe, f, indent=2)

    run_args = [
        swift_run,
        '--package-path', source_dir,
        '--build-path', build_dir,
        'swift-sdk-generator',
        'make-wasm-sdk',
        '--recipe-path', recipe_path,
    ]

    env = dict(os.environ)
    env['SWIFTCI_USE_LOCAL_DEPS'] = '1'

    shell.call(run_args, env=env)
