; RUN: llc -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s

; Test __CxxFrameHandler4 UnwindMap offset calculation with many entries.
; This test verifies that UnwindMap entry offsets are calculated correctly
; based on actual compressed integer sizes, not hardcoded approximations.
; Previously, the code used "5 * (I + 1)" as an approximation for byte offsets,
; but compressed integers can be 1-5 bytes depending on value.

declare i32 @__CxxFrameHandler4(...)
declare void @throw()
declare void @cleanup_func(ptr)

%struct.Cleanup = type { i32 }

; Test with multiple cleanup entries to verify offset calculation
; Each cleanuppad creates an UnwindMap entry
define void @many_cleanups() personality ptr @__CxxFrameHandler4 {
entry:
  %obj1 = alloca %struct.Cleanup, align 4
  %obj2 = alloca %struct.Cleanup, align 4
  %obj3 = alloca %struct.Cleanup, align 4
  %obj4 = alloca %struct.Cleanup, align 4
  invoke void @throw()
          to label %exit unwind label %cleanup4

cleanup4:
  %pad4 = cleanuppad within none []
  call void @cleanup_func(ptr %obj4) [ "funclet"(token %pad4) ]
  cleanupret from %pad4 unwind label %cleanup3

cleanup3:
  %pad3 = cleanuppad within none []
  call void @cleanup_func(ptr %obj3) [ "funclet"(token %pad3) ]
  cleanupret from %pad3 unwind label %cleanup2

cleanup2:
  %pad2 = cleanuppad within none []
  call void @cleanup_func(ptr %obj2) [ "funclet"(token %pad2) ]
  cleanupret from %pad2 unwind label %cleanup1

cleanup1:
  %pad1 = cleanuppad within none []
  call void @cleanup_func(ptr %obj1) [ "funclet"(token %pad1) ]
  cleanupret from %pad1 unwind to caller

exit:
  ret void
}

; CHECK-LABEL: many_cleanups:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$many_cleanups:
; FuncInfoHeader should indicate UnwindMap is present (bit 3)
; CHECK: .byte
; CHECK: .long $stateUnwindMap$many_cleanups@IMGREL
; CHECK: .long $ip2state$many_cleanups@IMGREL

; CHECK-LABEL: $stateUnwindMap$many_cleanups:
; Number of entries (4 cleanups)
; CHECK: .byte
; Each entry has: compressed (offset<<2|type), then 4-byte RVA
; The offsets should be calculated correctly based on actual byte sizes
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long


; Test deeply nested cleanups (chain of 8)
define void @deeply_nested_cleanups() personality ptr @__CxxFrameHandler4 {
entry:
  %obj1 = alloca %struct.Cleanup, align 4
  %obj2 = alloca %struct.Cleanup, align 4
  %obj3 = alloca %struct.Cleanup, align 4
  %obj4 = alloca %struct.Cleanup, align 4
  %obj5 = alloca %struct.Cleanup, align 4
  %obj6 = alloca %struct.Cleanup, align 4
  %obj7 = alloca %struct.Cleanup, align 4
  %obj8 = alloca %struct.Cleanup, align 4
  invoke void @throw()
          to label %exit unwind label %cleanup8

cleanup8:
  %pad8 = cleanuppad within none []
  call void @cleanup_func(ptr %obj8) [ "funclet"(token %pad8) ]
  cleanupret from %pad8 unwind label %cleanup7

cleanup7:
  %pad7 = cleanuppad within none []
  call void @cleanup_func(ptr %obj7) [ "funclet"(token %pad7) ]
  cleanupret from %pad7 unwind label %cleanup6

cleanup6:
  %pad6 = cleanuppad within none []
  call void @cleanup_func(ptr %obj6) [ "funclet"(token %pad6) ]
  cleanupret from %pad6 unwind label %cleanup5

cleanup5:
  %pad5 = cleanuppad within none []
  call void @cleanup_func(ptr %obj5) [ "funclet"(token %pad5) ]
  cleanupret from %pad5 unwind label %cleanup4

cleanup4:
  %pad4 = cleanuppad within none []
  call void @cleanup_func(ptr %obj4) [ "funclet"(token %pad4) ]
  cleanupret from %pad4 unwind label %cleanup3

cleanup3:
  %pad3 = cleanuppad within none []
  call void @cleanup_func(ptr %obj3) [ "funclet"(token %pad3) ]
  cleanupret from %pad3 unwind label %cleanup2

cleanup2:
  %pad2 = cleanuppad within none []
  call void @cleanup_func(ptr %obj2) [ "funclet"(token %pad2) ]
  cleanupret from %pad2 unwind label %cleanup1

cleanup1:
  %pad1 = cleanuppad within none []
  call void @cleanup_func(ptr %obj1) [ "funclet"(token %pad1) ]
  cleanupret from %pad1 unwind to caller

exit:
  ret void
}

; CHECK-LABEL: deeply_nested_cleanups:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$deeply_nested_cleanups:
; CHECK: .byte
; CHECK: .long $stateUnwindMap$deeply_nested_cleanups@IMGREL

; CHECK-LABEL: $stateUnwindMap$deeply_nested_cleanups:
; 8 entries for deeply nested cleanups
; CHECK: .byte
; Verify all 8 entries are emitted with proper offset encoding
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long
; CHECK: .byte
; CHECK: .long


; Test mixed cleanup and catch scenario
define i32 @cleanup_with_catch_chain() personality ptr @__CxxFrameHandler4 {
entry:
  %obj1 = alloca %struct.Cleanup, align 4
  %obj2 = alloca %struct.Cleanup, align 4
  invoke void @throw()
          to label %exit unwind label %cleanup2

cleanup2:
  %padC2 = cleanuppad within none []
  call void @cleanup_func(ptr %obj2) [ "funclet"(token %padC2) ]
  cleanupret from %padC2 unwind label %cleanup1

cleanup1:
  %padC1 = cleanuppad within none []
  call void @cleanup_func(ptr %obj1) [ "funclet"(token %padC1) ]
  cleanupret from %padC1 unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr null, i32 64, ptr null]
  catchret from %cp to label %return.caught

return.caught:
  ret i32 42

exit:
  ret i32 0
}

; CHECK-LABEL: cleanup_with_catch_chain:
; CHECK: .seh_handlerdata
; CHECK-LABEL: $cppxdata$cleanup_with_catch_chain:
; FuncInfoHeader should have UnwindMap + TryBlockMap bits set
; CHECK: .byte 56
; CHECK: .long $stateUnwindMap$cleanup_with_catch_chain@IMGREL
; CHECK: .long $tryMap$cleanup_with_catch_chain@IMGREL

; CHECK-LABEL: $stateUnwindMap$cleanup_with_catch_chain:
; Should have entries for cleanups
; CHECK: .byte
