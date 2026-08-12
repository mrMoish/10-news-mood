import feedparser
from app.config import RSS_URL

def fetch_rss_news(limit=15) -> list:
    feed = feedparser.parse(RSS_URL)
    items = []
    for entry in feed.entries[:limit]:
        items.append({
            "title": entry.get("title", ""),
            "link": entry.get("link", ""),
            "published": entry.get("published", ""),
            "summary": entry.get("summary", ""),
            "source_name": entry.get("source", {}).get("title", "Unknown")
        })
    return items
