"""Tests for api/users.py -> _get_user_id()."""

import pytest
from fastapi import HTTPException

from api.users import _get_user_id


class TestGetUserId:
    def test_valid_bearer(self):
        assert _get_user_id("Bearer apple.user.123") == "apple.user.123"

    def test_empty_after_bearer(self):
        with pytest.raises(HTTPException) as exc_info:
            _get_user_id("Bearer ")
        assert exc_info.value.status_code == 401
        assert "Missing user identifier" in exc_info.value.detail

    def test_invalid_prefix(self):
        with pytest.raises(HTTPException) as exc_info:
            _get_user_id("Token abc")
        assert exc_info.value.status_code == 401
        assert "Invalid authorization header" in exc_info.value.detail

    def test_empty_string(self):
        with pytest.raises(HTTPException) as exc_info:
            _get_user_id("")
        assert exc_info.value.status_code == 401

    def test_strip_whitespace(self):
        assert _get_user_id("Bearer   abc  ") == "abc"
