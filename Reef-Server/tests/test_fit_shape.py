import pytest
import math
from httpx import ASGITransport, AsyncClient
from app.main import app


@pytest.mark.asyncio
async def test_line_detection():
    points = [[float(i * 10), float(i * 2 + (i % 2))] for i in range(20)]
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/ai/fit-shape", json={"points": points})
    assert resp.status_code == 200
    data = resp.json()
    assert data["shape"] == "line"
    assert data["confidence"] > 0.6


@pytest.mark.asyncio
async def test_rectangle_detection():
    # Draw a rectangle path
    points = []
    for x in range(0, 100, 5):
        points.append([float(x), 0.0])
    for y in range(0, 75, 5):
        points.append([100.0, float(y)])
    for x in range(100, 0, -5):
        points.append([float(x), 75.0])
    for y in range(75, 0, -5):
        points.append([0.0, float(y)])
    points.append([0.0, 0.0])

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/ai/fit-shape", json={"points": points, "closed": True})
    data = resp.json()
    assert data["shape"] == "rectangle"


@pytest.mark.asyncio
async def test_circle_detection():
    points = []
    for i in range(40):
        angle = 2 * math.pi * i / 40
        points.append([50 + 40 * math.cos(angle), 50 + 40 * math.sin(angle)])
    points.append(points[0])

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/ai/fit-shape", json={"points": points, "closed": True})
    data = resp.json()
    assert data["shape"] == "circle"


@pytest.mark.asyncio
async def test_scribble_rejected():
    import random
    random.seed(42)
    points = [[random.uniform(0, 100), random.uniform(0, 100)] for _ in range(50)]
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/ai/fit-shape", json={"points": points})
    data = resp.json()
    assert data["shape"] == "none"


@pytest.mark.asyncio
async def test_triangle_detection():
    points = []
    for i in range(10):
        points.append([50 + float(i * 5), float(i * 8)])
    for i in range(10):
        points.append([100 - float(i * 10), 80.0])
    for i in range(10):
        points.append([0 + float(i * 5), 80 - float(i * 8)])

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/ai/fit-shape", json={"points": points, "closed": True})
    data = resp.json()
    assert data["shape"] == "triangle"
