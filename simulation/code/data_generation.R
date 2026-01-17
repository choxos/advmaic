#' Data Generation Functions for MAIC Simulation Study
#'
#' Based on simulation designs from Petto et al. (2019) and Phillippo (2020).
#' Generates IPD and AgD for two-trial scenarios with population differences.

library(dplyr)
library(tidyr)

#' Generate Individual Patient Data for a Trial
#'
#' @param n Sample size
#' @param n_covariates Number of covariates
#' @param covariate_means Vector of covariate means
#' @param covariate_sds Vector of covariate standard deviations
#' @param covariate_cors Correlation matrix for covariates (NULL for independent)
#' @param treatment_effect True treatment effect (log scale for binary/TTE)
#' @param effect_modifiers Indices of covariates that are effect modifiers
#' @param effect_modifier_coeffs Coefficients for effect modification
#' @param prognostic_coeffs Coefficients for prognostic effects
#' @param intercept Baseline intercept
#' @param outcome_type "continuous", "binary", or "tte"
#' @param residual_sd Residual SD for continuous outcomes
#' @param treatment_allocation Proportion allocated to treatment
#' @param seed Random seed
#'
#' @return Data frame with IPD
generate_trial_ipd <- function(n,
                                n_covariates = 3,
                                covariate_means = NULL,
                                covariate_sds = NULL,
                                covariate_cors = NULL,
                                treatment_effect = -0.5,
                                effect_modifiers = NULL,
                                effect_modifier_coeffs = NULL,
                                prognostic_coeffs = NULL,
                                intercept = 0,
                                outcome_type = c("continuous", "binary", "tte"),
                                residual_sd = 1,
                                treatment_allocation = 0.5,
                                seed = NULL) {

  outcome_type <- match.arg(outcome_type)

  if (!is.null(seed)) set.seed(seed)

  # Default covariate parameters
  if (is.null(covariate_means)) {
    covariate_means <- rep(0, n_covariates)
  }
  if (is.null(covariate_sds)) {
    covariate_sds <- rep(1, n_covariates)
  }
  if (is.null(prognostic_coeffs)) {
    prognostic_coeffs <- rep(0.3, n_covariates)
  }

  # Generate covariates
  if (is.null(covariate_cors)) {
    # Independent covariates
    X <- matrix(rnorm(n * n_covariates), nrow = n, ncol = n_covariates)
    X <- sweep(X, 2, covariate_sds, "*")
    X <- sweep(X, 2, covariate_means, "+")
  } else {
    # Correlated covariates using Cholesky decomposition
    L <- chol(covariate_cors)
    Z <- matrix(rnorm(n * n_covariates), nrow = n, ncol = n_covariates)
    X <- Z %*% L
    X <- sweep(X, 2, covariate_sds, "*")
    X <- sweep(X, 2, covariate_means, "+")
  }

  colnames(X) <- paste0("X", 1:n_covariates)

  # Generate treatment assignment (randomized)
  treatment <- rbinom(n, 1, treatment_allocation)

  # Calculate linear predictor
  # Y = intercept + sum(beta_k * X_k) + tau * T + sum(gamma_k * X_k * T) + epsilon
  linear_pred <- intercept + X %*% prognostic_coeffs + treatment * treatment_effect

  # Add effect modification
  if (!is.null(effect_modifiers) && !is.null(effect_modifier_coeffs)) {
    for (i in seq_along(effect_modifiers)) {
      em_idx <- effect_modifiers[i]
      linear_pred <- linear_pred + treatment * X[, em_idx] * effect_modifier_coeffs[i]
    }
  }

  # Generate outcome
  if (outcome_type == "continuous") {
    outcome <- linear_pred + rnorm(n, 0, residual_sd)
  } else if (outcome_type == "binary") {
    # Logistic model
    prob <- plogis(linear_pred)
    outcome <- rbinom(n, 1, prob)
  } else if (outcome_type == "tte") {
    # Exponential survival model
    # hazard = exp(linear_pred), time = -log(U) / hazard
    hazard <- exp(linear_pred)
    time <- -log(runif(n)) / hazard
    # Censoring at fixed time point
    censor_time <- quantile(time, 0.9)
    event <- as.numeric(time <= censor_time)
    time <- pmin(time, censor_time)
    outcome <- time  # Return time, event separately
  }

  # Create data frame
  ipd <- as.data.frame(X)
  ipd$treatment <- treatment
  ipd$outcome <- as.vector(outcome)

  if (outcome_type == "tte") {
    ipd$time <- time
    ipd$event <- event
  }

  ipd
}

