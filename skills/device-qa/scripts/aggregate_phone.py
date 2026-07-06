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

by_label = {}; order = []
for run in runs:
    for s in run:
        lab = s["label"]
        if lab not in by_label:
            by_label[lab] = []; order.append(lab)
        by_label[lab].append(s)

def med(xs): return round(st.median(xs), 2) if xs else 0
def mx(xs):  return round(max(xs), 2) if xs else 0

print(f"RUNS_PARSED={len(runs)}  실폰 Galaxy A52s(SM-A528N) 120Hz패널, 실뷰포트")
print("예산: 120Hz=8.33ms  60Hz=16.67ms.  work=build+raster/프레임(주사율무관).\n")
hdr = ("스크롤","n","fps","work_p50","work_p95","work_p99","work_max",
       "적합%@120","적합%@60","tot_p50")
print("\t".join(hdr))
for lab in order:
    rows = by_label[lab]
    n = len(rows)
    fps = med([r["fps"] for r in rows])
    w50 = med([r["work_ms"]["p50"] for r in rows])
    w95 = med([r["work_ms"]["p95"] for r in rows])
    w99 = med([r["work_ms"]["p99"] for r in rows])
    wmax = mx([r["work_ms"]["max"] for r in rows])
    fit120 = med([r["fit120_pct"] for r in rows])
    # 60Hz 적합% = work<=16.67 비율 추정 (work_over_16ms 사용)
    fit60 = med([round(100.0*(r["frames"]-r["work_over_16ms"])/r["frames"],1) for r in rows])
    tot50 = med([r["total_ms"]["p50"] for r in rows])
    print(f"{lab[:18]}\t{n}\t{fps}\t{w50}\t{w95}\t{w99}\t{wmax}\t{fit120}%\t{fit60}%\t{tot50}")
print("\n* tot_p50≈8.3=120Hz로 프레임전달, ≈16.7=60Hz로 떨어짐(작업과중→vsync 절반)")
