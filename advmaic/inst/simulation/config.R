#' Simulation Study Configuration
#'
#' Defines all parameters and methods to be compared in the simulation study.

# =============================================================================
# SIMULATION PARAMETERS
# =============================================================================

SIM_CONFIG <- list(

  # Number of simulation iterations
  n_iterations = 1000,

  # Random seed for reproducibility
  master_seed = 20260117,

  # Parallel processing
  n_cores = parallel::detectCores() - 1,
  use_parallel = TRUE,

  # Output directory
  output_dir = "results",

  # Save intermediate results
  save_intermediate = TRUE,
  checkpoint_every = 100
)

# =============================================================================
# METHODS TO COMPARE
# =============================================================================

METHODS <- list(

  # Standard methods
  Bucher = list(
    name = "Bucher (unadjusted)",
    method = "bucher",
    description = "Standard indirect comparison without matching"
  ),

  SigTotal = list(
    name = "SigTotal (Standard MAIC)",
    method = "maic",
    weight_method = "moments",
    match_variance = FALSE,
    by_arm = FALSE,
    description = "Standard MAIC matching on total population"
  ),

  SigTotalVar = list(
    name = "SigTotalVar",
    method = "maic",
    weight_method = "moments",
    match_variance = TRUE,
    by_arm = FALSE,
    description = "MAIC matching mean and variance"
  ),

  SigArm = list(
    name = "SigArm",
    method = "maic",
    weight_method = "moments",
    match_variance = FALSE,
    by_arm = TRUE,
    description = "MAIC with arm-separate weighting (method of moments)"
  ),

  EbTotal = list(
    name = "EbTotal",
    method = "maic",
    weight_method = "entropy",
    match_variance = FALSE,
    by_arm = FALSE,
    description = "Entropy balancing on total population"
  ),

  EbArm = list(
    name = "EbArm",
    method = "maic",
    weight_method = "entropy",
    match_variance = FALSE,
    by_arm = TRUE,
    description = "Entropy balancing with arm-separate weighting"
  ),

  EbArmILD = list(
    name = "EbArmILD",
    method = "maic_ild",
    weight_method = "entropy",
    description = "Entropy balancing by arm with ILD covariate balancing"
  ),

  # Novel methods from Phillippo 2020

  EbNPCA = list(
    name = "EbNPCA",
    method = "maic_npca",
    weight_method = "entropy",
    description = "Entropy balancing with NPCA base weights"
  ),

  EbEL = list(
    name = "EbEL (Empirical Likelihood)",
    method = "maic",
    weight_method = "entropy",
    loss_function = "empirical_likelihood",
    description = "Entropy balancing with empirical likelihood loss"
  ),

  EbCR05 = list(
    name = "EbCR (gamma=0.5)",
    method = "maic",
    weight_method = "entropy",
    loss_function = "cressie_read",
    gamma = 0.5,
    description = "Entropy balancing with Cressie-Read divergence (gamma=0.5)"
  ),

  EbCR1 = list(
    name = "EbCR (Chi-squared)",
    method = "maic",
    weight_method = "entropy",
    loss_function = "cressie_read",
    gamma = 1,
    description = "Entropy balancing with chi-squared divergence"
  )
)

# =============================================================================
# SCENARIO CONFIGURATIONS
# =============================================================================

SCENARIOS <- list(

  # Sample size variations
  sample_size = list(
    n_AB = c(100, 300, 500),
    n_AC = c(200, 500, 1000)
  ),

  # Number of covariates
  n_covariates = c(3, 6, 10),

  # Population overlap (shift magnitude)
  population_overlap = list(
    high = 0.2,
    medium = 0.5,
    low = 1.0
  ),

  # Effect modifiers
  effect_modifiers = list(
    none = list(em = NULL, coef = NULL),
    one = list(em = 1, coef = 0.3),
    two = list(em = c(1, 2), coef = c(0.3, 0.2))
  ),

  # Unmeasured effect modification
  unmeasured_em = c(FALSE, TRUE),

  # Outcome type
  outcome_type = c("binary", "continuous", "tte"),

  # Treatment switching (for IPCW methods)
  treatment_switching = list(
    none = 0,
    low = 0.1,
    high = 0.3
  )
)

