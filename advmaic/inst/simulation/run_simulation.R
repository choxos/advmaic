#' Main Simulation Runner
#'
#' Executes the full MAIC simulation study comparing novel weighting methods.

# =============================================================================
# SETUP
# =============================================================================

library(advmaic)
library(dplyr)
library(tidyr)
library(parallel)
library(progressr)

# Source configuration and data generation
source(here::here("inst/simulation/config.R"))
source(here::here("inst/simulation/data_generation.R"))

# Create output directory
if (!dir.exists(SIM_CONFIG$output_dir)) {
  dir.create(SIM_CONFIG$output_dir, recursive = TRUE)
}

# =============================================================================
# SINGLE ITERATION FUNCTION
# =============================================================================

#' Run single simulation iteration
#'
#' @param scenario_params List of scenario parameters
#' @param method_config Method configuration from METHODS
#' @param iteration Iteration number
#' @param seed Random seed
#'
#' @return List with results
run_single_iteration <- function(scenario_params, method_config, iteration, seed) {

  set.seed(seed)
  start_time <- Sys.time()

  result <- tryCatch({

    # Generate data
    data <- do.call(generate_maic_scenario, scenario_params)
    covariates <- paste0("X", 1:scenario_params$n_covariates)

    # Run method
    if (method_config$method == "bucher") {
      # Unadjusted Bucher comparison
      estimate <- run_bucher_unadjusted(data)

    } else if (method_config$method == "maic") {
      # Standard MAIC methods
      estimate <- run_maic_method(data, covariates, method_config)

    } else if (method_config$method == "maic_ild") {
      # Arm-separate with ILD balancing
      estimate <- run_maic_ild(data, covariates, method_config)

    } else if (method_config$method == "maic_npca") {
      # MAIC with NPCA base weights
      estimate <- run_maic_npca(data, covariates, method_config)
    }

    list(
      success = TRUE,
      estimate = estimate$d_BC,
      se = estimate$se_BC,
      ci_lower = estimate$ci_lower,
      ci_upper = estimate$ci_upper,
      ess = estimate$ess,
      converged = estimate$converged,
      compute_time = as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    )

  }, error = function(e) {
    list(
      success = FALSE,
      estimate = NA,
      se = NA,
      ci_lower = NA,
      ci_upper = NA,
      ess = NA,
      converged = FALSE,
      compute_time = NA,
      error_message = conditionMessage(e)
    )
  })

  result$iteration <- iteration
  result$seed <- seed
  result
}

# =============================================================================
# METHOD IMPLEMENTATIONS
# =============================================================================

#' Run unadjusted Bucher comparison
run_bucher_unadjusted <- function(data) {

  ipd <- data$AB_ipd

  # Estimate d_AB without adjustment
  if (data$parameters$outcome_type == "binary") {
    trt <- ipd$treatment == 1
    ctrl <- ipd$treatment == 0

    p_trt <- mean(ipd$outcome[trt])
    p_ctrl <- mean(ipd$outcome[ctrl])

    d_AB <- log((p_trt / (1 - p_trt)) / (p_ctrl / (1 - p_ctrl)))
    var_AB <- 1/sum(ipd$outcome[trt]) + 1/sum(!ipd$outcome[trt]) +
              1/sum(ipd$outcome[ctrl]) + 1/sum(!ipd$outcome[ctrl])

  } else if (data$parameters$outcome_type == "continuous") {
    d_AB <- mean(ipd$outcome[ipd$treatment == 1]) -
            mean(ipd$outcome[ipd$treatment == 0])
    var_AB <- var(ipd$outcome[ipd$treatment == 1]) / sum(ipd$treatment == 1) +
              var(ipd$outcome[ipd$treatment == 0]) / sum(ipd$treatment == 0)
  }

  # Bucher indirect comparison
  d_BC <- d_AB - data$d_AC
  se_BC <- sqrt(var_AB + data$var_d_AC)

  list(
    d_BC = d_BC,
    se_BC = se_BC,
    ci_lower = d_BC - 1.96 * se_BC,
    ci_upper = d_BC + 1.96 * se_BC,
    ess = nrow(ipd),
    converged = TRUE
  )
}

