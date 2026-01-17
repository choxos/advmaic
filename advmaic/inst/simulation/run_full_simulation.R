#!/usr/bin/env Rscript
#' Full Simulation Script
#' Runs the complete simulation study

# Set working directory
setwd("/Users/choxos/Documents/GitHub/new_maics/advmaic")

# Load packages
library(dplyr)
library(tidyr)
library(parallel)
library(sandwich)

# Source package functions
cat("Loading package functions...\n")
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Source simulation code
cat("Loading simulation code...\n")
source("inst/simulation/data_generation.R")
source("inst/simulation/config.R")

# =============================================================================
# FULL SIMULATION PARAMETERS
# =============================================================================

N_ITERATIONS <- 1000
N_CORES <- parallel::detectCores() - 1

# All methods to compare
ALL_METHODS <- c(
  "Bucher",      # Unadjusted
  "SigTotal",    # Standard MAIC (method of moments)
  "EbTotal",     # Entropy balancing
  "EbArm",       # Arm-separate entropy balancing
  "EbEL"         # Empirical likelihood
)

cat("\n========================================\n")
cat("FULL SIMULATION STUDY\n")
cat("========================================\n\n")

# Generate all scenarios
all_scenarios <- generate_scenario_grid()

cat("Total scenarios:", nrow(all_scenarios), "\n")
cat("Methods:", length(ALL_METHODS), "\n")
cat("Iterations per scenario-method:", N_ITERATIONS, "\n")
cat("Total runs:", nrow(all_scenarios) * length(ALL_METHODS) * N_ITERATIONS, "\n")
cat("Using", N_CORES, "cores\n\n")

# =============================================================================
# SIMULATION FUNCTION
# =============================================================================

run_iteration <- function(scenario_params, method_name, iteration, seed) {
  set.seed(seed)

  tryCatch({
    # Generate data
    data <- do.call(generate_maic_scenario, scenario_params)
    covariates <- paste0("X", 1:scenario_params$n_covariates)

    ipd <- data$AB_ipd
    agd_target <- data$AC_agd[covariates]

    start_time <- Sys.time()

    # Run method
    if (method_name == "Bucher") {
      trt <- ipd$treatment == 1
      ctrl <- ipd$treatment == 0

      p_trt <- max(min(mean(ipd$outcome[trt]), 0.999), 0.001)
      p_ctrl <- max(min(mean(ipd$outcome[ctrl]), 0.999), 0.001)

      d_AB <- log((p_trt / (1 - p_trt)) / (p_ctrl / (1 - p_ctrl)))

      n_trt <- sum(trt)
      n_ctrl <- sum(ctrl)
      var_AB <- 1/(p_trt * n_trt) + 1/((1-p_trt) * n_trt) +
                1/(p_ctrl * n_ctrl) + 1/((1-p_ctrl) * n_ctrl)

      ess <- nrow(ipd)
      converged <- TRUE

    } else if (method_name %in% c("SigTotal", "EbTotal")) {
      method <- if (method_name == "SigTotal") "moments" else "entropy"

      weights <- estimate_weights(
        ipd = ipd,
        agd_target = agd_target,
        covariates = covariates,
        method = method
      )

      w <- weights$weights * nrow(ipd)
      fit <- glm(outcome ~ treatment, data = ipd, family = binomial(), weights = w)
      d_AB <- coef(fit)["treatment"]
      var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]

      ess <- weights$ess
      converged <- weights$convergence$converged

    } else if (method_name == "EbArm") {
      arm_agd <- generate_arm_specific_agd(data$AC_ipd, covariates, "treatment")

      weights <- eb_arm_separate(
        ipd = ipd,
        agd_target = arm_agd,
        covariates = covariates,
        arm_var = "treatment",
        treatment_value = 1,
        control_value = 0
      )

      w <- weights$weights * nrow(ipd)
      fit <- glm(outcome ~ treatment, data = ipd, family = binomial(), weights = w)
      d_AB <- coef(fit)["treatment"]
      var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]

      ess <- weights$ess
      converged <- weights$convergence$converged

    } else if (method_name == "EbEL") {
      weights <- estimate_weights(
        ipd = ipd,
        agd_target = agd_target,
        covariates = covariates,
        method = "entropy",
        loss_function = "empirical_likelihood"
      )

      w <- weights$weights * nrow(ipd)
      fit <- glm(outcome ~ treatment, data = ipd, family = binomial(), weights = w)
      d_AB <- coef(fit)["treatment"]
      var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]

      ess <- weights$ess
      converged <- weights$convergence$converged
    }

    compute_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

    d_BC <- d_AB - data$d_AC
    se_BC <- sqrt(var_AB + data$var_d_AC)

    list(
      success = TRUE,
      estimate = as.numeric(d_BC),
      se = as.numeric(se_BC),
      ci_lower = as.numeric(d_BC - 1.96 * se_BC),
      ci_upper = as.numeric(d_BC + 1.96 * se_BC),
      ess = ess,
      converged = converged,
      compute_time = compute_time,
      true_value = scenario_params$treatment_effect_AB - scenario_params$treatment_effect_AC
    )

  }, error = function(e) {
    list(
      success = FALSE,
      estimate = NA, se = NA, ci_lower = NA, ci_upper = NA,
      ess = NA, converged = FALSE, compute_time = NA, true_value = NA,
      error = conditionMessage(e)
    )
  })
}

