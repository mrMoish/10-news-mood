import pytest
from app.services.fact_checker import check_facts

class MockClient:
    def __init__(self, response): self.response = response
    async def chat(self, messages, temperature): return self.response

@pytest.mark.asyncio
async def test_fact_checker_valid():
    client = MockClient('{"passed": true, "changed_facts": [], "missing_facts": [], "invented_facts": [], "explanation": "OK"}')
    result = await check_facts("orig", {}, "rewritten", client)
    assert result["passed"] is True

@pytest.mark.asyncio
async def test_fact_checker_invalid_json():
    client = MockClient("Invalid JSON")
    result = await check_facts("orig", {}, "rewritten", client)
    assert result["passed"] is False
