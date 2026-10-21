"""Startup hook: patches checks.py to accept BFF inline config, then initializes OTEL.

The RHOAI Dashboard BFF sends inline guardrails configuration (model, prompts,
API key) in every /v1/guardrail/checks request. The NemoGuardrails fork rejects
these with 'Inline guardrails configuration is not supported'. This patch
neutralizes the rejection: when inline config is detected, it is set to None so
the server falls through to its default config (--default-config-id).
"""
import os

_CHECKS_PATH = "/app/nemoguardrails/server/checks.py"
_OLD = (
    '            if body.guardrails.config:\n'
    '                yield _json_response(\n'
    '                    _create_check_error_response(\n'
    '                        "Inline guardrails configuration is not supported.'
    ' Use config_id to reference a server-side configuration."\n'
    '                    )\n'
    '                )\n'
    '                return'
)
_NEW = (
    '            if body.guardrails.config:\n'
    '                body.guardrails.config = None'
)

try:
    with open(_CHECKS_PATH) as _f:
        _content = _f.read()
    if _OLD in _content:
        with open(_CHECKS_PATH, "w") as _f:
            _f.write(_content.replace(_OLD, _NEW))
except Exception:
    pass

from opentelemetry.instrumentation.auto_instrumentation import initialize
initialize()
