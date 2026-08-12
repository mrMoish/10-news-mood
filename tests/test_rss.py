import pytest
from app.services.rss import fetch_rss_news

def test_rss_parse():
    class MockEntry:
        def __init__(self, title, link, published, summary, source):
            self.title = title; self.link = link; self.published = published; self.summary = summary; self.source = {"title": source}
    class MockFeed:
        entries = [MockEntry("T1", "L1", "P1", "S1", "Src1"), MockEntry("T2", "L2", "P2", "S2", "Src2")]
    import app.services.rss as rss_module
    original_parse = rss_module.feedparser.parse
    rss_module.feedparser.parse = lambda x: MockFeed()
    items = fetch_rss_news()
    assert len(items) == 2; assert items[0]["title"] == "T1"; assert items[0]["source_name"] == "Src1"
    rss_module.feedparser.parse = original_parse
