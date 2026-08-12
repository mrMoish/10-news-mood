import json
from app.services.openrouter import OpenRouterClient

EXTRACT_PROMPT = """
Ты — аналитик данных. Извлеки строго структурированные факты из следующего текста новости.
Верни ТОЛЬКО валидный JSON без markdown и дополнительных комментариев.
Если категория пуста, верни пустой массив.

Категории:
- people (имена людей)
- organizations (названия организаций)
- dates (даты)
- numbers (числа, суммы, проценты)
- places (географические названия)
- quotes (прямые цитаты)
- events (названия событий)
- claims (важные утверждения)

Текст:
{text}

Формат:
{{
  "people": [],
  "organizations": [],
  "dates": [],
  "numbers": [],
  "places": [],
  "quotes": [],
  "events": [],
  "claims": []
}}
"""

async def extract_facts(text: str, client: OpenRouterClient) -> dict:
    for _ in range(2):
        try:
            prompt = EXTRACT_PROMPT.format(text=text[:4000])
            response = await client.chat([{"role": "user", "content": prompt}], temperature=0.1)

            if "```json" in response:
                response = response.split("```json")[1].split("```")[0]

            return json.loads(response)
        except json.JSONDecodeError:
            continue
    return {}