#' Generate Aggregate Data Summary from IPD
#'
#' @param ipd Individual patient data
#' @param covariates Character vector of covariate names
#' @param include_variance Whether to include variance in AgD
#'
#' @return Named vector of aggregate statistics
generate_agd_from_ipd <- function(ipd, covariates, include_variance = FALSE) {

  agd <- c()

  for (cov in covariates) {
    agd[cov] <- mean(ipd[[cov]])
    if (include_variance) {
      agd[paste0(cov, "_var")] <- var(ipd[[cov]])
    }
  }

  agd
}

#' Generate Two-Trial MAIC Scenario
#'
#' Generates IPD for index trial (AB) and AgD for comparator trial (AC).
#'
#' @param n_AB Sample size for AB trial
#' @param n_AC Sample size for AC trial
#' @param n_covariates Number of covariates
#' @param population_shift Vector of mean shifts for AC vs AB population
#' @param treatment_effect_AB True effect of B vs A (log scale)
#' @param treatment_effect_AC True effect of C vs A (log scale)
#' @param effect_modifiers Indices of effect modifier covariates
#' @param effect_modifier_coeffs Effect modification coefficients
#' @param prognostic_coeffs Prognostic coefficients
#' @param outcome_type Type of outcome
#' @param include_variance Include variance in AgD
#' @param seed Random seed
#'
#' @return List with AB_ipd, AC_agd, true_effect_BC, and scenario parameters
generate_maic_scenario <- function(n_AB = 300,
                                    n_AC = 500,
                                    n_covariates = 3,
                                    population_shift = NULL,
                                    treatment_effect_AB = -0.5,
                                    treatment_effect_AC = -0.7,
                                    effect_modifiers = 1,
                                    effect_modifier_coeffs = 0.3,
                                    prognostic_coeffs = NULL,
                                    outcome_type = "binary",
                                    include_variance = FALSE,
                                    seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  # Default population shift (AC population older/different from AB)
  if (is.null(population_shift)) {
    population_shift <- c(0.5, rep(0, n_covariates - 1))  # Only first covariate differs
  }

  # Generate AB trial IPD (index trial with treatment B)
  AB_ipd <- generate_trial_ipd(
    n = n_AB,
    n_covariates = n_covariates,
    covariate_means = rep(0, n_covariates),
    covariate_sds = rep(1, n_covariates),
    treatment_effect = treatment_effect_AB,
    effect_modifiers = effect_modifiers,
    effect_modifier_coeffs = effect_modifier_coeffs,
    prognostic_coeffs = prognostic_coeffs,
    outcome_type = outcome_type
  )

  # Generate AC trial IPD (comparator trial with treatment C)
  AC_ipd <- generate_trial_ipd(
    n = n_AC,
    n_covariates = n_covariates,
    covariate_means = population_shift,  # Shifted population
    covariate_sds = rep(1, n_covariates),
    treatment_effect = treatment_effect_AC,
    effect_modifiers = effect_modifiers,
    effect_modifier_coeffs = effect_modifier_coeffs,
    prognostic_coeffs = prognostic_coeffs,
    outcome_type = outcome_type
  )

  # Create AgD from AC trial
  covariates <- paste0("X", 1:n_covariates)
  AC_agd <- generate_agd_from_ipd(AC_ipd, covariates, include_variance)

  # Calculate AgD treatment effect (C vs A) from AC trial
  if (outcome_type == "binary") {
    # Log odds ratio
    trt_idx <- AC_ipd$treatment == 1
    ctrl_idx <- AC_ipd$treatment == 0

    p_trt <- mean(AC_ipd$outcome[trt_idx])
    p_ctrl <- mean(AC_ipd$outcome[ctrl_idx])

    d_AC <- log((p_trt / (1 - p_trt)) / (p_ctrl / (1 - p_ctrl)))
    var_d_AC <- 1/sum(AC_ipd$outcome[trt_idx]) +
                1/sum(!AC_ipd$outcome[trt_idx]) +
                1/sum(AC_ipd$outcome[ctrl_idx]) +
                1/sum(!AC_ipd$outcome[ctrl_idx])

  } else if (outcome_type == "continuous") {
    # Mean difference
    d_AC <- mean(AC_ipd$outcome[AC_ipd$treatment == 1]) -
            mean(AC_ipd$outcome[AC_ipd$treatment == 0])
    var_d_AC <- var(AC_ipd$outcome[AC_ipd$treatment == 1]) / sum(AC_ipd$treatment == 1) +
                var(AC_ipd$outcome[AC_ipd$treatment == 0]) / sum(AC_ipd$treatment == 0)

  } else if (outcome_type == "tte") {
    # Log hazard ratio (simplified)
    cox_fit <- survival::coxph(
      survival::Surv(time, event) ~ treatment,
      data = AC_ipd
    )
    d_AC <- coef(cox_fit)["treatment"]
    var_d_AC <- vcov(cox_fit)["treatment", "treatment"]
  }

  # True effect of B vs C (what MAIC should estimate)
  # d_BC = d_AB - d_AC (B vs A minus C vs A = B vs C)
  # But we need conditional effect given AC population
  # For now, use the treatment effects directly
  true_effect_BC <- treatment_effect_AB - treatment_effect_AC

  list(
    AB_ipd = AB_ipd,
    AC_agd = AC_agd,
    AC_ipd = AC_ipd,  # Keep for validation
    d_AC = d_AC,
    var_d_AC = var_d_AC,
    true_effect_BC = true_effect_BC,
    parameters = list(
      n_AB = n_AB,
      n_AC = n_AC,
      n_covariates = n_covariates,
      population_shift = population_shift,
      treatment_effect_AB = treatment_effect_AB,
      treatment_effect_AC = treatment_effect_AC,
      effect_modifiers = effect_modifiers,
      effect_modifier_coeffs = effect_modifier_coeffs,
      outcome_type = outcome_type
    )
  )
}

