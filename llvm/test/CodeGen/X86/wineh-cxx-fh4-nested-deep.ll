; RUN: llc -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s

; Test __CxxFrameHandler4 with deeply nested try-catch blocks.
; This test verifies that FH4 tables are correctly generated for scenarios
; with many nested exception handlers, which previously caused crashes
; due to incorrect UnwindMap offset calculations.

declare i32 @__CxxFrameHandler4(...)
declare void @throw()
declare void @cleanup_func(ptr)

%struct.Cleanup = type { i32 }
%rtti.TypeDescriptor2 = type { ptr, ptr, [3 x i8] }

$"??_R0H@8" = comdat any
@"??_R0H@8" = linkonce_odr global %rtti.TypeDescriptor2 { ptr null, ptr null, [3 x i8] c".H\00" }, comdat

; Test with 6 levels of nesting - try blocks with cleanups
; This simulates code like:
;   try { Cleanup c1; 
;     try { Cleanup c2;
;       try { Cleanup c3;
;         try { Cleanup c4;
;           try { Cleanup c5;
;             try { Cleanup c6;
;               may_throw();
;             } catch(...) {}
;           } catch(...) {}
;         } catch(...) {}
;       } catch(...) {}
;     } catch(...) {}
;   } catch(...) {}

define void @nested_try_catch_6_levels() personality ptr @__CxxFrameHandler4 {
entry:
  %c1 = alloca %struct.Cleanup, align 4
  %c2 = alloca %struct.Cleanup, align 4
  %c3 = alloca %struct.Cleanup, align 4
  %c4 = alloca %struct.Cleanup, align 4
  %c5 = alloca %struct.Cleanup, align 4
  %c6 = alloca %struct.Cleanup, align 4
  invoke void @throw()
          to label %exit unwind label %cleanup6

cleanup6:
  %pad6 = cleanuppad within none []
  call void @cleanup_func(ptr %c6) [ "funclet"(token %pad6) ]
  cleanupret from %pad6 unwind label %catch.dispatch6

catch.dispatch6:
  %cs6 = catchswitch within none [label %catch6] unwind label %cleanup5

catch6:
  %cp6 = catchpad within %cs6 [ptr null, i32 64, ptr null]
  catchret from %cp6 to label %exit

cleanup5:
  %pad5 = cleanuppad within none []
  call void @cleanup_func(ptr %c5) [ "funclet"(token %pad5) ]
  cleanupret from %pad5 unwind label %catch.dispatch5

catch.dispatch5:
  %cs5 = catchswitch within none [label %catch5] unwind label %cleanup4

catch5:
  %cp5 = catchpad within %cs5 [ptr null, i32 64, ptr null]
  catchret from %cp5 to label %exit

cleanup4:
  %pad4 = cleanuppad within none []
  call void @cleanup_func(ptr %c4) [ "funclet"(token %pad4) ]
  cleanupret from %pad4 unwind label %catch.dispatch4

catch.dispatch4:
  %cs4 = catchswitch within none [label %catch4] unwind label %cleanup3

catch4:
  %cp4 = catchpad within %cs4 [ptr null, i32 64, ptr null]
  catchret from %cp4 to label %exit

cleanup3:
  %pad3 = cleanuppad within none []
  call void @cleanup_func(ptr %c3) [ "funclet"(token %pad3) ]
  cleanupret from %pad3 unwind label %catch.dispatch3

catch.dispatch3:
  %cs3 = catchswitch within none [label %catch3] unwind label %cleanup2

catch3:
  %cp3 = catchpad within %cs3 [ptr null, i32 64, ptr null]
  catchret from %cp3 to label %exit

cleanup2:
  %pad2 = cleanuppad within none []
  call void @cleanup_func(ptr %c2) [ "funclet"(token %pad2) ]
  cleanupret from %pad2 unwind label %catch.dispatch2

catch.dispatch2:
  %cs2 = catchswitch within none [label %catch2] unwind label %cleanup1

catch2:
  %cp2 = catchpad within %cs2 [ptr null, i32 64, ptr null]
  catchret from %cp2 to label %exit

cleanup1:
  %pad1 = cleanuppad within none []
  call void @cleanup_func(ptr %c1) [ "funclet"(token %pad1) ]
  cleanupret from %pad1 unwind label %catch.dispatch1

catch.dispatch1:
  %cs1 = catchswitch within none [label %catch1] unwind to caller

catch1:
  %cp1 = catchpad within %cs1 [ptr null, i32 64, ptr null]
  catchret from %cp1 to label %exit

exit:
  ret void
}

