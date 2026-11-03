import os
import subprocess
import sys
import tempfile
import unittest

RUNNER = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "scripts", "run_tests.py")


class RunTestsTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = self._tmp.name

    def tearDown(self):
        self._tmp.cleanup()

    def fixture(self, name, source):
        path = os.path.join(self.dir, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(source)
        return path

    def run_runner(self, *files, jobs=1):
        return subprocess.run(
            [sys.executable, RUNNER, "--jobs", str(jobs), *files],
            capture_output=True,
            text=True,
            timeout=120,
        )

    def test_exits_zero_when_every_file_passes(self):
        a = self.fixture("test_a.lua", "assert(1 + 1 == 2)\n")
        b = self.fixture("test_b.lua", "return function() assert(true) end\n")

        result = self.run_runner(a, b, jobs=2)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("2 files, 0 failed", result.stdout)

    def test_failing_file_exits_one_and_later_files_still_run(self):
        bad = self.fixture("test_a_bad.lua", "assert(false, 'boom')\n")
        good = self.fixture("test_b_good.lua", "print('good file ran')\n")

        result = self.run_runner(bad, good)

        self.assertEqual(result.returncode, 1)
        self.assertIn("good file ran", result.stdout)
        self.assertIn("2 files, 1 failed", result.stdout)
        self.assertIn("test_a_bad.lua", result.stdout)
        self.assertIn("boom", result.stderr)

    def test_returned_function_that_errors_counts_as_fail(self):
        bad = self.fixture("test_a.lua", "return function() error('late boom') end\n")

        result = self.run_runner(bad)

        self.assertEqual(result.returncode, 1)
        self.assertIn("late boom", result.stderr)

    def test_syntax_error_counts_as_fail(self):
        broken = self.fixture("test_a.lua", "local x = = 1\n")

        result = self.run_runner(broken)

        self.assertEqual(result.returncode, 1)
        self.assertIn("1 files, 1 failed", result.stdout)

    def test_lua_print_output_comes_before_the_summary(self):
        a = self.fixture("test_a.lua", "print('from lua')\n")

        result = self.run_runner(a)

        self.assertLess(result.stdout.index("from lua"), result.stdout.index("1 files, 0 failed"))

    def test_global_set_in_one_file_is_nil_in_the_next(self):
        a = self.fixture("test_a.lua", "LEAKED_GLOBAL = 1\n")
        b = self.fixture("test_b.lua", "assert(LEAKED_GLOBAL == nil, 'global leaked')\n")

        result = self.run_runner(a, b)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_package_loaded_entry_from_one_file_is_gone_in_the_next(self):
        a = self.fixture("test_a.lua", "package.loaded.leaked_module = {}\n")
        b = self.fixture("test_b.lua", "assert(package.loaded.leaked_module == nil, 'module leaked')\n")

        result = self.run_runner(a, b)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
