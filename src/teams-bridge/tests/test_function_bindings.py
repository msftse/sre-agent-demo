import inspect
import os
from typing import Any, get_type_hints

TEST_SETTINGS = {
    "CLIENT_ID": "00000000-0000-0000-0000-000000000001",
    "CLIENT_SECRET": "test-only",
    "TENANT_ID": "00000000-0000-0000-0000-000000000002",
    "ALLOWED_USER_OBJECT_ID": "00000000-0000-0000-0000-000000000004",
    "TEAMS_TENANT_ID": "00000000-0000-0000-0000-000000000002",
    "TEAMS_TEAM_ID": "00000000-0000-0000-0000-000000000003",
    "TEAMS_CHANNEL_ID": "19:test@thread.tacv2",
    "STORAGE_ACCOUNT_NAME": "teststorage",
    "STORAGE_TABLE_NAME": "teamsbridge",
    "SRE_AGENT_ENDPOINT": "https://agent.example",
    "MCP_SHARED_KEY": "test-key",
    "GITHUB_WEBHOOK_SECRET": "webhook-secret",
    "GITHUB_REPOSITORY": "msftse/sre-agent-demo",
}
for name, value in TEST_SETTINGS.items():
    os.environ.setdefault(name, value)

import function_app  # noqa: E402

REGISTERED_FUNCTIONS = function_app.app.get_functions()


def test_binding_names_match_function_parameters() -> None:
    for registered in REGISTERED_FUNCTIONS:
        user_function = registered._func
        parameters = inspect.signature(user_function).parameters
        input_bindings = [
            binding
            for binding in registered.get_bindings()
            if binding.name != "$return"
        ]

        for binding in input_bindings:
            assert binding.name in parameters, (
                registered.get_function_name(),
                binding.name,
                tuple(parameters),
            )


def test_activity_bindings_use_worker_supported_annotation() -> None:
    activity_names = {
        "complete_sre_turn",
        "fail_sre_turn",
        "poll_sre_turn",
        "persist_teams_activity",
        "start_sre_investigation",
        "reply_with_sre_thread",
        "timeout_sre_turn",
    }

    for registered in REGISTERED_FUNCTIONS:
        if registered.get_function_name() in activity_names:
            assert get_type_hints(registered._func)["request"] is Any