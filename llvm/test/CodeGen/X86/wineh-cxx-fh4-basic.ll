; RUN: llc -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s

; Test basic __CxxFrameHandler4 table emission with compressed format.

declare i32 @__CxxFrameHandler4(...)
declare void @throw()

%struct.Cleanup = type { i32 }

define void @simple_cleanup() personality ptr @__CxxFrameHandler4 {
entry:
  %obj = alloca %struct.Cleanup, align 4
  invoke void @throw()
          to label %exit unwind label %cleanup

cleanup:
  %pad = cleanuppad within none []
  call void @cleanup_func(ptr %obj) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller

exit:
  ret void
}

declare void @cleanup_func(ptr)

; CHECK-LABEL: simple_cleanup:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$simple_cleanup:
; FH4 has no magic number - just starts with FuncInfoHeader byte
; CHECK-NOT: .long 429065506
; FuncInfoHeader = 0x28 (bit 3 = UnwindMap present, bit 5 = EHs sync exceptions)
; CHECK: .byte 40
; CHECK: .long $stateUnwindMap$simple_cleanup@IMGREL
; CHECK: .long $ip2state$simple_cleanup@IMGREL

; CHECK-LABEL: $stateUnwindMap$simple_cleanup:
; Number of entries compressed as byte
; CHECK: .byte

; CHECK-LABEL: $ip2state$simple_cleanup:
; Number of entries compressed as byte
; CHECK: .byte

; Test try/catch with __CxxFrameHandler4

%rtti.TypeDescriptor2 = type { ptr, ptr, [3 x i8] }
$"??_R0H@8" = comdat any
@"??_R0H@8" = linkonce_odr global %rtti.TypeDescriptor2 { ptr null, ptr null, [3 x i8] c".H\00" }, comdat

define i32 @try_catch() personality ptr @__CxxFrameHandler4 {
entry:
  %retval = alloca i32, align 4
  invoke void @throw()
          to label %try.cont unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr @"??_R0H@8", i32 0, ptr null]
  store i32 42, ptr %retval, align 4
  catchret from %cp to label %try.cont

try.cont:
  %rv = load i32, ptr %retval, align 4
  ret i32 %rv
}

; CHECK-LABEL: try_catch:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$try_catch:
; CHECK-NOT: .long 429065506
; FuncInfoHeader = 0x38 (UnwindMap + TryBlockMap + EHs)
; CHECK: .byte 56
; CHECK: .long $stateUnwindMap$try_catch@IMGREL
; CHECK: .long $tryMap$try_catch@IMGREL
; CHECK: .long $ip2state$try_catch@IMGREL

; CHECK-LABEL: $stateUnwindMap$try_catch:
; CHECK: .byte

; CHECK-LABEL: $tryMap$try_catch:
; CHECK: .byte

; CHECK-LABEL: $handlerMap$0$try_catch:
; CHECK: .byte

; Test that we emit IPtoStateMap with compressed format
; CHECK-LABEL: $ip2state$try_catch:
; The number of entries should be compressed
; CHECK: .byte
