import httpx
from app.config import OPENROUTER_API_KEY, OPENROUTER_MODEL

class OpenRouterClient:
    def __init__(self):
        self.api_key = OPENROUTER_API_KEY
        self.model = OPENROUTER_MODEL
        self.url = "https://openrouter.ai/api/v1/chat/completions"

    async def chat(self, messages: list, temperature: float = 0.7) -> str:
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY is not set")

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "http://localhost:8000",
            "X-Title": "NewsMood"
        }
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            try:
                response = await client.post(self.url, headers=headers, json=payload)
                response.raise_for_status()
                data = response.json()
                return data['choices'][0]['message']['content']
            except httpx.HTTPStatusError as e:
                raise Exception(f"OpenRouter API Error: {e.response.status_code}")
            except Exception as e:
                raise Exception(f"OpenRouter Request Failed: {str(e)}")
