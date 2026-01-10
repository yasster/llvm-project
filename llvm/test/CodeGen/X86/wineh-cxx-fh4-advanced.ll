; RUN: llc -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s

; Test __CxxFrameHandler4 with multiple catch handlers.

declare i32 @__CxxFrameHandler4(...)
declare void @throw()

; Type descriptors for different exception types
%rtti.TypeDescriptor2 = type { ptr, ptr, [3 x i8] }
%rtti.TypeDescriptor8 = type { ptr, ptr, [9 x i8] }

$"??_R0H@8" = comdat any
@"??_R0H@8" = linkonce_odr global %rtti.TypeDescriptor2 { ptr null, ptr null, [3 x i8] c".H\00" }, comdat

$"??_R0PAX@8" = comdat any
@"??_R0PAX@8" = linkonce_odr global %rtti.TypeDescriptor2 { ptr null, ptr null, [3 x i8] c".X\00" }, comdat

; Test multiple catch handlers in one try block
define i32 @multiple_catch() personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @throw()
          to label %try.cont unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch.int, label %catch.all] unwind to caller

catch.int:
  %cp.int = catchpad within %cs [ptr @"??_R0H@8", i32 0, ptr null]
  catchret from %cp.int to label %return.1

catch.all:
  %cp.all = catchpad within %cs [ptr null, i32 64, ptr null]
  catchret from %cp.all to label %return.neg1

return.1:
  ret i32 1

return.neg1:
  ret i32 -1

try.cont:
  ret i32 0
}

; CHECK-LABEL: multiple_catch:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$multiple_catch:
; FuncInfoHeader = 0x38 (UnwindMap + TryBlockMap + EHs)
; CHECK: .byte 56
; CHECK: .long $stateUnwindMap$multiple_catch@IMGREL
; CHECK: .long $tryMap$multiple_catch@IMGREL
; CHECK: .long $ip2state$multiple_catch@IMGREL

; CHECK-LABEL: $handlerMap$0$multiple_catch:
; Should have 2 handlers
; CHECK: .byte


; Test nested try/catch blocks
define i32 @nested_try() personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @throw()
          to label %invoke.cont unwind label %catch.dispatch.outer

invoke.cont:
  invoke void @throw()
          to label %try.cont unwind label %catch.dispatch.inner

catch.dispatch.inner:
  %cs.inner = catchswitch within none [label %catch.inner] unwind label %catch.dispatch.outer

catch.inner:
  %cp.inner = catchpad within %cs.inner [ptr @"??_R0H@8", i32 0, ptr null]
  catchret from %cp.inner to label %try.cont

catch.dispatch.outer:
  %cs.outer = catchswitch within none [label %catch.outer] unwind to caller

catch.outer:
  %cp.outer = catchpad within %cs.outer [ptr null, i32 64, ptr null]
  catchret from %cp.outer to label %return.outer

return.outer:
  ret i32 -1

try.cont:
  ret i32 0
}

; CHECK-LABEL: nested_try:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$nested_try:
; CHECK: .byte 56
; CHECK-LABEL: $tryMap$nested_try:
; Should have 2 try blocks for nested structure
; CHECK: .byte


; Test cleanup with catch (destructor + catch handler)
%struct.Cleanup = type { i32 }
declare void @cleanup_func(ptr)

define i32 @cleanup_and_catch() personality ptr @__CxxFrameHandler4 {
entry:
  %obj = alloca %struct.Cleanup, align 4
  invoke void @throw()
          to label %try.cont unwind label %ehcleanup

ehcleanup:
  %cleanup = cleanuppad within none []
  call void @cleanup_func(ptr %obj) [ "funclet"(token %cleanup) ]
  cleanupret from %cleanup unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr @"??_R0H@8", i32 0, ptr null]
  catchret from %cp to label %return.caught

return.caught:
  ret i32 42

try.cont:
  ret i32 0
}

; CHECK-LABEL: cleanup_and_catch:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$cleanup_and_catch:
; CHECK: .byte 56
; CHECK-LABEL: $stateUnwindMap$cleanup_and_catch:
; Should have cleanup entries
; CHECK: .byte
