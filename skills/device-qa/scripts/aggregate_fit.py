import sys, json, statistics as st

sink = sys.argv[1]
runs = []
with open(sink) as f:
    for line in f:
        line = line.strip()
        if line.startswith("__PERF_RESULT__"):
            try:
                runs.append(json.loads(line[len("__PERF_RESULT__"):].strip()))
            except Exception:
                pass

by_label = {}
order = []
for run in runs:
    for s in run:
        lab = s["label"]
        if lab not in by_label:
            by_label[lab] = []; order.append(lab)
        by_label[lab].append(s)

def med(xs): return round(st.median(xs), 2) if xs else 0
def mx(xs):  return round(max(xs), 2) if xs else 0

print(f"RUNS_PARSED={len(runs)}  (예산: 120Hz=8.33ms, 60Hz=16.67ms)\n")
hdr = ("스크롤","n","work_p50","work_p95","work_p99","work_max",
       "8ms초과(중앙)","8ms초과(최대)","120fps적합%")
print("\t".join(hdr))
for lab in order:
    rows = by_label[lab]
    n = len(rows)
    w50 = med([r["work_ms"]["p50"] for r in rows])
    w95 = med([r["work_ms"]["p95"] for r in rows])
    w99 = med([r["work_ms"]["p99"] for r in rows])
    wmax = mx([r["work_ms"]["max"] for r in rows])
    o8  = med([r["work_over_8ms"] for r in rows])
    o8m = mx([r["work_over_8ms"] for r in rows])
    fit = med([r["fit120_pct"] for r in rows])
    frames = med([r["frames"] for r in rows])
    print(f"{lab}\t{n}\t{w50}\t{w95}\t{w99}\t{wmax}\t{o8}/{frames:.0f}\t{o8m}\t{fit}%")
