"""In-process cancellation registry for background document tasks.

Module-level dict of asyncio.Events keyed by document_id.
A watchdog awaits the event and cancels the pipeline task.
"""

import asyncio

_cancel_events: dict[str, asyncio.Event] = {}


def register(document_id: str) -> asyncio.Event:
    """Register a cancellation event for a document. Returns the event."""
    event = asyncio.Event()
    _cancel_events[document_id] = event
    return event


def cancel(document_id: str) -> bool:
    """Signal cancellation for a document. Returns True if it was registered."""
    event = _cancel_events.get(document_id)
    if event is not None:
        event.set()
        return True
    return False


def is_cancelled(document_id: str) -> bool:
    """Check whether a document has been cancelled."""
    event = _cancel_events.get(document_id)
    return event is not None and event.is_set()


def cleanup(document_id: str) -> None:
    """Remove the cancellation event for a document."""
    _cancel_events.pop(document_id, None)
