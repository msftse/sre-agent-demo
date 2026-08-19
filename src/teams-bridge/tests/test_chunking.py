import re

import pytest

from bridge.chunking import chunk_text


def reconstructed(chunks: tuple[str, ...]) -> str:
    return "".join(re.sub(r"^\(Part \d+/\d+\)\n", "", chunk) for chunk in chunks)


def test_leaves_short_text_unchanged() -> None:
    assert chunk_text("short answer", max_bytes=128) == ("short answer",)


@pytest.mark.parametrize(
    "text",
    [
        "paragraph one\n\nparagraph two\n\nparagraph three " * 10,
        "- first item\n- second item\n- third item\n" * 20,
        "```python\nprint('hello')\n```\n" * 20,
        "AKS is healthy ✅ 日本語 العربية " * 30,
        "x" * 1000,
    ],
)
def test_chunks_losslessly_within_utf8_limit(text: str) -> None:
    chunks = chunk_text(text, max_bytes=256)

    assert len(chunks) > 1
    assert reconstructed(chunks) == text
    assert all(len(chunk.encode()) <= 256 for chunk in chunks)
    assert chunks[0].startswith(f"(Part 1/{len(chunks)})\n")
    assert chunks[-1].startswith(f"(Part {len(chunks)}/{len(chunks)})\n")


def test_rejects_unsafe_limit() -> None:
    with pytest.raises(ValueError, match="at least 128"):
        chunk_text("answer", max_bytes=64)