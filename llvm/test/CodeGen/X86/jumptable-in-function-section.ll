; Test that force-jumptable-in-function-section module flag controls jump table placement
; RUN: sed -e 's/;WITHFLAG://g' %s | llc -mtriple=x86_64-pc-windows-msvc -filetype=asm | FileCheck -check-prefix=WITH_FLAG %s
; RUN: sed -e 's/;WITHOUTFLAG://g' %s | llc -mtriple=x86_64-pc-windows-msvc -filetype=asm | FileCheck -check-prefix=WITHOUT_FLAG %s

define i32 @test_switch(i32 %x) {
entry:
  switch i32 %x, label %default [
    i32 1, label %sw.bb
    i32 2, label %sw.bb1
    i32 3, label %sw.bb2
    i32 4, label %sw.bb3
    i32 5, label %sw.bb4
    i32 6, label %sw.bb5
    i32 7, label %sw.bb6
    i32 8, label %sw.bb7
    i32 9, label %sw.bb8
    i32 10, label %sw.bb9
  ]

sw.bb:
  ret i32 10
sw.bb1:
  ret i32 20
sw.bb2:
  ret i32 30
sw.bb3:
  ret i32 40
sw.bb4:
  ret i32 50
sw.bb5:
  ret i32 60
sw.bb6:
  ret i32 70
sw.bb7:
  ret i32 80
sw.bb8:
  ret i32 90
sw.bb9:
  ret i32 100
default:
  ret i32 0
}

; WITH_FLAG: .text
; WITH_FLAG: test_switch:
; WITH_FLAG: .LJTI{{[0-9]+}}_{{[0-9]+}}:
; WITH_FLAG-NOT: .section{{.*}}rdata

; WITHOUT_FLAG: .section{{.*}}rdata
; WITHOUT_FLAG: .LJTI{{[0-9]+}}_{{[0-9]+}}:

; WITHFLAG: !llvm.module.flags = !{!0}
; WITHFLAG: !0 = !{i32 2, !"x64-force-jumptable-in-function-section", i32 1}

; Verify that without the flag, the module flag is not present
; WITHOUTFLAG-NOT: x64-force-jumptable-in-function-section