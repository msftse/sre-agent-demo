def chunk_text(text: str, *, max_bytes: int = 12 * 1024) -> tuple[str, ...]:
    if max_bytes < 128:
        raise ValueError("max_bytes must be at least 128.")
    if len(text.encode()) <= max_bytes:
        return (text,)

    content_limit = max_bytes - 32
    remaining = text
    chunks: list[str] = []
    while remaining:
        split_at = _largest_prefix(remaining, content_limit)
        if split_at == len(remaining):
            chunks.append(remaining)
            break
        candidate = remaining[:split_at]
        lower_bound = max(1, split_at // 2)
        boundary = max(
            candidate.rfind("\n\n", lower_bound),
            candidate.rfind("\n", lower_bound),
            candidate.rfind(" ", lower_bound),
        )
        if boundary >= lower_bound:
            split_at = boundary + (2 if candidate[boundary : boundary + 2] == "\n\n" else 1)
        chunks.append(remaining[:split_at])
        remaining = remaining[split_at:]

    count = len(chunks)
    rendered = tuple(
        f"(Part {index}/{count})\n{chunk}"
        for index, chunk in enumerate(chunks, start=1)
    )
    if any(len(chunk.encode()) > max_bytes for chunk in rendered):
        raise RuntimeError("Chunk rendering exceeded the configured byte limit.")
    return rendered


def _largest_prefix(text: str, max_bytes: int) -> int:
    low = 0
    high = len(text)
    while low < high:
        middle = (low + high + 1) // 2
        if len(text[:middle].encode()) <= max_bytes:
            low = middle
        else:
            high = middle - 1
    return low