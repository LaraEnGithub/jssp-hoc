import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

BINS = 20
RESULTS = Path("results")


def encoding(source):
    with source.open("rb") as raw:
        return "utf-16" if raw.read(2) in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"


def read(source):
    runs = pd.read_csv(source, comment="#", encoding=encoding(source))
    return runs if {"makespan", "cycles"} <= set(runs.columns) else None


def summary(values):
    return {
        "mejor": f"{values.min()}",
        "mediana": f"{values.median():.1f}",
        "promedio": f"{values.mean():.2f}",
        "peor": f"{values.max()}",
        "desviacion": f"{values.std():.2f}",
    }


def histogram(values, target):
    figure, axes = plt.subplots(figsize=(9, 5))
    axes.hist(values, bins=BINS, color="steelblue")
    axes.axvline(values.min(), color="red", linewidth=1.2,
                 label=f"mejor {values.min()}")
    axes.axvline(values.median(), color="black", linewidth=1.2, linestyle="--",
                 label=f"mediana {values.median():.1f}")
    axes.set_xlabel("makespan")
    axes.set_ylabel("corridas")
    axes.legend(frameon=False)
    axes.spines["top"].set_visible(False)
    axes.spines["right"].set_visible(False)
    figure.tight_layout()
    figure.savefig(target, dpi=150)
    plt.close(figure)
    return target


def report(source):
    runs = read(source)
    if runs is None:
        print(f"{source}: no hay columnas 'makespan' y 'cycles', se omite")
        return

    # a run is feasible when it has no cycles OwO
    feasible = runs[runs["cycles"] == 0]
    print(source)
    print(f"  {'factibles':<12}{len(feasible):,} de {len(runs):,} "
          f"({len(feasible) / len(runs):.1%})")
    if "seconds" in runs.columns:
        print(f"  {'tiempo':<12}{runs['seconds'].mean():.2f} s por corrida")
    if feasible.empty:
        return

    for name, value in summary(feasible["makespan"]).items():
        print(f"  {name:<12}{value}")
    RESULTS.mkdir(exist_ok=True)
    print(f"  {'grafica':<12}{histogram(feasible['makespan'], RESULTS / f'{source.stem}-dist.png')}")


for argument in sys.argv[1:] or sorted(RESULTS.glob("*.csv")):
    report(Path(argument))
