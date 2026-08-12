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
