// REQUIRES: x86-registered-target
// Test that -fx64-force-jumptable-in-function-section controls jump table placement via module flags
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -fx64-force-jumptable-in-function-section -S -o - %s | FileCheck -check-prefix=WITH_FLAG %s
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -fx64-force-jumptable-in-function-section -emit-llvm -o - %s | FileCheck -check-prefix=WITH_FLAG_IR %s
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -S -o - %s | FileCheck -check-prefix=WITHOUT_FLAG %s
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -emit-llvm -o - %s | FileCheck -check-prefix=WITHOUT_FLAG_IR %s

int test_switch(int x) {
    switch(x) {
        case 1: return 10;
        case 2: return 20;
        case 3: return 30;
        case 4: return 40;
        case 5: return 50;
        case 6: return 60;
        case 7: return 70;
        case 8: return 80;
        case 9: return 90;
        case 10: return 100;
        case 11: return 110;
        case 12: return 120;
        case 13: return 130;
        case 14: return 140;
        case 15: return 150;
        case 16: return 160;
        default: return 0;
    }
}

// Assembly checks - jump table placement controlled by module flags
// WITH_FLAG: .text
// WITH_FLAG: test_switch:  
// WITH_FLAG: .LJTI{{[0-9]+}}_{{[0-9]+}}:
// WITH_FLAG-NOT: .section{{.*}}rdata

// WITHOUT_FLAG: .section{{.*}}rdata
// WITHOUT_FLAG: .LJTI{{[0-9]+}}_{{[0-9]+}}:
// WITHOUT_FLAG-NOT: x64-force-jumptable-in-function-section

// IR checks - module flag generation
// WITH_FLAG_IR: !llvm.module.flags = !{{{.*}}}
// WITH_FLAG_IR: !{{[0-9]+}} = !{i32 2, !"x64-force-jumptable-in-function-section", i32 1}