#' Generate Arm-Specific Aggregate Data
#'
#' For arm-separate weighting methods
#'
#' @param ipd IPD from trial
#' @param covariates Covariate names
#' @param arm_var Treatment arm variable name
#'
#' @return List with treatment and control arm AgD
generate_arm_specific_agd <- function(ipd, covariates, arm_var = "treatment") {

  trt_ipd <- ipd[ipd[[arm_var]] == 1, ]
  ctrl_ipd <- ipd[ipd[[arm_var]] == 0, ]

  list(
    treatment = generate_agd_from_ipd(trt_ipd, covariates),
    control = generate_agd_from_ipd(ctrl_ipd, covariates)
  )
}

#' Generate Scenario with Treatment Switching
#'
#' For testing IPCW + MAIC methods
#'
#' @param n Sample size
#' @param switch_rate Proportion of control patients who switch
#' @param switch_covariates Covariates that predict switching
#' @param ... Other arguments passed to generate_trial_ipd
#'
#' @return IPD with switching information
generate_switching_scenario <- function(n = 300,
                                         switch_rate = 0.2,
                                         switch_covariates = 1,
                                         ...) {

  ipd <- generate_trial_ipd(n = n, ...)

  # Only control arm can switch
  ctrl_idx <- which(ipd$treatment == 0)

  # Generate switching based on covariates
  switch_linear_pred <- rep(0, length(ctrl_idx))
  for (cov_idx in switch_covariates) {
    cov_name <- paste0("X", cov_idx)
    switch_linear_pred <- switch_linear_pred + 0.5 * ipd[[cov_name]][ctrl_idx]
  }

  # Adjust intercept to achieve target switch rate
  intercept <- qlogis(switch_rate) - mean(switch_linear_pred)
  switch_prob <- plogis(intercept + switch_linear_pred)

  # Generate switching
  ipd$switched <- 0
  ipd$switched[ctrl_idx] <- rbinom(length(ctrl_idx), 1, switch_prob)

  # Generate switch time (random proportion of follow-up)
  ipd$switch_time <- NA
  switched_idx <- which(ipd$switched == 1)
  if (length(switched_idx) > 0) {
    ipd$switch_time[switched_idx] <- runif(length(switched_idx), 0.1, 0.9) *
                                      ipd$time[switched_idx]
  }

  ipd
}

