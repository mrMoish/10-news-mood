#!/bin/bash

# Создаем структуру директорий
mkdir -p app/api app/models app/schemas app/services frontend tests

# 1. Конфигурация
cat << 'EOF' > .env.example
OPENROUTER_API_KEY=your_openrouter_api_key_here
OPENROUTER_MODEL=deepseek/deepseek-chat
EOF

cat << 'EOF' > .gitignore
.venv/
__pycache__/
*.pyc
.env
newsmood.db
EOF

cat << 'EOF' > requirements.txt
fastapi==0.111.0
uvicorn==0.30.1
sqlalchemy==2.0.30
httpx==0.27.0
feedparser==6.0.11
python-dotenv==1.0.1
pytest==8.2.0
pytest-asyncio==0.23.7
EOF

cat << 'EOF' > render.yaml
services:
  - type: web
    name: newsmood
    runtime: python
    buildCommand: pip install -r requirements.txt
    startCommand: uvicorn app.main:app --host 0.0.0.0 --port $PORT
    envVars:
      - key: PYTHON_VERSION
        value: 3.12.2
      - key: OPENROUTER_API_KEY
        sync: false
      - key: OPENROUTER_MODEL
        value: deepseek/deepseek-chat
EOF

# 2. Backend файлы
cat << 'EOF' > run.py
import uvicorn

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
EOF

cat << 'EOF' > app/__init__.py
EOF

cat << 'EOF' > app/config.py
import os
from dotenv import load_dotenv

load_dotenv()

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "deepseek/deepseek-chat")

RSS_URL = "https://news.google.com/rss?hl=ru&gl=RU&ceid=RU:ru"
DATABASE_URL = "sqlite:///./newsmood.db"
EOF

cat << 'EOF' > app/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config import DATABASE_URL

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

cat << 'EOF' > app/models/__init__.py
from app.models.news import News
from app.models.rewrite import RewrittenNews
EOF

cat << 'EOF' > app/models/news.py
from sqlalchemy import Column, Integer, String, Text, DateTime
from datetime import datetime
from app.database import Base

class News(Base):
    __tablename__ = "news"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    source_name = Column(String, index=True)
    source_url = Column(String, unique=True, index=True)
    published_at = Column(String)
    rss_description = Column(Text)
    original_text = Column(Text)
    text_source_type = Column(String) # теперь всегда 'rss'
    facts_json = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
EOF

cat << 'EOF' > app/models/rewrite.py
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, UniqueConstraint
from datetime import datetime
from app.database import Base

class RewrittenNews(Base):
    __tablename__ = "rewritten_news"

    id = Column(Integer, primary_key=True, index=True)
    news_id = Column(Integer, ForeignKey("news.id"), nullable=False)
    mood = Column(String, index=True)
    rewritten_text = Column(Text)
    facts_check_status = Column(String)
    facts_check_result = Column(Text)
    generation_attempts = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (UniqueConstraint('news_id', 'mood', name='_news_mood_uc'),)
EOF

cat << 'EOF' > app/schemas/__init__.py
EOF

cat << 'EOF' > app/schemas/news.py
from pydantic import BaseModel
from typing import List, Optional

class RewriteRequest(BaseModel):
    mood: str

class RewrittenNewsSchema(BaseModel):
    mood: str
    rewritten_text: str
    facts_check_status: str
    facts_check_result: Optional[str] = None

class NewsOut(BaseModel):
    id: int
    title: str
    source_name: str
    source_url: str
    published_at: Optional[str] = None
    rss_description: Optional[str] = None
    original_text: Optional[str] = None
    text_source_type: Optional[str] = None
    rewrites: List[RewrittenNewsSchema] = []

class NewsListOut(BaseModel):
    news: List[NewsOut]
EOF

cat << 'EOF' > app/services/__init__.py
EOF

cat << 'EOF' > app/services/rss.py
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
EOF

cat << 'EOF' > app/services/openrouter.py
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
EOF

