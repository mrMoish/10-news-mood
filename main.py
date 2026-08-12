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