#' Run standard MAIC method
run_maic_method <- function(data, covariates, method_config) {

  ipd <- data$AB_ipd
  agd_target <- data$AC_agd

  # Select AgD targets for covariates
  agd_target <- agd_target[covariates]

  # Add variance targets if needed
  if (isTRUE(method_config$match_variance)) {
    for (cov in covariates) {
      var_name <- paste0(cov, "_var")
      if (var_name %in% names(data$AC_agd)) {
        agd_target[var_name] <- data$AC_agd[var_name]
      } else {
        # Calculate from AC IPD if available
        agd_target[var_name] <- var(data$AC_ipd[[cov]])
      }
    }
  }

  # Set up method parameters
  method_args <- list(
    ipd = ipd,
    agd_target = agd_target,
    covariates = covariates,
    method = method_config$weight_method
  )

  if (!is.null(method_config$loss_function)) {
    method_args$loss_function <- method_config$loss_function
  }
  if (!is.null(method_config$gamma)) {
    method_args$gamma <- method_config$gamma
  }
  if (isTRUE(method_config$match_variance)) {
    method_args$match_variance <- TRUE
  }

  # Arm-separate weighting
  if (isTRUE(method_config$by_arm)) {
    arm_agd <- generate_arm_specific_agd(data$AC_ipd, covariates, "treatment")

    weights <- eb_arm_separate(
      ipd = ipd,
      agd_target = arm_agd,
      covariates = covariates,
      arm_var = "treatment",
      treatment_value = 1,
      control_value = 0,
      method = method_config$weight_method
    )
  } else {
    weights <- do.call(estimate_weights, method_args)
  }

  # Estimate treatment effect
  if (data$parameters$outcome_type == "binary") {
    fit <- glm(outcome ~ treatment, data = ipd, family = binomial(),
               weights = weights$weights * nrow(ipd))

    d_AB <- coef(fit)["treatment"]
    var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]

  } else if (data$parameters$outcome_type == "continuous") {
    fit <- lm(outcome ~ treatment, data = ipd,
              weights = weights$weights * nrow(ipd))

    d_AB <- coef(fit)["treatment"]
    var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]
  }

  # Bucher indirect comparison
  d_BC <- d_AB - data$d_AC
  se_BC <- sqrt(var_AB + data$var_d_AC)

  list(
    d_BC = d_BC,
    se_BC = se_BC,
    ci_lower = d_BC - 1.96 * se_BC,
    ci_upper = d_BC + 1.96 * se_BC,
    ess = weights$ess,
    converged = weights$convergence$converged
  )
}

#' Run MAIC with ILD covariate balancing
run_maic_ild <- function(data, covariates, method_config) {

  ipd <- data$AB_ipd
  arm_agd <- generate_arm_specific_agd(data$AC_ipd, covariates, "treatment")

  # Split covariates: common (in AgD) and ILD (IPD only)
  # For simulation, use first 2 as common, rest as ILD
  common_covs <- covariates[1:min(2, length(covariates))]
  ild_covs <- if (length(covariates) > 2) covariates[3:length(covariates)] else NULL

  if (is.null(ild_covs)) {
    # Fall back to regular arm-separate
    return(run_maic_method(data, covariates, modifyList(method_config, list(by_arm = TRUE))))
  }

  weights <- eb_arm_ild(
    ipd = ipd,
    agd_target = list(
      treatment = arm_agd$treatment[common_covs],
      control = arm_agd$control[common_covs]
    ),
    common_covariates = common_covs,
    ild_covariates = ild_covs,
    arm_var = "treatment",
    treatment_value = 1,
    control_value = 0,
    method = method_config$weight_method %||% "entropy"
  )

  # Estimate treatment effect
  if (data$parameters$outcome_type == "binary") {
    fit <- glm(outcome ~ treatment, data = ipd, family = binomial(),
               weights = weights$weights * nrow(ipd))
    d_AB <- coef(fit)["treatment"]
    var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]
  } else {
    fit <- lm(outcome ~ treatment, data = ipd,
              weights = weights$weights * nrow(ipd))
    d_AB <- coef(fit)["treatment"]
    var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]
  }

  d_BC <- d_AB - data$d_AC
  se_BC <- sqrt(var_AB + data$var_d_AC)

  list(
    d_BC = d_BC,
    se_BC = se_BC,
    ci_lower = d_BC - 1.96 * se_BC,
    ci_upper = d_BC + 1.96 * se_BC,
    ess = weights$ess,
    converged = weights$convergence$converged
  )
}

#' Run MAIC with NPCA base weights
run_maic_npca <- function(data, covariates, method_config) {

  ipd <- data$AB_ipd
  agd_target <- data$AC_agd[covariates]

  # Use first half of covariates for population adjustment, second half for efficiency
  n_cov <- length(covariates)
  pop_covs <- covariates[1:ceiling(n_cov/2)]
  eff_covs <- covariates

  weights <- maic_with_npca(
    ipd = ipd,
    agd_target = agd_target[pop_covs],
    population_covariates = pop_covs,
    efficiency_covariates = eff_covs,
    treatment_var = "treatment",
    method = method_config$weight_method %||% "entropy"
  )

  # Estimate treatment effect
  if (data$parameters$outcome_type == "binary") {
    fit <- glm(outcome ~ treatment, data = ipd, family = binomial(),
               weights = weights$weights * nrow(ipd))
    d_AB <- coef(fit)["treatment"]
    var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]
  } else {
    fit <- lm(outcome ~ treatment, data = ipd,
              weights = weights$weights * nrow(ipd))
    d_AB <- coef(fit)["treatment"]
    var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]
  }

  d_BC <- d_AB - data$d_AC
  se_BC <- sqrt(var_AB + data$var_d_AC)

  list(
    d_BC = d_BC,
    se_BC = se_BC,
    ci_lower = d_BC - 1.96 * se_BC,
    ci_upper = d_BC + 1.96 * se_BC,
    ess = weights$ess,
    converged = weights$convergence$converged
  )
}