cat << 'EOF' > app/services/fact_extractor.py
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
EOF

cat << 'EOF' > app/services/fact_checker.py
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
EOF

cat << 'EOF' > app/services/news_rewriter.py
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
EOF

cat << 'EOF' > app/api/__init__.py
EOF

cat << 'EOF' > app/api/news.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import News, RewrittenNews
from app.schemas.news import NewsListOut, NewsOut, RewriteRequest
from app.services.openrouter import OpenRouterClient
from app.services.news_rewriter import rewrite_and_check

router = APIRouter()

@router.get("/api/news", response_model=NewsListOut)
def get_news(db: Session = Depends(get_db)):
    news = db.query(News).all()
    return {"news": news}

@router.get("/api/news/{news_id}", response_model=NewsOut)
def get_news_detail(news_id: int, db: Session = Depends(get_db)):
    news = db.query(News).filter(News.id == news_id).first()
    if not news:
        raise HTTPException(status_code=404, detail="News not found")
    return news

@router.post("/api/news/{news_id}/rewrite")
async def rewrite_news(news_id: int, req: RewriteRequest, db: Session = Depends(get_db)):
    news = db.query(News).filter(News.id == news_id).first()
    if not news:
        raise HTTPException(status_code=404, detail="News not found")

    existing = db.query(RewrittenNews).filter(
        RewrittenNews.news_id == news_id,
        RewrittenNews.mood == req.mood
    ).first()

    if existing:
        return {
            "id": news.id,
            "mood": existing.mood,
            "rewritten_text": existing.rewritten_text,
            "facts_check_status": existing.facts_check_status,
            "facts_check_result": existing.facts_check_result
        }

    client = OpenRouterClient()
    try:
        result = await rewrite_and_check(news, req.mood, client)

        if result["facts_json"]:
            news.facts_json = result["facts_json"]

        new_rewrite = RewrittenNews(
            news_id=news.id,
            mood=req.mood,
            rewritten_text=result["text"],
            facts_check_status=result["status"],
            facts_check_result=result["result"],
            generation_attempts=result["attempts"]
        )
        db.add(new_rewrite)
        db.commit()
        db.refresh(new_rewrite)

        return {
            "id": news.id,
            "mood": new_rewrite.mood,
            "rewritten_text": new_rewrite.rewritten_text,
            "facts_check_status": new_rewrite.facts_check_status,
            "facts_check_result": new_rewrite.facts_check_result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail="Не удалось обработать новость. Попробуйте ещё раз.")

@router.post("/api/news/{news_id}/rewrite/regenerate")
async def regenerate_news(news_id: int, req: RewriteRequest, db: Session = Depends(get_db)):
    news = db.query(News).filter(News.id == news_id).first()
    if not news:
        raise HTTPException(status_code=404, detail="News not found")

    existing = db.query(RewrittenNews).filter(
        RewrittenNews.news_id == news_id,
        RewrittenNews.mood == req.mood
    ).first()

    if existing:
        db.delete(existing)
        db.commit()

    return await rewrite_news(news_id, req, db)
EOF

cat << 'EOF' > app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import os
from app.database import engine, Base, SessionLocal
from app.models import News
from app.services.rss import fetch_rss_news
from app.api.news import router

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    if db.query(News).count() < 10:
        print("Fetching real news from Google RSS...")
        items = fetch_rss_news(limit=15)

        saved = 0
        for item in items:
            if saved >= 15:
                break
            existing = db.query(News).filter(News.source_url == item["link"]).first()
            if existing:
                continue

            # Используем только RSS описание как оригинальный текст
            summary = item["summary"]
            news_item = News(
                title=item["title"],
                source_name=item["source_name"],
                source_url=item["link"],
                published_at=item["published"],
                rss_description=summary,
                original_text=summary,
                text_source_type="rss"
            )
            db.add(news_item)
            saved += 1

        db.commit()
        print(f"Saved {saved} real news.")
    db.close()
    yield

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