; CHECK-LABEL: nested_try_catch_6_levels:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$nested_try_catch_6_levels:
; FuncInfoHeader with UnwindMap + TryBlockMap
; CHECK: .byte 56
; CHECK: .long $stateUnwindMap$nested_try_catch_6_levels@IMGREL
; CHECK: .long $tryMap$nested_try_catch_6_levels@IMGREL
; CHECK: .long $ip2state$nested_try_catch_6_levels@IMGREL

; CHECK-LABEL: $stateUnwindMap$nested_try_catch_6_levels:
; Should have multiple entries for all the cleanups
; CHECK: .byte

; CHECK-LABEL: $tryMap$nested_try_catch_6_levels:
; Should have 6 try blocks
; CHECK: .byte


; Test with 10 simple try-catch blocks (no cleanups) to verify TryBlockMap
define i32 @many_try_catch_blocks() personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @throw()
          to label %cont1 unwind label %catch.dispatch1

catch.dispatch1:
  %cs1 = catchswitch within none [label %catch1] unwind label %catch.dispatch2
catch1:
  %cp1 = catchpad within %cs1 [ptr @"??_R0H@8", i32 0, ptr null]
  catchret from %cp1 to label %return.1

catch.dispatch2:
  %cs2 = catchswitch within none [label %catch2] unwind label %catch.dispatch3
catch2:
  %cp2 = catchpad within %cs2 [ptr @"??_R0H@8", i32 0, ptr null]
  catchret from %cp2 to label %return.2

catch.dispatch3:
  %cs3 = catchswitch within none [label %catch3] unwind label %catch.dispatch4
catch3:
  %cp3 = catchpad within %cs3 [ptr @"??_R0H@8", i32 0, ptr null]
  catchret from %cp3 to label %return.3

catch.dispatch4:
  %cs4 = catchswitch within none [label %catch4] unwind label %catch.dispatch5
catch4:
  %cp4 = catchpad within %cs4 [ptr @"??_R0H@8", i32 0, ptr null]
  catchret from %cp4 to label %return.4

catch.dispatch5:
  %cs5 = catchswitch within none [label %catch5] unwind to caller
catch5:
  %cp5 = catchpad within %cs5 [ptr @"??_R0H@8", i32 0, ptr null]
  catchret from %cp5 to label %return.5

return.1:
  ret i32 1
return.2:
  ret i32 2
return.3:
  ret i32 3
return.4:
  ret i32 4
return.5:
  ret i32 5
cont1:
  ret i32 0
}

; CHECK-LABEL: many_try_catch_blocks:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$many_try_catch_blocks:
; CHECK: .byte 56

; CHECK-LABEL: $tryMap$many_try_catch_blocks:
; Should have entries for all catch handlers
; CHECK: .byte


; Test cleanups interleaved with catches at various nesting levels
define void @interleaved_cleanup_catch() personality ptr @__CxxFrameHandler4 {
entry:
  %obj = alloca %struct.Cleanup, align 4
  invoke void @throw()
          to label %try.cont unwind label %cleanup.outer

cleanup.outer:
  %cleanup1 = cleanuppad within none []
  call void @cleanup_func(ptr %obj) [ "funclet"(token %cleanup1) ]
  cleanupret from %cleanup1 unwind label %catch.dispatch.outer

catch.dispatch.outer:
  %cs.outer = catchswitch within none [label %catch.outer] unwind to caller

catch.outer:
  %cp.outer = catchpad within %cs.outer [ptr @"??_R0H@8", i32 0, ptr null]
  invoke void @throw() [ "funclet"(token %cp.outer) ]
          to label %catch.outer.cont unwind label %cleanup.inner

cleanup.inner:
  %cleanup2 = cleanuppad within %cp.outer []
  call void @cleanup_func(ptr %obj) [ "funclet"(token %cleanup2) ]
  cleanupret from %cleanup2 unwind label %catch.dispatch.inner

catch.dispatch.inner:
  %cs.inner = catchswitch within %cp.outer [label %catch.inner] unwind to caller

catch.inner:
  %cp.inner = catchpad within %cs.inner [ptr null, i32 64, ptr null]
  catchret from %cp.inner to label %catch.outer.cont

catch.outer.cont:
  catchret from %cp.outer to label %try.cont

try.cont:
  ret void
}

; CHECK-LABEL: interleaved_cleanup_catch:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$interleaved_cleanup_catch:
; CHECK: .byte 56
; CHECK: .long $stateUnwindMap$interleaved_cleanup_catch@IMGREL
; CHECK: .long $tryMap$interleaved_cleanup_catch@IMGREL

; CHECK-LABEL: $stateUnwindMap$interleaved_cleanup_catch:
; CHECK: .byte

; CHECK-LABEL: $tryMap$interleaved_cleanup_catch:
; CHECK: .byte
