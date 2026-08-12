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
