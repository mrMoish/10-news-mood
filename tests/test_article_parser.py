import pytest
from app.services.article_parser import extract_article_text

@pytest.mark.asyncio
async def test_article_parser():
    html = '<html><body><script>var x=1;</script><nav>Home</nav><article><p>Para 1.</p><p>Para 2.</p></article></body></html>'
    class MockResponse:
        text = html
        def raise_for_status(self): pass
    class MockClient:
        def __init__(self, *args, **kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def get(self, url): return MockResponse()
    import app.services.article_parser as ap
    original_client = ap.httpx.AsyncClient
    ap.httpx.AsyncClient = MockClient
    result = await extract_article_text("http://example.com")
    assert result["source_type"] == "article"; assert "Para 1" in result["text"]; assert "script" not in result["text"]
    ap.httpx.AsyncClient = original_client
