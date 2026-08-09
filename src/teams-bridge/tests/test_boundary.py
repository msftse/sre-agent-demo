import pytest

from bridge.boundary import BoundaryViolation, TeamsBoundary


def activity() -> dict[str, object]:
    return {
        "id": "activity-1",
        "serviceUrl": "https://smba.trafficmanager.net/teams/",
        "text": "<at>Azure SRE Agent</at> investigate checkout",
        "from": {"aadObjectId": "user-1", "name": "Operator"},
        "conversation": {"id": "conversation-1"},
        "channelData": {
            "tenant": {"id": "tenant-1"},
            "team": {"id": "team-1"},
            "channel": {"id": "channel-1"},
        },
    }


def boundary() -> TeamsBoundary:
    return TeamsBoundary(
        tenant_id="tenant-1",
        team_id="team-1",
        channel_id="channel-1",
        allowed_user_object_id="user-1",
    )


def test_allows_exact_context_and_removes_mention() -> None:
    request = boundary().require_allowed(activity())

    assert request.text == "investigate checkout"
    assert request.user_object_id == "user-1"
    assert request.conversation_id == "conversation-1"


def test_uses_team_aad_group_id_in_realistic_channel_data() -> None:
    payload = activity()
    channel_data = payload["channelData"]
    assert isinstance(channel_data, dict)
    channel_data["team"] = {
        "id": "19:bot-framework-team-thread@thread.skype",
        "aadGroupId": "team-1",
        "name": "Demo Team",
    }

    request = boundary().require_allowed(payload)

    assert request.team_id == "team-1"


@pytest.mark.parametrize(
    ("section", "identifier"),
    [("tenant", "other"), ("team", "other"), ("channel", "other")],
)
def test_rejects_wrong_destination(section: str, identifier: str) -> None:
    payload = activity()
    channel_data = payload["channelData"]
    assert isinstance(channel_data, dict)
    channel_data[section] = {"id": identifier}

    with pytest.raises(BoundaryViolation):
        boundary().require_allowed(payload)


def test_rejects_unauthorized_user() -> None:
    payload = activity()
    payload["from"] = {"aadObjectId": "other", "name": "Other user"}

    with pytest.raises(BoundaryViolation, match="user"):
        boundary().require_allowed(payload)