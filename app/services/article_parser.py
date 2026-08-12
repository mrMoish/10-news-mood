import httpx
from bs4 import BeautifulSoup

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
}

async def extract_article_text(url: str) -> dict:
    try:
        async with httpx.AsyncClient(headers=HEADERS, follow_redirects=True, timeout=10.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            html = response.text

            soup = BeautifulSoup(html, 'html.parser')

            for tag in soup(["script", "style", "nav", "footer", "header", "aside", "form", "iframe", "noscript"]):
                tag.decompose()

            article = soup.find("article")
            if not article:
                article = soup.find("main") or soup

            paragraphs = article.find_all("p")
            text = "\n".join([p.get_text(strip=True) for p in paragraphs if p.get_text(strip=True)])

            if len(text) > 200:
                return {"text": text, "source_type": "article"}
            return {"text": "", "source_type": "rss_fallback"}
    except Exception:
        return {"text": "", "source_type": "rss_fallback"}
