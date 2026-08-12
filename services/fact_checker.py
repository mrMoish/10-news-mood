import json
from app.services.openrouter import OpenRouterClient

CHECK_PROMPT = """
Ты — строгий фактчекер. Сравни оригинальный текст, структурированные факты и переписанный текст.
Проверь, изменились ли: числа, даты, имена, организации, места, цитаты, события, причинно-следственные связи.
Если в переписанном тексте есть новые факты, которых нет в оригинале, или удалены/искажены старые — проверка не пройдена.
Верни ТОЛЬКО валидный JSON.

Оригинал: {original}
Факты: {facts}
Переписанный: {rewritten}

Формат:
{{
  "passed": true/false,
  "changed_facts": [],
  "missing_facts": [],
  "invented_facts": [],
  "explanation": ""
}}
"""

async def check_facts(original: str, facts: dict, rewritten: str, client: OpenRouterClient) -> dict:
    for _ in range(2):
        try:
            prompt = CHECK_PROMPT.format(
                original=original[:2000],
                facts=json.dumps(facts, ensure_ascii=False),
                rewritten=rewritten[:2000]
            )
            response = await client.chat([{"role": "user", "content": prompt}], temperature=0.1)

            if "```json" in response:
                response = response.split("```json")[1].split("```")[0]

            return json.loads(response)
        except json.JSONDecodeError:
            continue

    return {
        "passed": False,
        "changed_facts": [],
        "missing_facts": [],
        "invented_facts": [],
        "explanation": "Fact checker returned invalid JSON"
    }
