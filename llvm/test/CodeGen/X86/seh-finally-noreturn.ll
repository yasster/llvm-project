; RUN: llc -mtriple=x86_64-windows-msvc < %s | FileCheck %s

; Test that SEH scope tables are correctly generated when a __finally handler
; contains a noreturn function (like longjmp), which causes the cleanupret to
; be optimized away. The outer finally handlers should still be in the scope
; table for proper unwinding.
;
; This test is derived from the xcpt4 test suite test24/test26, which have
; nested __try/__finally where an inner finally calls longjmp (noreturn).
; Without the fix in WinEHPrepare.cpp (using seh.scope.end invoke to find
; the unwind destination when cleanupret is absent), the scope table would
; be missing entries for outer finally handlers.

@Counter = external global i32

declare void @RaiseException()
declare void @noreturn_func() noreturn
declare void @llvm.seh.scope.begin() nounwind
declare void @llvm.seh.scope.end() nounwind

; Test case with 3 levels of nesting, where the middle finally contains a
; noreturn function. This tests getCleanupRetUnwindDest() fallback to use
; seh.scope.end invoke when cleanupret is missing.
;
; C equivalent:
; __try {                               // outer scope -> ehcleanup.outer
;   __try {                             // middle scope -> ehcleanup.middle
;     __try {                           // inner scope -> ehcleanup.inner
;       RaiseException();
;     } __finally { Counter++; }        // inner finally - normal cleanup
;   } __finally {
;     Counter++;
;     longjmp(buf, 1);                  // NORETURN - no cleanupret!
;   }
; } __finally { Counter++; }            // outer finally - must be in scope table!

define void @test_finally_noreturn_nested() personality ptr @__C_specific_handler {
entry:
  invoke void @llvm.seh.scope.begin()
          to label %invoke.cont1 unwind label %ehcleanup.outer

invoke.cont1:
  invoke void @llvm.seh.scope.begin()
          to label %invoke.cont2 unwind label %ehcleanup.middle

invoke.cont2:
  invoke void @llvm.seh.scope.begin()
          to label %invoke.cont3 unwind label %ehcleanup.inner

invoke.cont3:
  invoke void @RaiseException()
          to label %invoke.cont4 unwind label %ehcleanup.inner

invoke.cont4:
  invoke void @llvm.seh.scope.end()
          to label %invoke.cont5 unwind label %ehcleanup.inner

invoke.cont5:
  invoke void @llvm.seh.scope.end()
          to label %invoke.cont6 unwind label %ehcleanup.middle

invoke.cont6:
  invoke void @llvm.seh.scope.end()
          to label %return unwind label %ehcleanup.outer

ehcleanup.inner:
  %pad.inner = cleanuppad within none []
  invoke void @llvm.seh.scope.end() [ "funclet"(token %pad.inner) ]
          to label %ehcleanup.inner.body unwind label %ehcleanup.middle

ehcleanup.inner.body:
  ; Inner finally handler
  %0 = load i32, ptr @Counter, align 4
  %add0 = add i32 %0, 1
  store i32 %add0, ptr @Counter, align 4
  cleanupret from %pad.inner unwind label %ehcleanup.middle

ehcleanup.middle:
  %pad.middle = cleanuppad within none []
  invoke void @llvm.seh.scope.end() [ "funclet"(token %pad.middle) ]
          to label %ehcleanup.middle.body unwind label %ehcleanup.outer

ehcleanup.middle.body:
  ; Middle finally handler - calls noreturn (NO cleanupret follows!)
  %1 = load i32, ptr @Counter, align 4
  %add1 = add i32 %1, 1
  store i32 %add1, ptr @Counter, align 4
  call void @noreturn_func() [ "funclet"(token %pad.middle) ]
  ; Note: no cleanupret here! The noreturn call ends the funclet.
  unreachable

ehcleanup.outer:
  %pad.outer = cleanuppad within none []
  ; Outermost finally handler
  %2 = load i32, ptr @Counter, align 4
  %add2 = add i32 %2, 1
  store i32 %add2, ptr @Counter, align 4
  cleanupret from %pad.outer unwind to caller

return:
  ret void
}

declare i32 @__C_specific_handler(...)

; CHECK-LABEL: test_finally_noreturn_nested:
; All three finally handlers should be in scope table, even though
; the middle one has no cleanupret (due to noreturn call).
; The fix in WinEHPrepare.cpp uses seh.scope.end invoke to find the
; unwind destination when cleanupret is missing.
; CHECK: .seh_handlerdata
; CHECK: .long {{.*}}@IMGREL # FinallyFunclet
; CHECK: .long {{.*}}@IMGREL # FinallyFunclet
; CHECK: .long {{.*}}@IMGREL # FinallyFunclet

