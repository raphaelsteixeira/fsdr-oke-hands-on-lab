import json
from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]


class ResourceManagerSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = yaml.safe_load((ROOT / "schema.yaml").read_text())
        cls.variables = cls.schema["variables"]

    def test_collection_element_references_exist(self):
        for name, definition in self.variables.items():
            if definition["type"] in ("list", "map"):
                with self.subTest(variable=name):
                    reference = definition["valueType"]
                    self.assertTrue(
                        reference in self.variables,
                        f"{name}.valueType references undefined entry {reference!r}",
                    )

    def test_collection_element_definitions_are_hidden(self):
        for name, definition in self.variables.items():
            if definition["type"] in ("list", "map"):
                with self.subTest(variable=name):
                    element = self.variables[definition["valueType"]]
                    self.assertIs(element.get("visible"), False)

    def test_collection_defaults_match_element_types(self):
        primitive_types = {"string": str, "number": (int, float)}
        for name, definition in self.variables.items():
            if definition["type"] not in ("list", "map"):
                continue
            with self.subTest(variable=name):
                value = json.loads(definition["default"])
                self.assertIsInstance(
                    value, list if definition["type"] == "list" else dict
                )
                element = self.variables[definition["valueType"]]
                values = value if isinstance(value, list) else value.values()
                for item in values:
                    self.assertIsInstance(item, primitive_types[element["type"]])
                    self.assertNotIsInstance(item, bool)

    def test_object_attribute_references_exist(self):
        for name, definition in self.variables.items():
            if definition["type"] == "object":
                for reference in definition["attributes"]:
                    with self.subTest(variable=name, attribute=reference):
                        self.assertTrue(
                            reference in self.variables,
                            f"{name}.attributes references undefined entry {reference!r}",
                        )

    def test_object_attributes_are_hidden_and_named(self):
        for name, definition in self.variables.items():
            if definition["type"] == "object":
                for reference in definition["attributes"]:
                    with self.subTest(variable=name, attribute=reference):
                        attribute = self.variables[reference]
                        self.assertIs(attribute.get("visible"), False)
                        self.assertTrue(attribute.get("actualName"))

    def test_shape_config_matches_terraform_attributes(self):
        attributes = self.variables["node_shape_config"]["attributes"]
        actual_types = {
            self.variables[reference]["actualName"]: self.variables[reference]["type"]
            for reference in attributes
        }
        self.assertEqual(actual_types, {"ocpus": "number", "memory_in_gbs": "number"})

    def test_empty_tags_map_is_not_rendered_by_default(self):
        control = self.variables["configure_freeform_tags"]
        self.assertEqual(control["type"], "boolean")
        self.assertIs(control["default"], False)
        self.assertEqual(
            self.variables["freeform_tags"]["visible"], "${configure_freeform_tags}"
        )
        self.assertEqual(json.loads(self.variables["freeform_tags"]["default"]), {})

    def test_groups_reference_existing_entries(self):
        for group_key, entry_key in (
            ("variableGroups", "variables"),
            ("outputGroups", "outputs"),
        ):
            for group in self.schema.get(group_key, []):
                for reference in group[entry_key]:
                    name = (
                        reference[2:-1]
                        if reference.startswith("${") and reference.endswith("}")
                        else reference
                    )
                    with self.subTest(group=group["title"], reference=reference):
                        self.assertIn(name, self.schema[entry_key])


if __name__ == "__main__":
    unittest.main()
