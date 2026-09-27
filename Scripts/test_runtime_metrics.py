import unittest

from Scripts.runtime_metrics import parse_process_metrics


class RuntimeMetricsParsingTests(unittest.TestCase):
    def test_parses_cpu_percent_and_darwin_rss_kib(self):
        cpu_percent, rss_mib = parse_process_metrics("  1.25   4096\n")
        self.assertEqual(cpu_percent, 1.25)
        self.assertEqual(rss_mib, 4.0)

    def test_rejects_malformed_nonfinite_and_negative_values(self):
        for output in ("", "1", "1 2 3", "nan 42", "inf 42", "-1 42", "1 -42", "bad 42"):
            with self.subTest(output=output), self.assertRaises(ValueError):
                parse_process_metrics(output)

    def test_rejects_nonfinite_converted_memory(self):
        with self.assertRaises(ValueError):
            parse_process_metrics("1 " + "9" * 400)


if __name__ == "__main__":
    unittest.main()
