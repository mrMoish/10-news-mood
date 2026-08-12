import pytest
from app.services.news_rewriter import rewrite_and_check

class MockNews:
    def __init__(self): self.original_text = "Company X opened a factory."; self.rss_description = ""; self.facts_json = None

class MockClient:
    async def chat(self, messages, temperature):
        if "Извлеки" in messages[0]["content"]: return '{"people": [], "organizations": [], "dates": [], "numbers": [], "places": [], "quotes": [], "events": [], "claims": []}'
        elif "строгий фактчекер" in messages[0]["content"]: return '{"passed": true, "changed_facts": [], "missing_facts": [], "invented_facts": [], "explanation": "OK"}'
        elif "переписываешь реальную новость" in messages[0]["content"]: return "Company X opened a factory."
        return ""

@pytest.mark.asyncio
async def test_rewrite_and_check_pass():
    news = MockNews(); client = MockClient()
    result = await rewrite_and_check(news, "happy", client)
    assert result["status"] == "passed"; assert result["attempts"] == 1
