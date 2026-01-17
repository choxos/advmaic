# advmaic

Advanced Matching-Adjusted Indirect Comparison (MAIC) Methods for R

## Overview

`advmaic` implements novel weighting approaches for Matching-Adjusted Indirect Comparisons (MAIC), including:

- **Entropy balancing with non-uniform base weights** - Combine MAIC with other adjustment methods
- **Alternative loss functions** - Cressie-Read divergence family (entropy, empirical likelihood, chi-squared)
- **Arm-separate weighting schemes** - EbArm, EbArmILD (Petto et al. 2019)
- **Combined adjustment methods** - MAIC + IPCW for treatment switching, MAIC + NPCA for variance reduction

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("choxos/advmaic")
```

## Quick Example

```r
library(advmaic)

# Simulate IPD from index trial
set.seed(123)
n <- 200
ipd <- data.frame(
  age = rnorm(n, 55, 10),
  male = rbinom(n, 1, 0.6),
  treatment = rbinom(n, 1, 0.5),
  outcome = rnorm(n, 0, 1)
)

# Target moments from aggregate data
agd_target <- c(age = 60, male = 0.5)

# Estimate MAIC weights
weights <- estimate_weights(
  ipd = ipd,
  agd_target = agd_target,
  covariates = c("age", "male"),
  method = "entropy"
)

print(weights)
# Check balance
balance <- check_balance(ipd, agd_target, weights, c("age", "male"))
print(balance)

# Visualize weight distribution
plot(weights)
```

## Novel Methods

### Non-uniform Base Weights (Phillippo 2020)

```r
# MAIC with NPCA base weights for variance reduction
weights <- maic_with_npca(
  ipd = ipd,
  agd_target = agd_target,
  population_covariates = c("age", "male"),
  efficiency_covariates = c("biomarker"),
  treatment_var = "treatment"
)

# MAIC with IPCW for treatment switching
weights <- maic_with_treatment_switching(
  ipd = ipd,
  agd_target = agd_target,
  covariates = c("age", "male"),
  time_var = "time",
  event_var = "event",
  switch_var = "switched",
  switch_covariates = c("age", "biomarker")
)
```

### Alternative Loss Functions

```r
# Standard entropy (Kullback-Leibler)
weights_entropy <- estimate_weights(ipd, agd_target, covariates,
                                    loss_function = "entropy")

# Empirical likelihood
weights_el <- estimate_weights(ipd, agd_target, covariates,
                               loss_function = "empirical_likelihood")

# Cressie-Read with custom gamma
weights_cr <- estimate_weights(ipd, agd_target, covariates,
                               loss_function = "cressie_read", gamma = 0.5)
```

### Arm-Separate Weighting (Petto 2019)

```r
# Arm-separate targets
agd_target_arm <- list(
  treatment = c(age = 58, male = 0.55),
  control = c(age = 62, male = 0.50)
)

# EbArm: separate weighting by arm
weights <- eb_arm_separate(
  ipd = ipd,
  agd_target = agd_target_arm,
  covariates = c("age", "male"),
  arm_var = "treatment",
  treatment_value = 1,
  control_value = 0
)

# EbArmILD: with ILD covariate balancing
weights <- eb_arm_ild(
  ipd = ipd,
  agd_target = agd_target_arm,
  common_covariates = c("age", "male"),
  ild_covariates = c("biomarker"),  # IPD-only
  arm_var = "treatment",
  treatment_value = 1,
  control_value = 0
)
```

## Full Analysis Pipeline

```r
# Complete MAIC analysis
result <- maic_analysis(
  ipd = ipd,
  agd_target = agd_target,
  agd_effect = 0.3,      # log OR from comparator trial
  agd_var = 0.05,
  covariates = c("age", "male"),
  outcome_var = "outcome",
  treatment_var = "treatment",
  outcome_type = "binary",
  estimand = "or"
)

# Access results
result$weights     # MAIC weights
result$balance     # Balance diagnostics
result$ate         # Treatment effect (B vs A)
result$idc         # Indirect comparison (B vs C)
```

## References

1. Phillippo DM, et al. (2020). Equivalence of entropy balancing and the method of moments for matching-adjusted indirect comparison. *Res Synth Methods*. 11:568-572.

2. Petto H, et al. (2019). Alternative weighting approaches for anchored matching-adjusted indirect comparisons via a common comparator. *Value Health*. 22:85-91.

3. Williamson EJ, et al. (2014). Variance reduction in randomised trials by inverse probability weighting using the propensity score. *Stat Med*. 33:721-737.

4. Hainmueller J. (2012). Entropy balancing for causal effects: A multivariate reweighting method to produce balanced samples in observational studies. *Polit Anal*. 20:25-46.

## License

MIT License

## Author

Ahmad Sofi-Mahmudi (a.sofimahmudi@gmail.com)
