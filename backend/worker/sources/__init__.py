from worker.sources.base import DiscoveredEvent, SourceAdapter
from worker.sources.community_meetups import CommunityMeetupsSource
from worker.sources.luma import LumaSource
from worker.sources.meetup import MeetupSource

SOURCE_ADAPTERS: dict[str, type[SourceAdapter]] = {
    "luma": LumaSource,
    "meetup": MeetupSource,
    "community": CommunityMeetupsSource,
}


def adapter_for(source_id: str) -> SourceAdapter:
    try:
        return SOURCE_ADAPTERS[source_id]()
    except KeyError as exc:
        raise ValueError(f"Unknown source {source_id}") from exc
