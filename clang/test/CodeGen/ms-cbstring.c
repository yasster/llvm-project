// Comprehensive test for -fms-cbstring flag functionality
// RUN: %clang_cc1 -emit-llvm -fms-cbstring -fms-extensions %s -o - | FileCheck --check-prefixes=CBSTRING,CHECK %s
// RUN: %clang_cc1 -emit-llvm -fms-extensions %s -o - | FileCheck --check-prefixes=NORMAL,CHECK %s

// Function declarations to avoid needing system headers
int printf(const char* format, ...);

// Helper function declaration
int uses_string(const char*);

// Global scope strings
const char *global_str = "global_test";
static const char *static_global_str = "static_global_test";

// String arrays
const char *array[] = {"array_element1", "array_element2"};

// Function in default text section
void test_function() {
    const char *local_str = "local_test";
    static const char *static_local_str = "static_local_test";
    
    // Concatenated strings
    const char *concat = "concat_" "string_test";
    
    // Use strings to prevent optimization
    printf("%s %s %s\n", local_str, static_local_str, concat);
}

// Function with custom code segment
void __declspec(code_seg("other_seg")) in_other_seg(void)
{
    uses_string("test_in_other_seg");
}

int main() {
    const char *main_str = "main_function_test";
    static const char *static_main_str = "static_main_test";
    
    // Use all strings to ensure they appear in IR
    printf("%s %s %s %s %s\n", global_str, static_global_str, array[0], array[1], main_str);
    printf("%s\n", static_main_str);
    test_function();
    in_other_seg();
    
    return 0;
}

// Check string constants in order they appear in IR:
// Note: With -fms-cbstring, function strings get section attributes but remain comdats for proper deduplication
// Note: Global strings keep default section behavior (like MSVC's CONST segment)

// Global strings - should keep default section behavior (not go to .text$s)
// NORMAL: constant {{.*}} c"global_test\00"{{.*}}comdat
// CBSTRING: constant {{.*}} c"global_test\00"
// CBSTRING-NOT: section
// CBSTRING-SAME: comdat

// Array elements (global scope) - should keep default section behavior
// NORMAL: constant {{.*}} c"array_element1\00"{{.*}}comdat
// CBSTRING: constant {{.*}} c"array_element1\00"
// CBSTRING-NOT: section
// CBSTRING-SAME: comdat
// NORMAL: constant {{.*}} c"array_element2\00"{{.*}}comdat
// CBSTRING: constant {{.*}} c"array_element2\00"
// CBSTRING-NOT: section
// CBSTRING-SAME: comdat

// Function local strings go to .text$s
// CHECK: constant {{.*}} c"local_test\00"
// CBSTRING-SAME: section ".text$s"
// NORMAL-NOT: section
// CHECK-SAME: comdat

// Static local strings keep default section behavior (like MSVC)
// CHECK: constant {{.*}} c"static_local_test\00"
// CBSTRING-NOT: section
// NORMAL-NOT: section
// CHECK-SAME: comdat

// Concatenated strings in functions go to .text$s
// CHECK: constant {{.*}} c"concat_string_test\00"
// CBSTRING-SAME: section ".text$s"
// NORMAL-NOT: section
// CHECK-SAME: comdat

// Printf format strings also go to .text$s when used in functions
// CBSTRING: section ".text$s"{{.*}}comdat

// Strings in function with custom code segment go to other_seg$s
// CHECK: constant {{.*}} c"test_in_other_seg\00"
// CBSTRING-SAME: section "other_seg$s"
// NORMAL-NOT: section
// CHECK-SAME: comdat

// Main function strings go to .text$s
// CHECK: constant {{.*}} c"main_function_test\00"
// CBSTRING-SAME: section ".text$s"
// NORMAL-NOT: section
// CHECK-SAME: comdat

// Static main function strings keep default section behavior
// NORMAL: constant {{.*}} c"static_main_test\00"{{.*}}comdat
// CBSTRING: constant {{.*}} c"static_main_test\00"
// CBSTRING-NOT: section
// CBSTRING-SAME: comdat

// Static global strings keep default section behavior
// NORMAL: constant {{.*}} c"static_global_test\00"{{.*}}comdat
// CBSTRING: constant {{.*}} c"static_global_test\00"
// CBSTRING-NOT: section
// CBSTRING-SAME: comdat

// Check that functions are defined
// CHECK: define dso_local void @test_function()
// CHECK: define dso_local void @in_other_seg()
// CHECK: define dso_local i32 @main()