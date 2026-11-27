name: 每日自动更新 AI 日报

on:
  push:
    paths:
      - '.github/workflows/daily_update.yml'
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  update-daily-ai:
    runs-on: ubuntu-latest
    steps:
      - name: 拉取仓库文件
        uses: actions/checkout@v4

      - name: 自动解压部署包（首次运行）
        run: |
          if [ -f ai_daily_pwa_flat.zip ]; then
            unzip -o ai_daily_pwa_flat.zip
            rm -f ai_daily_pwa_flat.zip
          fi

      - name: 抓取最新 AI 动态并更新 daily_data.json
        run: |
          python3 - << 'EOF'
          import datetime, html, json, os, re, urllib.request
          import xml.etree.ElementTree as ET

          FEEDS = [
              {"url": "https://blog.google/technology/ai/rss/", "tag": "Google AI 动态", "color": "indigo", "tab": "capability", "source": "Google AI Blog"},
              {"url": "https://openai.com/news/rss.xml", "tag": "OpenAI 动态", "color": "emerald", "tab": "capability", "source": "OpenAI News"},
              {"url": "https://www.technologyreview.com/topic/artificial-intelligence/feed", "tag": "前沿与政策", "color": "cyan", "tab": "frontier", "source": "MIT Technology Review"},
              {"url": "https://techcrunch.com/category/artificial-intelligence/feed/", "tag": "AI 应用与行业", "color": "amber", "tab": "apps", "source": "TechCrunch AI"},
              {"url": "https://rss.arxiv.org/rss/cs.AI", "tag": "AI 科学前沿", "color": "rose", "tab": "frontier", "source": "arXiv cs.AI"},
          ]

          def clean(raw, limit=140):
              if not raw: return ""
              t = re.sub(r"<[^>]+>", " ", html.unescape(raw))
              t = re.sub(r"\s+", " ", t).strip()
              return (t[:limit] + "...") if len(t) > limit else t

          tz_cn = datetime.timezone(datetime.timedelta(hours=8))
          now_cn = datetime.datetime.now(tz_cn)
          date_str = f"{now_cn.year}年{now_cn.month}月{now_cn.day}日"

          collected, seen = [], set()
          for f in FEEDS:
              try:
                  req = urllib.request.Request(f["url"], headers={"User-Agent": "AI-Daily-Bot/1.0"})
                  root = ET.fromstring(urllib.request.urlopen(req, timeout=15).read())
                  for node in root.findall(".//item")[:2]:
                      title = clean(node.findtext("title"), 90)
                      link = (node.findtext("link") or "").strip()
                      desc = clean(node.findtext("description"), 150)
                      if title and link and title not in seen:
                          seen.add(title)
                          collected.append({
                              "id": f"auto_{now_cn.strftime('%Y%m%d')}_{len(collected)+1}",
                              "tag": f["tag"], "color": f["color"], "tab": f["tab"],
                              "title": title, "summary": desc or "点击来源链接查看完整报道。",
                              "sourceTitle": f["source"], "sourceUrl": link
                          })
              except Exception as e:
                  print("Skip", f["source"], e)

          if collected:
              with open("daily_data.json", "w", encoding="utf-8") as fp:
                  json.dump({"updatedAt": date_str, "todayDigests": collected[:6]}, fp, ensure_ascii=False, indent=2)
          EOF

      - name: 自动保存更新
        run: |
          git config user.name "AI Daily Bot"
          git config user.email "bot@users.noreply.github.com"
          git add -A
          git diff --staged --quiet || (git commit -m "chore: 自动更新每日AI日报" && git push)
