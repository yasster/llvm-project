// RUN: %clang_cc1 -std=c++11 -emit-llvm %s -o - -triple=x86_64-pc-windows-msvc \
// RUN:     -fexceptions -fcxx-exceptions -fms-cxx-fh4 \
// RUN:     | FileCheck %s

// Test that -fms-cxx-fh4 selects __CxxFrameHandler4 personality function.

extern "C" void might_throw();
extern "C" void recover() noexcept(true);

extern "C" void test_fh4_catch_all() {
  try {
    might_throw();
  } catch (...) {
    recover();
  }
}

// CHECK-LABEL: define dso_local void @test_fh4_catch_all()
// CHECK-SAME: personality ptr @__CxxFrameHandler4
// CHECK: invoke void @might_throw()
// CHECK: catchswitch within none
// CHECK: catchpad within

extern "C" void test_fh4_catch_int() {
  try {
    might_throw();
  } catch (int e) {
    (void)e;
  }
}

// CHECK-LABEL: define dso_local void @test_fh4_catch_int()
// CHECK-SAME: personality ptr @__CxxFrameHandler4
// CHECK: catchpad within %{{[^ ]*}} [ptr @"??_R0H@8", i32 0, ptr %{{.*}}]
