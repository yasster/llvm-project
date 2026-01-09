// RUN: %clang_cc1 -triple x86_64-windows-msvc -fms-compatibility -emit-llvm -o - %s | FileCheck %s

// Test that in MSVC compatibility mode, a non-extern redeclaration of an
// inline function does NOT force an externally visible definition.
// This matches MSVC behavior where inline functions have ODR linkage and
// can be discarded if not referenced.
//
// This is the pattern used by the Windows CRT headers:
//   // corecrt_stdio_config.h
//   __inline __int64* __local_stdio_printf_options(void) { static __int64 _OptionsStorage; return &_OptionsStorage; }
//   // stdio.h (later)
//   __int64* __local_stdio_printf_options(void);  // redeclaration without inline

// The inline definition
__inline int inline_func(void) { return 42; }

// A non-extern, non-inline redeclaration - in C99, this would force an
// externally visible definition, but in MSVC mode it should not.
int inline_func(void);

// CHECK-NOT: define dso_local i32 @inline_func
// CHECK: define linkonce_odr dso_local i32 @inline_func

int call_it(void) {
    return inline_func();
}
