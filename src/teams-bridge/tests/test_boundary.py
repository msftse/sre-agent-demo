import pytest

from bridge.boundary import BoundaryViolation, TeamsBoundary


def activity() -> dict[str, object]:
    return {
        "id": "activity-1",
        "serviceUrl": "https://smba.trafficmanager.net/teams/",
        "text": "<at>Azure SRE Agent</at> investigate checkout",
        "from": {"aadObjectId": "user-1", "name": "Operator"},
        "conversation": {"id": "conversation-1", "conversationType": "channel"},
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
    assert request.scope == "channel"
    assert request.root_activity_id == "activity-1"


def test_uses_reply_to_id_as_channel_root() -> None:
    payload = activity()
    payload["replyToId"] = "root-1"

    request = boundary().require_allowed(payload)

    assert request.reply_to_id == "root-1"
    assert request.root_activity_id == "root-1"


def test_treats_self_referential_reply_id_as_channel_root() -> None:
    payload = activity()
    payload["replyToId"] = "activity-1"

    request = boundary().require_allowed(payload)

    assert request.reply_to_id == ""
    assert request.root_activity_id == "activity-1"


def test_treats_null_reply_id_as_channel_root() -> None:
    payload = activity()
    payload["replyToId"] = None

    request = boundary().require_allowed(payload)

    assert request.reply_to_id == ""
    assert request.root_activity_id == "activity-1"


def test_does_not_treat_channel_conversation_message_id_as_reply() -> None:
    payload = activity()
    payload["conversation"] = {
        "id": "conversation-1;messageid=teams-root-1",
        "conversationType": "channel",
    }

    request = boundary().require_allowed(payload)

    assert request.reply_to_id == ""
    assert request.root_activity_id == "activity-1"


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


def personal_activity(user_id: str = "user-1") -> dict[str, object]:
    return {
        "id": "personal-activity-1",
        "serviceUrl": "https://smba.trafficmanager.net/teams/",
        "text": "what is the AKS status?",
        "from": {"aadObjectId": user_id, "name": "Operator"},
        "conversation": {"id": "personal-conversation-1", "conversationType": "personal"},
        "channelData": {"tenant": {"id": "tenant-1"}},
    }


def personal_boundary(access_mode: str = "tenant") -> TeamsBoundary:
    return TeamsBoundary(
        tenant_id="tenant-1",
        team_id="team-1",
        channel_id="channel-1",
        allowed_user_object_id="user-1",
        personal_chat_enabled=True,
        personal_chat_access_mode=access_mode,  # type: ignore[arg-type]
    )


def test_allows_tenant_user_in_personal_chat_without_channel_context() -> None:
    request = personal_boundary().require_allowed(personal_activity("user-2"))

    assert request.scope == "personal"
    assert request.team_id == ""
    assert request.channel_id == ""
    assert request.root_activity_id == "personal-conversation-1"


def test_personal_allowed_user_mode_rejects_other_user() -> None:
    with pytest.raises(BoundaryViolation, match="user"):
        personal_boundary("allowed_user").require_allowed(personal_activity("user-2"))


def test_rejects_personal_chat_when_disabled() -> None:
    with pytest.raises(BoundaryViolation, match="personal-chat"):
        boundary().require_allowed(personal_activity())


def test_rejects_group_chat() -> None:
    payload = personal_activity()
    conversation = payload["conversation"]
    assert isinstance(conversation, dict)
    conversation["conversationType"] = "groupChat"

    with pytest.raises(BoundaryViolation, match="conversation-type"):
        personal_boundary().require_allowed(payload)


def test_rejects_cross_tenant_personal_chat() -> None:
    payload = personal_activity()
    payload["channelData"] = {"tenant": {"id": "other-tenant"}}

    with pytest.raises(BoundaryViolation, match="tenant"):
        personal_boundary().require_allowed(payload)