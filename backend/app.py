"""Minimal iClearer API. Download counts and feedback primarily use Supabase from the website."""

from __future__ import annotations

import os

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS

load_dotenv()

app = Flask(__name__)
CORS(app)


def _supabase():
    url = os.getenv("SUPABASE_URL", "").rstrip("/")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    if not url or not key:
        return None
    try:
        from supabase import create_client

        return create_client(url, key)
    except Exception:
        return None


TABLE = "iclearer_downloads"


@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "iclearer"}), 200


@app.get("/api/downloads/stats")
def download_stats():
    db = _supabase()
    if not db:
        return jsonify({"status": "error", "message": "Supabase not configured", "total": 0}), 200
    try:
        result = (
            db.table(TABLE)
            .select("id", count="exact")
            .is_("feedback", "null")
            .limit(1)
            .execute()
        )
        total = getattr(result, "count", None)
        if total is None:
            total = len(getattr(result, "data", None) or [])
        return jsonify({"status": "success", "total": int(total or 0)}), 200
    except Exception as exc:
        return jsonify({"status": "error", "message": str(exc), "total": 0}), 200


@app.post("/api/downloads")
def record_download():
    db = _supabase()
    if not db:
        return jsonify({"status": "error", "message": "Supabase not configured", "total": 0}), 500
    body = request.get_json(silent=True) or {}
    row = {
        "name": (body.get("name") or "").strip() or None,
        "email": (body.get("email") or "").strip() or None,
        "feedback": (body.get("feedback") or "").strip() or None,
    }
    row = {k: v for k, v in row.items() if v}
    try:
        db.table(TABLE).insert(row or {}).execute()
        stats = download_stats()
        payload = stats[0].get_json()
        return jsonify({"status": "success", "total": payload.get("total", 0)}), 201
    except Exception as exc:
        return jsonify({"status": "error", "message": str(exc), "total": 0}), 500


@app.get("/api/feedback")
def list_feedback():
    db = _supabase()
    if not db:
        return jsonify({"status": "error", "items": []}), 200
    try:
        result = (
            db.table(TABLE)
            .select("name,feedback,created_at")
            .not_.is_("feedback", "null")
            .order("created_at", desc=True)
            .limit(48)
            .execute()
        )
        items = [
            {
                "name": (row.get("name") or "Anonymous"),
                "text": row.get("feedback"),
                "createdAt": row.get("created_at"),
            }
            for row in (result.data or [])
            if row.get("feedback")
        ]
        return jsonify({"status": "success", "items": items}), 200
    except Exception as exc:
        return jsonify({"status": "error", "message": str(exc), "items": []}), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=os.getenv("FLASK_DEBUG") == "1")
