import json
from app.services.openrouter import OpenRouterClient
from app.services.fact_extractor import extract_facts
from app.services.fact_checker import check_facts

REWRITE_PROMPT = """
Ты переписываешь реальную новость. Твоя задача — изменить только эмоциональную подачу на: {mood}.
Категорически нельзя:
- добавлять новые факты;
- удалять существенные факты;
- менять числа, даты, имена, места, организации;
- менять цитаты и их смысл;
- выдавать предположения за факты.

Факты из списка являются обязательными.
Верни только готовый текст новости без комментариев.

Оригинал:
{original}

Факты:
{facts}
"""

async def rewrite_and_check(news, mood: str, client: OpenRouterClient) -> dict:
    original_text = news.original_text or news.rss_description

    if not news.facts_json:
        facts = await extract_facts(original_text, client)
        news.facts_json = json.dumps(facts, ensure_ascii=False)
    else:
        facts = json.loads(news.facts_json)

    attempts = 0
    max_attempts = 3
    last_result = None
    last_text = ""

    while attempts < max_attempts:
        attempts += 1
        try:
            prompt = REWRITE_PROMPT.format(
                mood=mood,
                original=original_text[:3000],
                facts=json.dumps(facts, ensure_ascii=False)
            )
            rewritten_text = await client.chat([{"role": "user", "content": prompt}], temperature=0.7)
            last_text = rewritten_text

            check_result = await check_facts(original_text, facts, rewritten_text, client)
            last_result = check_result

            if check_result.get("passed"):
                return {
                    "text": rewritten_text,
                    "status": "passed",
                    "result": json.dumps(check_result, ensure_ascii=False),
                    "facts_json": news.facts_json,
                    "attempts": attempts
                }
        except Exception:
            pass

    return {
        "text": last_text,
        "status": "failed",
        "result": json.dumps(last_result or {}, ensure_ascii=False),
        "facts_json": news.facts_json,
        "attempts": attempts
    }
