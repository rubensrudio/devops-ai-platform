"""Unit tests for apps/worker-service/src/main.py.

Test coverage:
- _heartbeat_line(): format validation (ISO8601 UTC, prefix, suffix)
- _load_interval(): valid values, invalid (non-numeric, zero, negative)
- Default interval when HEARTBEAT_INTERVAL is not set in the environment
"""

import re
import sys
import os

import pytest

# ---------------------------------------------------------------------------
# Helpers to import src/main.py which is NOT on sys.path by default
# ---------------------------------------------------------------------------

_SRC_DIR = os.path.join(os.path.dirname(__file__), "..", "src")


def _import_main():
    """Import src/main.py as a module, adding src/ to sys.path if needed."""
    if _SRC_DIR not in sys.path:
        sys.path.insert(0, _SRC_DIR)
    import main as m  # noqa: PLC0415
    return m


# Force a fresh import to pick up any monkeypatching cleanly.
main = _import_main()


# ---------------------------------------------------------------------------
# _heartbeat_line()
# ---------------------------------------------------------------------------

class TestHeartbeatLine:
    """Validate the exact format of the heartbeat log line."""

    # Pattern: [YYYY-MM-DDTHH:MM:SSZ] [worker-service] heartbeat — status: ok
    _PATTERN = re.compile(
        r"^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\] "
        r"\[worker-service\] heartbeat — status: ok$"
    )

    def test_line_matches_exact_format(self):
        line = main._heartbeat_line()
        assert self._PATTERN.match(line), (
            f"Heartbeat line does not match expected format.\n"
            f"Got:      {line!r}\n"
            f"Expected: [YYYY-MM-DDTHH:MM:SSZ] [worker-service] heartbeat — status: ok"
        )

    def test_timestamp_is_utc_iso8601(self):
        line = main._heartbeat_line()
        match = self._PATTERN.match(line)
        assert match is not None
        ts = match.group(1)
        # Must end with Z (UTC indicator, no offset)
        assert ts.endswith("Z"), f"Timestamp must end with 'Z', got: {ts!r}"

    def test_service_name_in_line(self):
        line = main._heartbeat_line()
        assert "[worker-service]" in line

    def test_status_ok_in_line(self):
        line = main._heartbeat_line()
        assert "status: ok" in line

    def test_line_contains_em_dash(self):
        """The spec requires the em dash character (—), not a hyphen (-)."""
        line = main._heartbeat_line()
        assert "heartbeat — status: ok" in line, (
            "Heartbeat line must contain em dash (—), not a hyphen (-)"
        )

    def test_two_consecutive_lines_are_valid(self):
        """Multiple calls must all produce valid lines."""
        for _ in range(3):
            line = main._heartbeat_line()
            assert self._PATTERN.match(line), f"Invalid line: {line!r}"


# ---------------------------------------------------------------------------
# _load_interval() — valid configuration
# ---------------------------------------------------------------------------

class TestLoadIntervalValid:
    """_load_interval() must return the correct integer for valid inputs."""

    def test_default_when_env_not_set(self, monkeypatch):
        monkeypatch.delenv("HEARTBEAT_INTERVAL", raising=False)
        assert main._load_interval() == 10

    def test_reads_custom_valid_value(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "30")
        assert main._load_interval() == 30

    def test_reads_minimum_valid_value(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "1")
        assert main._load_interval() == 1

    def test_reads_large_value(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "3600")
        assert main._load_interval() == 3600

    def test_returns_int_type(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "15")
        result = main._load_interval()
        assert isinstance(result, int)


# ---------------------------------------------------------------------------
# _load_interval() — invalid configuration
# ---------------------------------------------------------------------------

class TestLoadIntervalInvalid:
    """_load_interval() must exit with code 1 and write to stderr on bad input."""

    def test_non_numeric_value_exits(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "not-a-number")
        with pytest.raises(SystemExit) as exc_info:
            main._load_interval()
        assert exc_info.value.code == 1

    def test_non_numeric_value_writes_stderr(self, monkeypatch, capsys):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "abc")
        with pytest.raises(SystemExit):
            main._load_interval()
        captured = capsys.readouterr()
        assert captured.err != "", "Expected error message on stderr, got nothing"

    def test_zero_value_exits(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "0")
        with pytest.raises(SystemExit) as exc_info:
            main._load_interval()
        assert exc_info.value.code == 1

    def test_zero_value_writes_stderr(self, monkeypatch, capsys):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "0")
        with pytest.raises(SystemExit):
            main._load_interval()
        captured = capsys.readouterr()
        assert captured.err != "", "Expected error message on stderr, got nothing"

    def test_negative_value_exits(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "-5")
        with pytest.raises(SystemExit) as exc_info:
            main._load_interval()
        assert exc_info.value.code == 1

    def test_negative_value_writes_stderr(self, monkeypatch, capsys):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "-1")
        with pytest.raises(SystemExit):
            main._load_interval()
        captured = capsys.readouterr()
        assert captured.err != "", "Expected error message on stderr, got nothing"

    def test_float_string_exits(self, monkeypatch):
        """Float strings like '3.5' are not valid integers."""
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "3.5")
        with pytest.raises(SystemExit) as exc_info:
            main._load_interval()
        assert exc_info.value.code == 1

    def test_empty_string_exits(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "")
        with pytest.raises(SystemExit) as exc_info:
            main._load_interval()
        assert exc_info.value.code == 1

    def test_whitespace_string_exits(self, monkeypatch):
        monkeypatch.setenv("HEARTBEAT_INTERVAL", "   ")
        with pytest.raises(SystemExit) as exc_info:
            main._load_interval()
        assert exc_info.value.code == 1


# ---------------------------------------------------------------------------
# _fail()
# ---------------------------------------------------------------------------

class TestFail:
    """_fail() must always exit with code 1 and print to stderr."""

    def test_exits_with_code_1(self):
        with pytest.raises(SystemExit) as exc_info:
            main._fail("test error")
        assert exc_info.value.code == 1

    def test_writes_message_to_stderr(self, capsys):
        with pytest.raises(SystemExit):
            main._fail("something went wrong")
        captured = capsys.readouterr()
        assert "something went wrong" in captured.err

    def test_includes_service_name_in_stderr(self, capsys):
        with pytest.raises(SystemExit):
            main._fail("oops")
        captured = capsys.readouterr()
        assert "worker-service" in captured.err