frontend_dir = os.path.join(os.path.dirname(__file__), "..", "frontend")
app.mount("/", StaticFiles(directory=frontend_dir, html=True), name="frontend")
EOF

# 3. Frontend файлы
cat << 'EOF' > frontend/index.html
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NewsMood</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <header>
        <h1>NewsMood</h1>
        <p>Реальные новости. Разные эмоции. Те же факты.</p>
    </header>

    <main id="news-grid" class="news-grid">
        <div class="loader">Загрузка реальных новостей...</div>
    </main>

    <div id="modal" class="modal hidden">
        <div class="modal-content">
            <button class="close-btn" onclick="closeModal()">×</button>
            <div class="modal-header">
                <h2 id="modal-title"></h2>
                <div class="source-info">
                    Источник: <span id="modal-source"></span>
                    <a id="modal-source-link" href="#" target="_blank">Читать оригинал →</a>
                </div>
            </div>

            <!-- Выбор настроения теперь внутри modal -->
            <nav class="mood-selector">
                <button class="mood-btn active" data-mood="happy">😊 Радостно</button>
                <button class="mood-btn" data-mood="sad">😢 Грустно</button>
                <button class="mood-btn" data-mood="ironic">😏 Иронично</button>
                <button class="mood-btn" data-mood="anxious">😰 Тревожно</button>
                <button class="mood-btn" data-mood="optimistic">🌤 Оптимистично</button>
                <button class="mood-btn" data-mood="sarcasm">😈 Сарказм</button>
            </nav>

            <div class="modal-grid">
                <div class="modal-left">
                    <h3>Оригинал</h3>
                    <div id="modal-original" class="article-text"></div>
                </div>
                <div class="modal-right">
                    <h3>Версия: <span id="modal-mood"></span></h3>
                    <div id="modal-rewritten" class="article-text"></div>
                    <div id="fact-check-status" class="fact-check"></div>
                </div>
            </div>
        </div>
    </div>

    <script src="app.js"></script>
</body>
</html>
EOF

