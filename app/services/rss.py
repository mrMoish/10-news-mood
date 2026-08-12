import feedparser
from bs4 import BeautifulSoup
from app.config import RSS_URL

def clean_html(html_text: str) -> str:
    """Удаляет HTML-теги из строки и возвращает чистый текст."""
    if not html_text:
        return ""
    soup = BeautifulSoup(html_text, "html.parser")
    # get_text(separator=' ', strip=True) удаляет теги и склеивает текст красиво
    return soup.get_text(separator=" ", strip=True)

def fetch_rss_news(limit=15) -> list:
    feed = feedparser.parse(RSS_URL)
    items = []
    for entry in feed.entries[:limit]:
        raw_summary = entry.get("summary", "")
        clean_summary = clean_html(raw_summary)
        
        items.append({
            "title": entry.get("title", ""),
            "link": entry.get("link", ""),
            "published": entry.get("published", ""),
            "summary": clean_summary,  # Сохраняем очищенный текст
            "source_name": entry.get("source", {}).get("title", "Unknown")
        })
    return items
