; RUN: sed -e s/.Amd64Seh:// %s | llc -mtriple=x86_64-pc-windows-msvc | FileCheck %s --check-prefixes=CHECK,AMD64SEH,AMD64
; RUN: sed -e s/.Amd64Cxx:// %s | llc -mtriple=x86_64-pc-windows-msvc | FileCheck %s --check-prefixes=CHECK,AMD64CXX,AMD64
; RUN: %if aarch64-registered-target %{ sed -e s/.Arm64Seh:// %s | llc -mtriple=aarch64-pc-windows-msvc | FileCheck %s --check-prefixes=CHECK,ARM64SEH,ARM64 %}
; RUN: %if aarch64-registered-target %{ sed -e s/.Arm64Cxx:// %s | llc -mtriple=aarch64-pc-windows-msvc | FileCheck %s --check-prefixes=CHECK,ARM64CXX,ARM64 %}

; Test that finally blocks are not executed twice when an exception
; is raised after the finally has already run. This tests the fix
; for duplicate SEH table emission.

declare void @external_operation()
declare ptr @allocate_buffer()
declare void @free_buffer(ptr)
declare void @RaiseException(i32, i32, i32, ptr)
declare i32 @__CxxFrameHandler3(...)
declare i32 @__C_specific_handler(...)

;Amd64Seh: define void @test_finally_double_execute(i32 %operation_type) personality ptr @__C_specific_handler {
;Amd64Cxx: define void @test_finally_double_execute(i32 %operation_type) personality ptr @__CxxFrameHandler3 {
;Arm64Seh: define void @test_finally_double_execute(i32 %operation_type) personality ptr @__C_specific_handler {
;Arm64Cxx: define void @test_finally_double_execute(i32 %operation_type) personality ptr @__CxxFrameHandler3 {
entry:
  %buffer = call ptr @allocate_buffer()
  invoke void @external_operation()
          to label %invoke.cont unwind label %ehcleanup

invoke.cont:
  %cmp = icmp eq i32 %operation_type, 1
  br i1 %cmp, label %if.then, label %if.end

if.then:
  invoke void @external_operation()
          to label %if.end unwind label %ehcleanup

if.end:
  ; Simulate the finally block running normally
  call void @free_buffer(ptr %buffer)
  ; Now raise an exception AFTER finally has run
  %cmp2 = icmp eq i32 %operation_type, 2
  br i1 %cmp2, label %raise, label %exit

raise:
  call void @RaiseException(i32 3221225477, i32 0, i32 0, ptr null)
  unreachable

exit:
  ret void

ehcleanup:
  %pad = cleanuppad within none []
  call void @free_buffer(ptr %buffer) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
}

; CHECK-LABEL: test_finally_double_execute:
; CHECK: .seh_proc test_finally_double_execute
; CHECK: .seh_handler

; For SEH personalities, verify the main function's handler data
; The fix ensures this appears exactly once, not duplicated
; AMD64SEH: .seh_handlerdata
; AMD64SEH: .long (.Llsda_end0-.Llsda_begin0)/16
; AMD64SEH: .Llsda_begin0:
; AMD64SEH: .long {{.*}}IMGREL
; AMD64SEH: .long {{.*}}IMGREL{{.*}}
; AMD64SEH: .long {{.*}}IMGREL
; AMD64SEH: .long 0
; AMD64SEH: .Llsda_end0:
; AMD64SEH-NOT: .Llsda_begin1:
; AMD64SEH: .text
; AMD64SEH: .seh_endproc

; ARM64SEH: .seh_handlerdata
; ARM64SEH: .word (.Llsda_end0-.Llsda_begin0)/16
; ARM64SEH: .Llsda_begin0:
; ARM64SEH: .word {{.*}}IMGREL
; ARM64SEH: .word {{.*}}IMGREL{{.*}}
; ARM64SEH: .word {{.*}}IMGREL
; ARM64SEH: .word 0
; ARM64SEH: .Llsda_end0:
; ARM64SEH-NOT: .Llsda_begin1:
; ARM64SEH: .text
; ARM64SEH: .seh_endproc

; For C++ personalities, verify the handler data references the cppxdata
; AMD64CXX: .seh_handlerdata
; AMD64CXX: .long $cppxdata$test_finally_double_execute@IMGREL
; AMD64CXX: .text
; AMD64CXX: .seh_endproc

; ARM64CXX: .seh_handlerdata
; ARM64CXX: .word $cppxdata$test_finally_double_execute@IMGREL
; ARM64CXX: .text
; ARM64CXX: .seh_endproc

; Verify the cleanup funclet exists and has proper structure
; CHECK-LABEL: "?dtor${{[0-9]+}}@?0?test_finally_double_execute@4HA":
; CHECK: .seh_proc
; AMD64: callq free_buffer
; ARM64: bl free_buffer
; CHECK: .seh_handlerdata
; CHECK: .seh_endproc

; For C++ personalities, verify the xdata section comes at the end
; AMD64CXX: .section .xdata,"dr"
; AMD64CXX: $cppxdata$test_finally_double_execute:
; AMD64CXX: .long 429065506
; AMD64CXX-NOT: $cppxdata$test_finally_double_execute:

; ARM64CXX: .section .xdata,"dr"
; ARM64CXX: $cppxdata$test_finally_double_execute:
; ARM64CXX: .word 429065506
; ARM64CXX-NOT: $cppxdata$test_finally_double_execute: