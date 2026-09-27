import unittest
import sys

sys.dont_write_bytecode = True
import check_architecture


def package_fixture():
    return {
        "toolsVersion": {"_version": "6.0.0"},
        "platforms": [{"platformName": "macos", "version": "14.0"}],
        "dependencies": [],
        "targets": [
            {"name": "SafetyCore", "dependencies": []},
            {"name": "ScanCore", "dependencies": [{"byName": ["ProductContract", None]}]},
            {"name": "Domain", "dependencies": [
                {"byName": ["SafetyCore", None]},
                {"byName": ["Persistence", None]},
            ]},
        ],
    }


class ArchitectureContractTests(unittest.TestCase):
    def test_accepts_declared_swift6_macos14_modular_package(self):
        self.assertEqual(check_architecture.validate(package_fixture()), [])

    def test_rejects_external_package_dependency(self):
        package = package_fixture()
        package["dependencies"].append({"sourceControl": [{"url": "https://example.invalid/pkg"}]})
        self.assertIn("external SwiftPM dependencies are not allowed", check_architecture.validate(package))

    def test_rejects_macos_below_supported_minimum(self):
        package = package_fixture()
        package["platforms"][0]["version"] = "13.0"
        self.assertIn("macOS deployment target must be at least 14.0", check_architecture.validate(package))

    def test_rejects_write_capable_dependencies_in_scancore(self):
        package = package_fixture()
        package["targets"][1]["dependencies"].append({"byName": ["SafetyCore", None]})
        self.assertIn("ScanCore may not depend on SafetyCore or Persistence", check_architecture.validate(package))


if __name__ == "__main__":
    unittest.main()
