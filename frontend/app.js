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
        card.innerHTML = `<h3>${n.title}</h3><div class="source">${n.source_name}</div><div class="desc">${n.rss_description ? n.rss_description.substring(0, 100) : 'Нет описания'}...</div>`;
        grid.appendChild(card);
    });
}

document.querySelectorAll('.mood-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.mood-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentMood = btn.dataset.mood;
        if (currentNewsId && !document.getElementById('modal').classList.contains('hidden')) { loadRewrittenNews(currentNewsId); }
    });
});

async function openModal(id) {
    currentNewsId = id;
    document.getElementById('modal').classList.remove('hidden');
    const res = await fetch(`/api/news/${id}`);
    const n = await res.json();
    document.getElementById('modal-title').innerText = n.title;
    document.getElementById('modal-source').innerText = n.source_name;
    document.getElementById('modal-source-link').href = n.source_url;
    document.getElementById('modal-original').innerText = n.original_text || n.rss_description;
    document.getElementById('modal-mood').innerText = currentMood;
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
