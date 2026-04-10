# Runtime Logging Note

Use `res://core/systems/debug_log.gd` for runtime logging.

Current convention:
- `MTDebugLog.debug(enabled, ...)` for opt-in debug traces and intentional CLI/test output.
- `MTDebugLog.warning(...)` for recoverable runtime fallbacks.
- `MTDebugLog.error(...)` for hard runtime failures that should surface in diagnostics.

Avoid adding direct `print(...)`, `push_warning(...)`, or `push_error(...)` calls in gameplay/runtime code unless the utility itself is being changed.

Known exception:
- The logging utility implementation in `res://core/systems/debug_log.gd` necessarily wraps the engine logging primitives.