# =============================================================================
# RUN SIMULATION
# =============================================================================

output_dir <- "inst/simulation/results"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

all_results <- list()
start_time <- Sys.time()

for (s in 1:nrow(all_scenarios)) {
  scenario_row <- all_scenarios[s, ]
  scenario_params <- get_scenario_params(scenario_row)

  cat(sprintf("\n[%s] Scenario %d/%d: %s (n=%d, p=%d, overlap=%s, EM=%s)\n",
              format(Sys.time(), "%H:%M:%S"),
              s, nrow(all_scenarios), scenario_row$scenario_id,
              scenario_row$n_AB, scenario_row$n_covariates,
              scenario_row$population_overlap, scenario_row$effect_modifiers))

  for (method_name in ALL_METHODS) {
    cat(sprintf("  %s: ", method_name))
    flush.console()

    # Generate seeds
    seeds <- 20260117 * s + 1:N_ITERATIONS

    # Run iterations (parallel)
    if (N_CORES > 1) {
      results <- mclapply(1:N_ITERATIONS, function(i) {
        run_iteration(scenario_params, method_name, i, seeds[i])
      }, mc.cores = N_CORES)
    } else {
      results <- lapply(1:N_ITERATIONS, function(i) {
        run_iteration(scenario_params, method_name, i, seeds[i])
      })
    }

    # Convert to data frame
    results_df <- do.call(rbind, lapply(seq_along(results), function(i) {
      r <- results[[i]]
      data.frame(
        scenario_id = scenario_row$scenario_id,
        n_AB = scenario_row$n_AB,
        n_covariates = scenario_row$n_covariates,
        population_overlap = scenario_row$population_overlap,
        effect_modifiers = scenario_row$effect_modifiers,
        method = method_name,
        iteration = i,
        estimate = r$estimate,
        se = r$se,
        ci_lower = r$ci_lower,
        ci_upper = r$ci_upper,
        ess = r$ess,
        converged = r$converged,
        compute_time = r$compute_time,
        success = r$success,
        true_value = r$true_value,
        stringsAsFactors = FALSE
      )
    }))

    all_results[[paste(scenario_row$scenario_id, method_name, sep = "_")]] <- results_df

    # Summary stats
    succ <- mean(results_df$success, na.rm = TRUE)
    bias <- mean(results_df$estimate - results_df$true_value, na.rm = TRUE)
    cat(sprintf("done (%.0f%% success, bias=%.3f)\n", 100*succ, bias))
  }

  # Save checkpoint every 10 scenarios
  if (s %% 10 == 0) {
    checkpoint <- do.call(rbind, all_results)
    saveRDS(checkpoint, file.path(output_dir, sprintf("checkpoint_s%03d.rds", s)))
    cat(sprintf("  [Checkpoint saved: %d scenarios]\n", s))
  }
}

# Combine and save final results
final_results <- do.call(rbind, all_results)
saveRDS(final_results, file.path(output_dir, "simulation_results.rds"))

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "hours")

cat(sprintf("\n\n========================================\n"))
cat(sprintf("SIMULATION COMPLETE\n"))
cat(sprintf("========================================\n"))
cat(sprintf("Total time: %.2f hours\n", as.numeric(elapsed)))
cat(sprintf("Results saved to: %s/simulation_results.rds\n", output_dir))

# =============================================================================
# CALCULATE FINAL METRICS
# =============================================================================

cat("\n\nCalculating performance metrics...\n")

metrics <- final_results %>%
  filter(success == TRUE) %>%
  group_by(scenario_id, method, n_AB, n_covariates, population_overlap, effect_modifiers) %>%
  summarise(
    n_success = n(),
    true_value = first(true_value),
    bias = mean(estimate, na.rm = TRUE) - first(true_value),
    empirical_se = sd(estimate, na.rm = TRUE),
    model_se = mean(se, na.rm = TRUE),
    rmse = sqrt(mean((estimate - first(true_value))^2, na.rm = TRUE)),
    coverage = mean(ci_lower <= first(true_value) & ci_upper >= first(true_value), na.rm = TRUE),
    ess_mean = mean(ess, na.rm = TRUE),
    ess_median = median(ess, na.rm = TRUE),
    convergence_rate = mean(converged, na.rm = TRUE),
    mean_time = mean(compute_time, na.rm = TRUE),
    .groups = "drop"
  )

saveRDS(metrics, file.path(output_dir, "performance_metrics.rds"))

# Summary table
cat("\n========================================\n")
cat("OVERALL RESULTS BY METHOD\n")
cat("========================================\n\n")

method_summary <- metrics %>%
  group_by(method) %>%
  summarise(
    `Mean Bias` = round(mean(bias, na.rm = TRUE), 4),
    `Mean RMSE` = round(mean(rmse, na.rm = TRUE), 4),
    `Mean Coverage` = round(mean(coverage, na.rm = TRUE), 3),
    `Mean ESS` = round(mean(ess_mean, na.rm = TRUE), 1),
    `Conv Rate` = round(mean(convergence_rate, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  arrange(`Mean RMSE`)

print(as.data.frame(method_summary), row.names = FALSE)

saveRDS(method_summary, file.path(output_dir, "method_summary.rds"))

cat("\n\nAll results saved to:", output_dir, "\n")
