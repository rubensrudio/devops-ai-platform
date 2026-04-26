"""worker-service — heartbeat loop.

Reads HEARTBEAT_INTERVAL from the environment (default: 10 seconds).
Every interval, writes one heartbeat line to stdout:

    [AAAA-MM-DDTHH:MM:SSZ] [worker-service] heartbeat — status: ok

If the configuration is invalid (non-numeric or <= 0), writes to stderr
and exits with a non-zero exit code.

The loop is designed to be resilient: any exception raised inside the loop
body is caught, logged to stderr, and execution continues (degraded mode)
so the container is never blocked by a transient failure of an external
resource.
"""

import os
import sys
import time
from datetime import datetime, timezone


_SERVICE_NAME = "worker-service"
_DEFAULT_INTERVAL = 10


def _load_interval() -> int:
    """Read and validate HEARTBEAT_INTERVAL from the environment.

    Returns:
        The validated interval in seconds (integer >= 1).

    Raises:
        SystemExit: with exit code 1 when the value is invalid.
    """
    raw = os.environ.get("HEARTBEAT_INTERVAL", str(_DEFAULT_INTERVAL))
    try:
        value = int(raw)
    except ValueError:
        _fail(
            f"HEARTBEAT_INTERVAL='{raw}' is not a valid integer. "
            "Provide a positive integer (e.g. HEARTBEAT_INTERVAL=10)."
        )

    if value <= 0:
        _fail(
            f"HEARTBEAT_INTERVAL='{raw}' must be greater than 0. "
            "Provide a positive integer (e.g. HEARTBEAT_INTERVAL=10)."
        )

    return value


def _fail(message: str) -> None:
    """Write an error message to stderr and exit with code 1."""
    print(f"[{_SERVICE_NAME}] ERROR: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def _heartbeat_line() -> str:
    """Return a single heartbeat line with the current UTC timestamp."""
    ts = datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return f"[{ts}] [{_SERVICE_NAME}] heartbeat — status: ok"


def run(interval: int) -> None:  # pragma: no cover — infinite loop, tested via unit
    """Enter the heartbeat loop.

    The loop never exits on its own. Any exception raised during a single
    iteration is caught and logged; the next iteration proceeds normally
    (degraded mode).

    Args:
        interval: Seconds to wait between heartbeat emissions.
    """
    while True:
        try:
            print(_heartbeat_line(), flush=True)
        except Exception as exc:  # noqa: BLE001
            # Degraded mode: log the error but keep looping.
            print(
                f"[{_SERVICE_NAME}] WARNING: heartbeat iteration failed: {exc}",
                file=sys.stderr,
                flush=True,
            )
        time.sleep(interval)


def main() -> None:
    """Entry point: validate configuration then start the heartbeat loop."""
    interval = _load_interval()
    run(interval)


if __name__ == "__main__":
    main()
