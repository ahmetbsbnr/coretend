#!/usr/bin/env python3
import unittest

from Scripts.site_accessibility_contract import reduced_motion_contract_errors


class ReducedMotionContractTests(unittest.TestCase):
    def test_accepts_complete_reduced_motion_rule(self):
        css = """
        @media (prefers-reduced-motion: reduce) {
          *, *::before, *::after {
            scroll-behavior: auto !important;
            animation-duration: .01ms !important;
            transition-duration: .01ms !important;
          }
        }
        """
        self.assertEqual(reduced_motion_contract_errors(css), [])

    def test_rejects_missing_media_query(self):
        errors = reduced_motion_contract_errors("body { color: black }")
        self.assertIn("missing prefers-reduced-motion: reduce media query", errors)

    def test_rejects_each_missing_motion_reduction(self):
        css = """
        @media (prefers-reduced-motion: reduce) {
          * { scroll-behavior: smooth; animation-duration: 2s; transition-duration: 1s; }
        }
        """
        errors = reduced_motion_contract_errors(css)
        self.assertEqual(len(errors), 3)
        self.assertTrue(any("smooth scrolling" in error for error in errors))
        self.assertTrue(any("animation-duration" in error for error in errors))
        self.assertTrue(any("transition-duration" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
