<a id="readme-top"></a>

# jssp-hoc
Job Shop Scheduling Problem

Solves the Job Shop Scheduling Problem with a discrete Lightning Search Algorithm (LSA).
A solution is an operation chain, evaluated on the disjunctive graph to get its makespan,
its operations stuck in cycles, and its cost. The leader moves by swapping operations at the
ends of critical blocks; the other projectiles move toward it with a crossover whose child
is decoded as a non-delay schedule.

The original LSA, where a solution is a vector of random keys that a decoder turns into an
operation chain, is still available as `lsa` (`--keys` in `scripts/experiment.jl`).

### Built With

* [![Julia][Julia.jl]][Julia-url]

### Usage

#### Run the tests

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

#### Evaluate an instance

```bash
julia --project scripts/evaluate.jl instances/example_3x3.txt
```

#### Solve an instance

```bash
julia --project scripts/solve.jl instances/JSSP_40_40.txt
```

Add `--seed s` to use another seed (67 by default) and `--solution` to also print the
solution before the summary

```bash
julia --project scripts/solve.jl instances/JSSP_40_40.txt --solution
```

#### Run multiple seeds

Writes one CSV row per seed (makespan, cycles, cost, seconds) to standard output and
the progress to standard error:

```bash
julia --project scripts/experiment.jl instances/JSSP_40_40.txt --seeds 30 > results/seeds.csv
```

The seeds run in parallel on the threads Julia is started with (`-t auto` uses every
core). Choose them with `--seeds k` (1 to k), `--random k` (k random seeds, written in
the CSV header as `# seed_list=...`) or `--seed-list a,b,c` (to repeat a run):

```bash
julia --project -t auto scripts/experiment.jl instances/JSSP_40_40.txt --random 30 > results/random.csv
julia --project -t auto scripts/experiment.jl instances/JSSP_40_40.txt --seed-list 386332240,602326403,... > results/again.csv
```

`--every X` prints the best makespan found so far every X finished seeds. For a seed
search, run many random seeds and look for the best one; then `solve.jl --seed` gives its
solution:

```bash
julia --project -t auto scripts/experiment.jl instances/JSSP_40_40.txt --random 1000 --every 50 > results/search_40_40.csv
julia --project scripts/solve.jl instances/JSSP_40_40.txt --seed 17319281 --solution
```

With `--keys` the original LSA is used instead, and its decoder is chosen with
`--decoder active`, `repetition` or `operations`, or `--delay δ` (non-delay, δ = 0, by default).

### Analysis

Code goes in [analysis/](analysis); anything the programs write goes in `results/`.
 Run the scripts from the project root.

```bash
python3 -m venv .venv
.venv/bin/pip install -r analysis/requirements.txt
```

Feasibility rate, makespan statistics and a histogram. With no arguments it reports
every `.csv` under `results/`:

```bash
.venv/bin/python analysis/summary.py results/seeds.csv
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

[Julia.jl]: https://img.shields.io/badge/Julia-9558B2?style=for-the-badge&logo=julia&logoColor=white
[Julia-url]: https://julialang.org/
