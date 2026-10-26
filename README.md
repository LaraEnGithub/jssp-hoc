<a id="readme-top"></a>

# jssp-hoc
Job Shop Scheduling Problem

Solves the Job Shop Scheduling Problem with the Lightning Search Algorithm (LSA).
A solution is a vector of random keys, one per operation, that a decoder turns into
an operation chain. The chain is evaluated on the disjunctive graph to get its
makespan, its operations stuck in cycles, and its cost.

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

Add `--solution` to also print the solution before the summary

```bash
julia --project scripts/solve.jl instances/JSSP_40_40.txt --solution
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

[Julia.jl]: https://img.shields.io/badge/Julia-9558B2?style=for-the-badge&logo=julia&logoColor=white
[Julia-url]: https://julialang.org/
