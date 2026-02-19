"""Tests for lib/llm_client.py -> _make_strict()."""

from lib.llm_client import _make_strict


class TestMakeStrict:
    def test_flat_object(self):
        schema = {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "age": {"type": "integer"},
            },
        }
        result = _make_strict(schema)
        assert result["additionalProperties"] is False
        assert set(result["required"]) == {"name", "age"}

    def test_nested_object(self):
        schema = {
            "type": "object",
            "properties": {
                "address": {
                    "type": "object",
                    "properties": {
                        "street": {"type": "string"},
                    },
                },
            },
        }
        result = _make_strict(schema)
        inner = result["properties"]["address"]
        assert inner["additionalProperties"] is False
        assert inner["required"] == ["street"]

    def test_array_of_objects(self):
        schema = {
            "type": "object",
            "properties": {
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "id": {"type": "integer"},
                        },
                    },
                },
            },
        }
        result = _make_strict(schema)
        item_schema = result["properties"]["items"]["items"]
        assert item_schema["additionalProperties"] is False
        assert item_schema["required"] == ["id"]

    def test_ref_strips_siblings(self):
        schema = {
            "type": "object",
            "properties": {
                "child": {
                    "$ref": "#/$defs/Child",
                    "description": "should be stripped",
                },
            },
        }
        result = _make_strict(schema)
        child = result["properties"]["child"]
        assert child == {"$ref": "#/$defs/Child"}
        assert "description" not in child

    def test_any_of(self):
        schema = {
            "type": "object",
            "properties": {
                "value": {
                    "anyOf": [
                        {"type": "object", "properties": {"x": {"type": "integer"}}},
                        {"type": "string"},
                    ],
                },
            },
        }
        result = _make_strict(schema)
        variants = result["properties"]["value"]["anyOf"]
        obj_variant = variants[0]
        assert obj_variant["additionalProperties"] is False
        assert obj_variant["required"] == ["x"]

    def test_defs(self):
        schema = {
            "type": "object",
            "properties": {},
            "$defs": {
                "Item": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                    },
                },
            },
        }
        result = _make_strict(schema)
        item_def = result["$defs"]["Item"]
        assert item_def["additionalProperties"] is False
        assert item_def["required"] == ["name"]

    def test_original_not_mutated(self):
        schema = {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
            },
        }
        _make_strict(schema)
        assert "additionalProperties" not in schema
        assert "required" not in schema
