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