# =============================================================================
# MAIN SIMULATION LOOP
# =============================================================================

#' Run full simulation study
#'
#' @param scenarios Data frame of scenario configurations (or NULL for all)
#' @param methods List of method names to run (or NULL for all)
#' @param n_iter Number of iterations (overrides config if provided)
#' @param parallel Use parallel processing
#'
#' @return Data frame with all results
run_simulation_study <- function(scenarios = NULL,
                                  methods = NULL,
                                  n_iter = NULL,
                                  parallel = SIM_CONFIG$use_parallel) {

  # Get scenario grid
  if (is.null(scenarios)) {
    scenarios <- generate_scenario_grid()
  }

  # Get methods
  if (is.null(methods)) {
    methods <- names(METHODS)
  }

  # Number of iterations
  n_iterations <- n_iter %||% SIM_CONFIG$n_iterations

  cat("=== Starting MAIC Simulation Study ===\n")
  cat("Scenarios:", nrow(scenarios), "\n")
  cat("Methods:", length(methods), "\n")
  cat("Iterations:", n_iterations, "\n")
  cat("Total runs:", nrow(scenarios) * length(methods) * n_iterations, "\n\n")

  # Initialize results storage
  all_results <- list()

  # Set up progress handler
  handlers(global = TRUE)
  handlers("progress")

  # Loop over scenarios
  for (s in 1:nrow(scenarios)) {
    scenario_row <- scenarios[s, ]
    scenario_params <- get_scenario_params(scenario_row)

    cat(sprintf("Scenario %d/%d: %s\n", s, nrow(scenarios), scenario_row$scenario_id))

    # Loop over methods
    for (method_name in methods) {
      method_config <- METHODS[[method_name]]

      cat(sprintf("  Method: %s\n", method_config$name))

      # Run iterations
      if (parallel && SIM_CONFIG$n_cores > 1) {
        # Parallel execution
        seeds <- SIM_CONFIG$master_seed + (s - 1) * n_iterations + 1:n_iterations

        results <- mclapply(1:n_iterations, function(i) {
          run_single_iteration(scenario_params, method_config, i, seeds[i])
        }, mc.cores = SIM_CONFIG$n_cores)

      } else {
        # Sequential execution
        results <- list()
        for (i in 1:n_iterations) {
          seed <- SIM_CONFIG$master_seed + (s - 1) * n_iterations + i
          results[[i]] <- run_single_iteration(scenario_params, method_config, i, seed)

          if (i %% 100 == 0) cat(sprintf("    Iteration %d/%d\n", i, n_iterations))
        }
      }

      # Convert to data frame
      results_df <- bind_rows(lapply(results, function(r) {
        data.frame(
          scenario_id = scenario_row$scenario_id,
          method = method_name,
          iteration = r$iteration,
          estimate = r$estimate,
          se = r$se,
          ci_lower = r$ci_lower,
          ci_upper = r$ci_upper,
          ess = r$ess,
          converged = r$converged,
          compute_time = r$compute_time,
          success = r$success,
          stringsAsFactors = FALSE
        )
      }))

      # Add true value
      results_df$true_value <- scenario_params$treatment_effect_AB -
                               scenario_params$treatment_effect_AC

      all_results[[paste(scenario_row$scenario_id, method_name, sep = "_")]] <- results_df

      # Save checkpoint
      if (SIM_CONFIG$save_intermediate && s %% SIM_CONFIG$checkpoint_every == 0) {
        checkpoint_file <- file.path(SIM_CONFIG$output_dir,
                                     sprintf("checkpoint_s%03d.rds", s))
        saveRDS(all_results, checkpoint_file)
      }
    }
  }

  # Combine all results
  final_results <- bind_rows(all_results)

  # Save final results
  final_file <- file.path(SIM_CONFIG$output_dir, "simulation_results.rds")
  saveRDS(final_results, final_file)
  cat(sprintf("\nResults saved to: %s\n", final_file))

  final_results
}

# =============================================================================
# RUN SIMULATION (if executed directly)
# =============================================================================

if (sys.nframe() == 0) {
  # Run pilot simulation (small scale for testing)
  cat("Running pilot simulation...\n")

  pilot_scenarios <- generate_scenario_grid()[1:3, ]  # First 3 scenarios
  pilot_methods <- c("Bucher", "SigTotal", "EbTotal")  # 3 methods

  pilot_results <- run_simulation_study(
    scenarios = pilot_scenarios,
    methods = pilot_methods,
    n_iter = 100,
    parallel = FALSE
  )

  cat("\nPilot simulation complete.\n")
  print(head(pilot_results))
}

# Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x