# =============================================================================
# PERFORMANCE METRICS
# =============================================================================

METRICS <- c(
  "bias",           # Bias = mean(estimate) - true
  "empirical_se",   # Empirical SE = sd(estimates)
  "model_se",       # Mean of model-based SEs
  "mse",            # Mean squared error
  "rmse",           # Root MSE
  "coverage",       # 95% CI coverage probability
  "ess_mean",       # Mean effective sample size
  "ess_median",     # Median ESS
  "convergence",    # Proportion converged
  "compute_time"    # Mean computation time
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

#' Generate all scenario combinations
#'
#' Creates a grid of all scenario parameter combinations
#'
#' @return Data frame with one row per scenario
generate_scenario_grid <- function() {

  # Create base grid for main comparisons
  grid <- expand.grid(
    n_AB = c(100, 300, 500),
    population_overlap = c("high", "medium", "low"),
    n_covariates = c(3, 6),
    effect_modifiers = c("none", "one", "two"),
    outcome_type = c("binary"),
    stringsAsFactors = FALSE
  )

  # Add scenario ID
  grid$scenario_id <- paste0("S", sprintf("%03d", 1:nrow(grid)))

  # Add derived parameters
  grid$shift_magnitude <- sapply(grid$population_overlap, function(x) {
    SCENARIOS$population_overlap[[x]]
  })

  grid
}

#' Get scenario parameters
#'
#' @param scenario_row Row from scenario grid
#' @return List of parameters for generate_maic_scenario
get_scenario_params <- function(scenario_row) {

  n_cov <- scenario_row$n_covariates

  # Population shift vector
  shift <- rep(0, n_cov)
  shift[1] <- scenario_row$shift_magnitude
  if (n_cov > 1) shift[2] <- scenario_row$shift_magnitude * 0.5
  if (n_cov > 2) shift[3] <- scenario_row$shift_magnitude * 0.25

  # Effect modifier config
  em_config <- SCENARIOS$effect_modifiers[[scenario_row$effect_modifiers]]

  list(
    n_AB = scenario_row$n_AB,
    n_AC = 500,  # Fixed comparator trial size
    n_covariates = n_cov,
    population_shift = shift,
    treatment_effect_AB = -0.5,
    treatment_effect_AC = -0.7,
    effect_modifiers = em_config$em,
    effect_modifier_coeffs = em_config$coef,
    outcome_type = scenario_row$outcome_type
  )
}

#' Print simulation configuration summary
print_config_summary <- function() {
  cat("=== MAIC Simulation Study Configuration ===\n\n")

  cat("Iterations:", SIM_CONFIG$n_iterations, "\n")
  cat("Parallel cores:", SIM_CONFIG$n_cores, "\n\n")

  cat("Methods to compare:", length(METHODS), "\n")
  for (m in names(METHODS)) {
    cat("  -", METHODS[[m]]$name, "\n")
  }

  cat("\nScenario grid:\n")
  grid <- generate_scenario_grid()
  cat("  Total scenarios:", nrow(grid), "\n")
  cat("  Sample sizes:", paste(unique(grid$n_AB), collapse = ", "), "\n")
  cat("  Overlap levels:", paste(unique(grid$population_overlap), collapse = ", "), "\n")
  cat("  Covariates:", paste(unique(grid$n_covariates), collapse = ", "), "\n")

  cat("\nTotal simulation runs:", nrow(grid) * length(METHODS) * SIM_CONFIG$n_iterations, "\n")
}

# Print summary if sourced directly
if (interactive()) {
  print_config_summary()
}
