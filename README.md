# advmaic: Advanced Matching-Adjusted Indirect Comparisons

[![R Package](https://img.shields.io/badge/R%20Package-advmaic-blue)](https://github.com/choxos/advmaic)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An R package implementing novel weighting methods for Matching-Adjusted Indirect Comparisons (MAIC), along with a comprehensive simulation study comparing alternative approaches.

## Overview

Matching-adjusted indirect comparison (MAIC) is a population adjustment method used in health technology assessment when head-to-head trials are unavailable. This package implements:

- **Standard MAIC** (method of moments and entropy balancing)
- **Alternative loss functions** from the Cressie-Read divergence family (empirical likelihood, chi-squared, Hellinger)
- **Arm-separate weighting** schemes for when arm-specific aggregate data is available
- **Non-uniform base weights** framework for combining MAIC with other adjustments (IPCW, NPCA)

The package accompanies a simulation study that empirically confirms the equivalence of method of moments and entropy balancing (Phillippo et al., 2020) and evaluates the performance of alternative weighting approaches.

## Installation

```r
# Install from GitHub
devtools::install_github("choxos/advmaic")
```

## Quick Start

```r
library(advmaic)

# Load example data
data(maic_example)

# Estimate weights using entropy balancing
weights <- estimate_weights(
  ipd = maic_example$AB_ipd,
  agd_target = maic_example$AC_agd,
  covariates = c("age", "male", "biomarker"),
  method = "entropy"
)

# View results
print(weights)

# Check covariate balance
check_balance(
  ipd = maic_example$AB_ipd,
  agd_target = maic_example$AC_agd,
  weights = weights$weights,
  covariates = c("age", "male", "biomarker")
)

# Estimate treatment effect
ate <- estimate_ate(
  ipd = maic_example$AB_ipd,
  weights = weights$weights,
  outcome_var = "outcome",
  treatment_var = "treatment",
  outcome_type = "binary"
)
```

## Key Functions

| Function | Description |
|----------|-------------|
| `estimate_weights()` | Main function for weight estimation with multiple methods |
| `eb_arm_separate()` | Arm-separate entropy balancing |
| `eb_arm_ild()` | Arm-separate with ILD covariate balancing |
| `check_balance()` | Assess covariate balance after weighting |
| `calculate_ess()` | Compute effective sample size |
| `estimate_ate()` | Estimate average treatment effect |
| `bucher_idc()` | Perform Bucher indirect comparison |
| `maic_analysis()` | Complete MAIC analysis pipeline |

## Weighting Methods

### Standard Methods

```r
# Method of moments (original Signorovitch approach)
weights_mom <- estimate_weights(ipd, agd_target, covariates, method = "moments")

# Entropy balancing (mathematically equivalent to method of moments)
weights_eb <- estimate_weights(ipd, agd_target, covariates, method = "entropy")
```

### Alternative Loss Functions

```r
# Empirical likelihood
weights_el <- estimate_weights(ipd, agd_target, covariates,
                               method = "entropy",
                               loss_function = "empirical_likelihood")

# Chi-squared divergence
weights_chi <- estimate_weights(ipd, agd_target, covariates,
                                method = "entropy",
                                loss_function = "chi_squared")
```

### Arm-Separate Weighting

```r
# When arm-specific aggregate data is available
arm_agd <- list(
  treatment = c(age = 58, male = 0.55),
  control = c(age = 62, male = 0.45)
)

weights_arm <- eb_arm_separate(
  ipd = ipd,
  agd_target = arm_agd,
  covariates = c("age", "male"),
  arm_var = "treatment",
  treatment_value = 1,
  control_value = 0
)
```

## Simulation Study

This repository includes a comprehensive simulation study comparing MAIC weighting methods. The study evaluated 5 methods across 54 scenarios with 1,000 iterations each.

### Key Findings

1. **Method of moments = Entropy balancing**: Numerically identical results (max difference < 3e-08), confirming Phillippo et al. (2020)

2. **MAIC reduces bias when effect modifiers present**:
   - Bucher (unadjusted): bias = -0.130
   - MAIC methods: bias = -0.030

3. **Effective sample size is critical**: Low population overlap dramatically reduces ESS

4. **Arm-separate methods require caution**: Unstable under low overlap conditions

### Results Summary

| Method | Mean Bias | Coverage | Mean ESS |
|--------|-----------|----------|----------|
| EbTotal/SigTotal | -0.030 | 94.3% | 192 |
| EbEL | -0.036 | 91.8% | 147 |
| EbArm | -0.047 | 94.3% | 186 |
| Bucher | -0.130 | 91.6% | 300 |

### Accessing Simulation Materials

All simulation materials are in the `/simulation` folder:

```
simulation/
├── protocol.pdf          # Pre-registration protocol
├── manuscript.pdf        # Full results paper
├── code/                 # R simulation scripts
│   ├── data_generation.R
│   ├── config.R
│   ├── run_pilot.R
│   └── run_full_simulation.R
└── results/
    ├── csv/              # Results in CSV format
    ├── figures/          # Publication figures (PDF + PNG)
    └── *.rds             # R data files
```

### Reproducing the Simulation

```r
# Run pilot simulation (quick test)
source("simulation/code/run_pilot.R")

# Run full simulation (takes several hours)
source("simulation/code/run_full_simulation.R")
```

## Theoretical Background

### The Equivalence Theorem

Phillippo et al. (2020) proved that method of moments MAIC and entropy balancing are mathematically equivalent through convex duality. Both solve:

**Primal (Entropy Balancing):**

Minimize the Kullback-Leibler divergence from uniform weights subject to covariate balance constraints.

**Dual (Method of Moments):**

Minimize the log-sum-exp of linear predictors, which yields the same optimal weights.

### Cressie-Read Divergence Family

The package supports the full Cressie-Read family parameterized by gamma:

| gamma | Divergence |
|-------|------------|
| 0 | Kullback-Leibler (entropy) |
| -1 | Empirical likelihood |
| 1 | Chi-squared |
| -0.5 | Hellinger |

## Citation

If you use this package, please cite:

```bibtex
@software{advmaic2026,
  author = {Sofi-Mahmudi, Ahmad},
  title = {advmaic: Advanced Matching-Adjusted Indirect Comparisons},
  year = {2026},
  url = {https://github.com/choxos/advmaic}
}
```

And the key methodological references:

```bibtex
@article{phillippo2020,
  title = {Equivalence of Entropy Balancing and the Method of Moments for
           Matching-Adjusted Indirect Comparison},
  author = {Phillippo, David M and Dias, Sofia and Ades, A E and Welton, Nicky J},
  journal = {Research Synthesis Methods},
  volume = {11},
  pages = {568--572},
  year = {2020}
}

@article{signorovitch2010,
  title = {Comparative Effectiveness Without Head-to-Head Trials},
  author = {Signorovitch, James E and Wu, Eric Q and others},
  journal = {PharmacoEconomics},
  volume = {28},
  pages = {935--945},
  year = {2010}
}
```

## References

- Signorovitch JE et al. (2010). Comparative effectiveness without head-to-head trials. *PharmacoEconomics*.
- Signorovitch JE et al. (2012). Matching-adjusted indirect comparisons: a new tool for timely comparative effectiveness research. *Value in Health*.
- Phillippo DM et al. (2020). Equivalence of entropy balancing and the method of moments for MAIC. *Research Synthesis Methods*.
- Petto H et al. (2019). Alternative weighting approaches for anchored MAIC. *Value in Health*.
- Hainmueller J (2012). Entropy balancing for causal effects. *Political Analysis*.
- Williamson EJ et al. (2014). Variance reduction in randomised trials by inverse probability weighting. *Statistics in Medicine*.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

Ahmad Sofi-Mahmudi (a.sofimahmudi@gmail.com)
