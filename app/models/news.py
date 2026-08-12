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
    text_source_type = Column(String)
    facts_json = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