#' Define Standard Simulation Scenarios
#'
#' Returns a list of scenario configurations for the simulation study
#'
#' @return List of scenario configurations
define_simulation_scenarios <- function() {

  scenarios <- list()

  # Base scenario parameters
  base <- list(
    n_AB = 300,
    n_AC = 500,
    n_covariates = 3,
    treatment_effect_AB = -0.5,
    treatment_effect_AC = -0.7,
    effect_modifiers = 1,
    effect_modifier_coeffs = 0.3,
    outcome_type = "binary"
  )

  # Scenario 1: Small population overlap (large shift)
  scenarios$low_overlap <- modifyList(base, list(
    population_shift = c(1.0, 0.5, 0),
    name = "Low population overlap"
  ))

  # Scenario 2: Medium population overlap
  scenarios$medium_overlap <- modifyList(base, list(
    population_shift = c(0.5, 0.25, 0),
    name = "Medium population overlap"
  ))

  # Scenario 3: High population overlap (small shift)
  scenarios$high_overlap <- modifyList(base, list(
    population_shift = c(0.2, 0.1, 0),
    name = "High population overlap"
  ))

  # Scenario 4: Multiple effect modifiers
  scenarios$multiple_em <- modifyList(base, list(
    effect_modifiers = c(1, 2),
    effect_modifier_coeffs = c(0.3, 0.2),
    name = "Multiple effect modifiers"
  ))

  # Scenario 5: No effect modification
  scenarios$no_em <- modifyList(base, list(
    effect_modifiers = NULL,
    effect_modifier_coeffs = NULL,
    name = "No effect modification"
  ))

  # Scenario 6: Small IPD sample
  scenarios$small_ipd <- modifyList(base, list(
    n_AB = 100,
    name = "Small IPD sample (n=100)"
  ))

  # Scenario 7: Large IPD sample
  scenarios$large_ipd <- modifyList(base, list(
    n_AB = 500,
    name = "Large IPD sample (n=500)"
  ))

  # Scenario 8: Many covariates
  scenarios$many_covariates <- modifyList(base, list(
    n_covariates = 6,
    population_shift = c(0.5, 0.3, 0.2, 0, 0, 0),
    effect_modifiers = c(1, 2),
    effect_modifier_coeffs = c(0.3, 0.2),
    name = "Many covariates (p=6)"
  ))

  # Scenario 9: Continuous outcome
  scenarios$continuous <- modifyList(base, list(
    outcome_type = "continuous",
    treatment_effect_AB = -0.3,
    treatment_effect_AC = -0.5,
    name = "Continuous outcome"
  ))

  # Scenario 10: Time-to-event outcome
  scenarios$tte <- modifyList(base, list(
    outcome_type = "tte",
    treatment_effect_AB = -0.4,
    treatment_effect_AC = -0.6,
    name = "Time-to-event outcome"
  ))

  scenarios
}

# Test the data generation
if (FALSE) {
  # Quick test
  scenario <- generate_maic_scenario(
    n_AB = 200,
    n_AC = 300,
    n_covariates = 3,
    population_shift = c(0.5, 0.2, 0),
    treatment_effect_AB = -0.5,
    treatment_effect_AC = -0.7,
    effect_modifiers = 1,
    effect_modifier_coeffs = 0.3,
    outcome_type = "binary",
    seed = 123
  )

  print(head(scenario$AB_ipd))
  print(scenario$AC_agd)
  print(scenario$d_AC)
  print(scenario$true_effect_BC)
}