cat << 'EOF' > frontend/styles.css
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f8f9fa; color: #333; line-height: 1.6; }
header { text-align: center; padding: 40px 20px; background: #fff; border-bottom: 1px solid #eaeaea; margin-bottom: 20px; }
header h1 { font-size: 2.5rem; color: #1a1a1a; margin-bottom: 5px; }
header p { color: #666; font-size: 1.1rem; }

.news-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; padding: 0 20px 40px; max-width: 1200px; margin: 0 auto; }
.news-card { background: #fff; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.05); cursor: pointer; transition: transform 0.2s, box-shadow 0.2s; border: 1px solid #eee; }
.news-card:hover { transform: translateY(-3px); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
.news-card h3 { font-size: 1.2rem; margin-bottom: 10px; }
.news-card .source { font-size: 0.9rem; color: #888; margin-bottom: 10px; }
.news-card .desc { font-size: 0.95rem; color: #444; }

.modal { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.6); display: flex; justify-content: center; align-items: center; z-index: 100; padding: 20px; }
.modal.hidden { display: none; }
.modal-content { background: #fff; border-radius: 16px; width: 100%; max-width: 1000px; max-height: 90vh; overflow-y: auto; padding: 30px; position: relative; }
.close-btn { position: absolute; top: 15px; right: 20px; background: none; border: none; font-size: 2rem; cursor: pointer; color: #666; }

.modal-header { margin-bottom: 20px; border-bottom: 1px solid #eee; padding-bottom: 15px; }
.modal-header h2 { margin-bottom: 10px; font-size: 1.5rem; }
.source-info { font-size: 0.9rem; color: #666; }
.source-info a { color: #007bff; text-decoration: none; margin-left: 10px; }

.mood-selector { display: flex; flex-wrap: wrap; justify-content: center; gap: 10px; margin-bottom: 30px; padding: 15px; background: #f8f9fa; border-radius: 12px; }
.mood-btn { padding: 10px 20px; border: 1px solid #ddd; border-radius: 30px; background: #fff; cursor: pointer; font-size: 1rem; transition: all 0.2s; }
.mood-btn:hover { background: #f0f0f0; }
.mood-btn.active { background: #1a1a1a; color: #fff; border-color: #1a1a1a; }

.modal-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 30px; }
.article-text { font-size: 1rem; white-space: pre-wrap; }
.fact-check { margin-top: 20px; font-weight: bold; }
.fact-check.passed { color: #28a745; }
.fact-check.failed { color: #dc3545; }
.fact-check.loading { color: #ffc107; }
.loader { grid-column: 1 / -1; text-align: center; padding: 50px; color: #666; }

@media (max-width: 900px) { .news-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 600px) { .news-grid { grid-template-columns: 1fr; } .modal-grid { grid-template-columns: 1fr; } .mood-selector { overflow-x: auto; flex-wrap: nowrap; justify-content: flex-start; } }
EOF

cat << 'EOF' > frontend/app.js
let currentMood = 'happy';
let currentNewsId = null;
let isGenerating = false;

async function loadNews() {
    const res = await fetch('/api/news');
    const data = await res.json();
    const grid = document.getElementById('news-grid');
    grid.innerHTML = '';
    if (data.news.length === 0) { grid.innerHTML = '<div class="loader">Новости не найдены. Перезагрузите страницу.</div>'; return; }
    data.news.forEach(n => {
        const card = document.createElement('div');
        card.className = 'news-card';
        card.onclick = () => openModal(n.id);
        card.innerHTML = `<h3>${n.title}</h3><div class="source">${n.source_name}</div><div class="desc">${n.rss_description ? n.rss_description.substring(0, 150) : 'Нет описания'}...</div>`;
        grid.appendChild(card);
    });
}

// Слушатель кликов по настроению внутри modal
document.querySelectorAll('.mood-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.mood-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentMood = btn.dataset.mood;
        if (currentNewsId) { loadRewrittenNews(currentNewsId); }
    });
});

async function openModal(id) {
    currentNewsId = id;
    document.getElementById('modal').classList.remove('hidden');

    // Сбрасываем на "Радостно" при каждом открытии
    document.querySelectorAll('.mood-btn').forEach(b => b.classList.remove('active'));
    const happyBtn = document.querySelector('.mood-btn[data-mood="happy"]');
    if(happyBtn) happyBtn.classList.add('active');
    currentMood = 'happy';

    const res = await fetch(`/api/news/${id}`);
    const n = await res.json();
    document.getElementById('modal-title').innerText = n.title;
    document.getElementById('modal-source').innerText = n.source_name;
    document.getElementById('modal-source-link').href = n.source_url;
    document.getElementById('modal-original').innerText = n.original_text || n.rss_description;
    document.getElementById('modal-mood').innerText = currentMood;

    // Сразу запрашиваем генерацию для дефолтного настроения
    await loadRewrittenNews(id);
}

async function loadRewrittenNews(id) {
    if (isGenerating) return;
    isGenerating = true;
    const rewrittenDiv = document.getElementById('modal-rewritten');
    const statusDiv = document.getElementById('fact-check-status');
    rewrittenDiv.innerHTML = '<div class="loader">AI переписывает новость...</div>';
    statusDiv.className = 'fact-check loading';
    statusDiv.innerText = 'Проверяем факты...';

    document.getElementById('modal-mood').innerText = currentMood;

    try {
        const res = await fetch(`/api/news/${id}/rewrite`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mood: currentMood }) });
        if (!res.ok) throw new Error('Failed');
        const data = await res.json();
        rewrittenDiv.innerText = data.rewritten_text;
        if (data.facts_check_status === 'passed') {
            statusDiv.className = 'fact-check passed';
            statusDiv.innerHTML = '✓ Факты сохранены';
        } else if (data.facts_check_status === 'failed') {
            statusDiv.className = 'fact-check failed';
            statusDiv.innerHTML = '⚠️ Факты могли быть искажены. <button onclick="regenerate()" style="margin-left:10px; padding:5px 10px; cursor:pointer; background:#dc3545; color:#fff; border:none; border-radius:5px;">Перегенерировать</button>';
        }
    } catch (e) {
        rewrittenDiv.innerText = '';
        statusDiv.className = 'fact-check failed';
        statusDiv.innerText = 'Не удалось обработать новость. Попробуйте ещё раз.';
    }
    isGenerating = false;
}

async function regenerate() {
    if (isGenerating) return;
    isGenerating = true;
    const rewrittenDiv = document.getElementById('modal-rewritten');
    const statusDiv = document.getElementById('fact-check-status');
    rewrittenDiv.innerHTML = '<div class="loader">AI переписывает новость...</div>';
    statusDiv.className = 'fact-check loading';
    statusDiv.innerText = 'Проверяем факты...';
    try {
        const res = await fetch(`/api/news/${currentNewsId}/rewrite/regenerate`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mood: currentMood }) });
        if (!res.ok) throw new Error('Failed');
        const data = await res.json();
        rewrittenDiv.innerText = data.rewritten_text;
        if (data.facts_check_status === 'passed') {
            statusDiv.className = 'fact-check passed';
            statusDiv.innerHTML = '✓ Факты сохранены';
        } else {
            statusDiv.className = 'fact-check failed';
            statusDiv.innerHTML = '⚠️ Факты могли быть искажены. <button onclick="regenerate()" style="margin-left:10px; padding:5px 10px; cursor:pointer; background:#dc3545; color:#fff; border:none; border-radius:5px;">Перегенерировать</button>';
        }
    } catch (e) {
        statusDiv.className = 'fact-check failed';
        statusDiv.innerText = 'Ошибка перегенерации.';
    }
    isGenerating = false;
}

function closeModal() {
    document.getElementById('modal').classList.add('hidden');
    currentNewsId = null;
}

loadNews();
EOF

# 4. Тесты (удален test_article_parser, так как парсера больше нет)
cat << 'EOF' > tests/__init__.py
EOF

cat << 'EOF' > tests/test_rss.py
import pytest
from app.services.rss import fetch_rss_news

def test_rss_parse():
    class MockEntry:
        def __init__(self, title, link, published, summary, source):
            self.title = title; self.link = link; self.published = published; self.summary = summary; self.source = {"title": source}
    class MockFeed:
        entries = [MockEntry("T1", "L1", "P1", "S1", "Src1"), MockEntry("T2", "L2", "P2", "S2", "Src2")]
    import app.services.rss as rss_module
    original_parse = rss_module.feedparser.parse
    rss_module.feedparser.parse = lambda x: MockFeed()
    items = fetch_rss_news()
    assert len(items) == 2; assert items[0]["title"] == "T1"; assert items[0]["source_name"] == "Src1"
    rss_module.feedparser.parse = original_parse
EOF

cat << 'EOF' > tests/test_fact_checker.py
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
EOF

cat << 'EOF' > tests/test_news_rewriter.py
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
EOF

cat << 'EOF' > tests/test_api.py
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import Base, engine, SessionLocal
from app.models import News

client = TestClient(app)

@pytest.fixture(scope="module", autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    n = News(title="Test", source_name="TestSrc", source_url="http://test.com", original_text="Text")
    db.add(n); db.commit(); db.close()
    yield
    Base.metadata.drop_all(bind=engine)

def test_get_news():
    res = client.get("/api/news")
    assert res.status_code == 200; assert "news" in res.json()

def test_get_news_detail():
    res = client.get("/api/news/1")
    assert res.status_code == 200; assert res.json()["title"] == "Test"
EOF

cat << 'EOF' > README.md
# NewsMood
NewsMood — это веб-приложение, которое позволяет читать одни и те же реальные новости в разных эмоциональных тональностях.
EOF

echo "Project structure created successfully!"