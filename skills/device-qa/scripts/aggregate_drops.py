import sys, json, statistics as st

sink = sys.argv[1]
runs = []
with open(sink) as f:
    for line in f:
        line = line.strip()
        if line.startswith("__PERF_RESULT__"):
            try:
                d = json.loads(line[len("__PERF_RESULT__"):].strip())
                if d: runs.append(d)
            except Exception:
                pass

by = {}; order = []
for run in runs:
    for s in run:
        lab = s["label"]
        if lab not in by:
            by[lab] = []; order.append(lab)
        by[lab].append(s)

def bucket(w):
    if w <= 12: return "경미 8-12"
    if w <= 16.67: return "중간 12-16"
    if w <= 33: return "심함 16-33"
    return "치명 >33"

print(f"RUNS={len(runs)} (삼성 인터넷 120Hz). 드랍=프레임 work>8.33ms(120fps 예산).")
print("위치: 초반<0.33 / 중반 / 후반>0.66 (스크롤 진행도)\n")

for lab in order:
    rows = by[lab]
    nrun = len(rows)
    totals = [r["drops_total"] for r in rows]
    frames = [r["frames"] for r in rows]
    tot = sum(totals); fr = sum(frames)
    rate = 100.0*tot/fr if fr else 0
    # 모든 드랍 모으기(상위50 캡이지만 대부분 그 이하)
    alld = []
    for r in rows: alld.extend(r.get("drops", []))
    print(f"■ {lab}")
    print(f"   드랍 {tot}개 / {fr}프레임 = {rate:.2f}%  (런당 평균 {tot/nrun:.1f}개, 최다런 {max(totals)})")
    if not alld:
        print("   드랍 없음 ✅\n"); continue
    # 원인
    cb = sum(1 for d in alld if d["cause"]=="build"); cr = len(alld)-cb
    print(f"   원인: build {cb} ({100*cb/len(alld):.0f}%) / raster {cr} ({100*cr/len(alld):.0f}%)")
    # 심각도 버킷
    bk = {}
    for d in alld: bk[bucket(d["work"])] = bk.get(bucket(d["work"]),0)+1
    print("   심각도: " + ", ".join(f"{k}:{v}" for k,v in sorted(bk.items())))
    # 위치
    e=sum(1 for d in alld if d["frac"]<0.33); m=sum(1 for d in alld if 0.33<=d["frac"]<=0.66); l=sum(1 for d in alld if d["frac"]>0.66)
    print(f"   위치: 초반 {e} / 중반 {m} / 후반 {l}")
    # 최악 5개
    worst = sorted(alld, key=lambda d:-d["work"])[:5]
    print("   최악 5: " + " | ".join(f"{d['work']}ms(b{d['build']}/r{d['raster']},{d['cause']},pos{d['frac']})" for d in worst))
    print()
