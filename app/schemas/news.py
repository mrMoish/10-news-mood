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
