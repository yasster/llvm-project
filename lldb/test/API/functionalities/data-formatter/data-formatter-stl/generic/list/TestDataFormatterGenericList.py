"""
Test lldb data formatter subsystem.
"""


import lldb
from lldbsuite.test.decorators import *
from lldbsuite.test.lldbtest import *
from lldbsuite.test import lldbutil


class GenericListDataFormatterTestCase(TestBase):
    def setUp(self):
        # Call super's setUp().
        TestBase.setUp(self)
        # Find the line numbers to break at for the different tests.
        self.line = line_number("main.cpp", "// Set break point at this line.")
        self.optional_line = line_number(
            "main.cpp", "// Optional break point at this line."
        )
        self.final_line = line_number(
            "main.cpp", "// Set final break point at this line."
        )

    def do_test_with_run_command(self, *, is_libstdcpp=False):
        """Test that that file and class static variables display correctly."""
        self.runCmd("file " + self.getBuildArtifact("a.out"), CURRENT_EXECUTABLE_SET)

        lldbutil.run_break_set_by_file_and_line(
            self, "main.cpp", self.line, num_expected_locations=-1
        )

        self.runCmd("run", RUN_SUCCEEDED)

        # The stop reason of the thread should be breakpoint.
        self.expect(
            "thread list",
            STOPPED_DUE_TO_BREAKPOINT,
            substrs=["stopped", "stop reason = breakpoint"],
        )

        # This is the function to remove the custom formats in order to have a
        # clean slate for the next test case.
        def cleanup():
            self.runCmd("type format clear", check=False)
            self.runCmd("type summary clear", check=False)
            self.runCmd("type filter clear", check=False)
            self.runCmd("type synth clear", check=False)

        # Execute the cleanup function during test case tear down.
        self.addTearDownHook(cleanup)

        self.runCmd("frame variable numbers_list --show-types")

        self.runCmd("type format add -f hex int")

        self.expect(
            "frame variable numbers_list --raw", matching=False, substrs=["size=0"]
        )

        if is_libstdcpp:
            self.expect(
                "frame variable &numbers_list._M_impl._M_node --raw",
                matching=False,
                substrs=["size=0", "{}"],
            )

        self.expect("frame variable numbers_list", substrs=["size=0", "{}"])

        self.expect("expression numbers_list", substrs=["size=0", "{}"])

        self.runCmd("n")

        self.expect(
            "frame variable numbers_list", substrs=["size=1", "[0] = ", "0x12345678"]
        )

        self.runCmd("n")
        self.runCmd("n")
        self.runCmd("n")

        self.expect(
            "frame variable numbers_list",
            substrs=[
                "size=4",
                "[0] = ",
                "0x12345678",
                "[1] =",
                "0x11223344",
                "[2] =",
                "0xbeeffeed",
                "[3] =",
                "0x00abba00",
            ],
        )

        self.runCmd("n")
        self.runCmd("n")

        self.expect(
            "frame variable numbers_list",
            substrs=[
                "size=6",
                "[0] = ",
                "0x12345678",
                "0x11223344",
                "0xbeeffeed",
                "0x00abba00",
                "[4] =",
                "0x0abcdef0",
                "[5] =",
                "0x0cab0cab",
            ],
        )

        self.expect(
            "expression numbers_list",
            substrs=[
                "size=6",
                "[0] = ",
                "0x12345678",
                "0x11223344",
                "0xbeeffeed",
                "0x00abba00",
                "[4] =",
                "0x0abcdef0",
                "[5] =",
                "0x0cab0cab",
            ],
        )

        # check access-by-index
        self.expect("frame variable numbers_list[0]", substrs=["0x12345678"])
        self.expect("frame variable numbers_list[1]", substrs=["0x11223344"])

        # but check that expression does not rely on us
        self.expect(
            "expression numbers_list[0]",
            matching=False,
            error=True,
            substrs=["0x12345678"],
        )

        # check that MightHaveChildren() gets it right
        self.assertTrue(
            self.frame().FindVariable("numbers_list").MightHaveChildren(),
            "numbers_list.MightHaveChildren() says False for non empty!",
        )

        self.runCmd("n")

        self.expect("frame variable numbers_list", substrs=["size=0", "{}"])

        self.runCmd("n")
        self.runCmd("n")
        self.runCmd("n")
        self.runCmd("n")

        self.expect(
            "frame variable numbers_list",
            substrs=[
                "size=4",
                "[0] = ",
                "1",
                "[1] = ",
                "2",
                "[2] = ",
                "3",
                "[3] = ",
                "4",
            ],
        )

        self.runCmd("type format delete int")

        lldbutil.run_break_set_by_file_and_line(self, "main.cpp", self.optional_line)
        self.runCmd("continue")

        self.expect("frame variable text_list", substrs=["size=0", "{}"])

        lldbutil.run_break_set_by_file_and_line(
            self, "main.cpp", self.final_line, num_expected_locations=-1
        )

        self.runCmd("c", RUN_SUCCEEDED)

        # The stop reason of the thread should be breakpoint.
        self.expect(
            "thread list",
            STOPPED_DUE_TO_BREAKPOINT,
            substrs=["stopped", "stop reason = breakpoint"],
        )

        self.expect(
            "frame variable text_list",
            substrs=[
                "size=4",
                "[0]",
                "goofy",
                "[1]",
                "is",
                "[2]",
                "smart",
                "[3]",
                "!!!",
            ],
        )

        self.expect(
            "expression text_list",
            substrs=["size=4", '"goofy"', '"is"', '"smart"', '"!!!"'],
        )

        # check access-by-index
        self.expect("frame variable text_list[0]", substrs=["goofy"])
        self.expect("frame variable text_list[3]", substrs=["!!!"])

        # but check that expression does not rely on us
        self.expect(
            "expression text_list[0]", matching=False, error=True, substrs=["goofy"]
        )

        # check that MightHaveChildren() gets it right
        self.assertTrue(
            self.frame().FindVariable("text_list").MightHaveChildren(),
            "text_list.MightHaveChildren() says False for non empty!",
        )

    def do_test_ptr_and_ref(self):
        """Test that ref and ptr to std::list is displayed correctly"""
        (_, process, _, bkpt) = lldbutil.run_to_source_breakpoint(
            self, "Check ref and ptr", lldb.SBFileSpec("main.cpp", False)
        )

        self.expect(
            "frame variable ref",
            substrs=[
                "size=4",
                "[0] = ",
                "1",
                "[1] = ",
                "2",
                "[2] = ",
                "3",
                "[3] = ",
                "4",
            ],
        )

        self.expect(
            "frame variable *ptr",
            substrs=[
                "size=4",
                "[0] = ",
                "1",
                "[1] = ",
                "2",
                "[2] = ",
                "3",
                "[3] = ",
                "4",
            ],
        )

        lldbutil.continue_to_breakpoint(process, bkpt)

        self.expect(
            "frame variable ref",
            substrs=[
                "size=4",
                "[0]",
                "goofy",
                "[1]",
                "is",
                "[2]",
                "smart",
                "[3]",
                "!!!",
            ],
        )

        self.expect(
            "frame variable *ptr",
            substrs=[
                "size=4",
                "[0]",
                "goofy",
                "[1]",
                "is",
                "[2]",
                "smart",
                "[3]",
                "!!!",
            ],
        )

    @add_test_categories(["libstdcxx"])
    def test_with_run_command_libstdcpp(self):
        self.build(dictionary={"USE_LIBSTDCPP": 1})
        self.do_test_with_run_command(is_libstdcpp=True)

    @add_test_categories(["libstdcxx"])
    def test_ptr_and_ref_libstdcpp(self):
        self.build(dictionary={"USE_LIBSTDCPP": 1})
        self.do_test_ptr_and_ref()

    @add_test_categories(["libc++"])
    def test_with_run_command_libcpp(self):
        self.build(dictionary={"USE_LIBCPP": 1})
        self.do_test_with_run_command()

    @add_test_categories(["libc++"])
    def test_ptr_and_ref_libcpp(self):
        self.build(dictionary={"USE_LIBCPP": 1})
        self.do_test_ptr_and_ref()

    @add_test_categories(["msvcstl"])
    def test_with_run_command_msvcstl(self):
        # No flags, because the "msvcstl" category checks that the MSVC STL is used by default.
        self.build()
        self.do_test_with_run_command()

    @add_test_categories(["msvcstl"])
    def test_ptr_and_ref_msvcstl(self):
        self.build()
        self.do_test_ptr_and_ref()
