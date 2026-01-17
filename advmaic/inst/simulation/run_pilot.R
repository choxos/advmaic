#!/usr/bin/env Rscript
#' Pilot Simulation Script
#' Tests the simulation framework with a small-scale run

# Set working directory
setwd("/Users/choxos/Documents/GitHub/new_maics/advmaic")

# Install package dependencies if needed
required_pkgs <- c("dplyr", "tidyr", "ggplot2", "boot", "sandwich",
                   "survival", "nloptr", "matrixStats", "cli", "tibble", "rlang")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

# Source package functions directly (without installing)
cat("Loading package functions...\n")
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Source simulation code
cat("Loading simulation code...\n")
source("inst/simulation/data_generation.R")
source("inst/simulation/config.R")

# =============================================================================
# PILOT SIMULATION
# =============================================================================

cat("\n========================================\n")
cat("PILOT SIMULATION\n")
cat("========================================\n\n")

# Pilot parameters
N_PILOT_ITER <- 100
PILOT_SCENARIOS <- 3
PILOT_METHODS <- c("Bucher", "SigTotal", "EbTotal", "EbArm")

set.seed(20260117)

# Generate scenario grid
all_scenarios <- generate_scenario_grid()
pilot_scenarios <- all_scenarios[1:PILOT_SCENARIOS, ]

cat("Scenarios:", PILOT_SCENARIOS, "\n")
cat("Methods:", length(PILOT_METHODS), "\n")
cat("Iterations per scenario-method:", N_PILOT_ITER, "\n")
cat("Total runs:", PILOT_SCENARIOS * length(PILOT_METHODS) * N_PILOT_ITER, "\n\n")

# Initialize results storage
all_results <- list()

# Single iteration function
run_single_iteration <- function(scenario_params, method_name, iteration, seed) {
  set.seed(seed)

  tryCatch({
    # Generate data
    data <- do.call(generate_maic_scenario, scenario_params)
    covariates <- paste0("X", 1:scenario_params$n_covariates)

    ipd <- data$AB_ipd
    agd_target <- data$AC_agd[covariates]

    # Run method
    if (method_name == "Bucher") {
      # Unadjusted
      trt <- ipd$treatment == 1
      ctrl <- ipd$treatment == 0

      p_trt <- mean(ipd$outcome[trt])
      p_ctrl <- mean(ipd$outcome[ctrl])

      # Avoid log(0)
      p_trt <- max(min(p_trt, 0.999), 0.001)
      p_ctrl <- max(min(p_ctrl, 0.999), 0.001)

      d_AB <- log((p_trt / (1 - p_trt)) / (p_ctrl / (1 - p_ctrl)))

      n_trt <- sum(trt)
      n_ctrl <- sum(ctrl)
      var_AB <- 1/(p_trt * n_trt) + 1/((1-p_trt) * n_trt) +
                1/(p_ctrl * n_ctrl) + 1/((1-p_ctrl) * n_ctrl)

      ess <- nrow(ipd)
      converged <- TRUE

    } else if (method_name %in% c("SigTotal", "EbTotal")) {
      # Standard MAIC
      method <- if (method_name == "SigTotal") "moments" else "entropy"

      weights <- estimate_weights(
        ipd = ipd,
        agd_target = agd_target,
        covariates = covariates,
        method = method
      )

      w <- weights$weights * nrow(ipd)

      # Weighted logistic regression
      fit <- glm(outcome ~ treatment, data = ipd, family = binomial(), weights = w)
      d_AB <- coef(fit)["treatment"]
      var_AB <- sandwich::vcovHC(fit, type = "HC1")["treatment", "treatment"]

      ess <- weights$ess
      converged <- weights$convergence$converged

    } else if (method_name == "EbArm") {
      # Arm-separate
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
    }

    # Indirect comparison
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
      true_value = scenario_params$treatment_effect_AB - scenario_params$treatment_effect_AC
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
      true_value = NA,
      error = conditionMessage(e)
    )
  })
}

# Run pilot simulation
start_time <- Sys.time()

for (s in 1:nrow(pilot_scenarios)) {
  scenario_row <- pilot_scenarios[s, ]
  scenario_params <- get_scenario_params(scenario_row)

  cat(sprintf("Scenario %d/%d: %s (n=%d, p=%d, overlap=%s)\n",
              s, nrow(pilot_scenarios), scenario_row$scenario_id,
              scenario_row$n_AB, scenario_row$n_covariates,
              scenario_row$population_overlap))

  for (method_name in PILOT_METHODS) {
    cat(sprintf("  Method: %s ", method_name))

    results <- lapply(1:N_PILOT_ITER, function(i) {
      seed <- 20260117 + (s - 1) * 10000 + i
      run_single_iteration(scenario_params, method_name, i, seed)
    })

    # Convert to data frame
    results_df <- do.call(rbind, lapply(seq_along(results), function(i) {
      r <- results[[i]]
      data.frame(
        scenario_id = scenario_row$scenario_id,
        n_AB = scenario_row$n_AB,
        n_covariates = scenario_row$n_covariates,
        population_overlap = scenario_row$population_overlap,
        method = method_name,
        iteration = i,
        estimate = r$estimate,
        se = r$se,
        ci_lower = r$ci_lower,
        ci_upper = r$ci_upper,
        ess = r$ess,
        converged = r$converged,
        success = r$success,
        true_value = r$true_value,
        stringsAsFactors = FALSE
      )
    }))

    all_results[[paste(scenario_row$scenario_id, method_name, sep = "_")]] <- results_df

    # Quick summary
    success_rate <- mean(results_df$success, na.rm = TRUE)
    mean_bias <- mean(results_df$estimate - results_df$true_value, na.rm = TRUE)
    cat(sprintf("(success: %.0f%%, bias: %.3f)\n", 100*success_rate, mean_bias))
  }
}

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "mins")

# Combine all results
pilot_results <- do.call(rbind, all_results)

cat(sprintf("\n\nPilot completed in %.1f minutes\n", as.numeric(elapsed)))

# =============================================================================
# CALCULATE METRICS
# =============================================================================

cat("\n========================================\n")
cat("PILOT RESULTS SUMMARY\n")
cat("========================================\n\n")

metrics <- pilot_results %>%
  filter(success == TRUE) %>%
  group_by(scenario_id, method) %>%
  summarise(
    n_success = n(),
    true_value = first(true_value),
    bias = mean(estimate, na.rm = TRUE) - first(true_value),
    empirical_se = sd(estimate, na.rm = TRUE),
    model_se = mean(se, na.rm = TRUE),
    rmse = sqrt(mean((estimate - first(true_value))^2, na.rm = TRUE)),
    coverage = mean(ci_lower <= first(true_value) & ci_upper >= first(true_value), na.rm = TRUE),
    ess_mean = mean(ess, na.rm = TRUE),
    .groups = "drop"
  )

# Summary by method
method_summary <- metrics %>%
  group_by(method) %>%
  summarise(
    `Mean Bias` = mean(bias),
    `Mean RMSE` = mean(rmse),
    `Mean Coverage` = mean(coverage),
    `Mean ESS` = mean(ess_mean),
    .groups = "drop"
  ) %>%
  arrange(`Mean RMSE`)

cat("Performance by Method:\n")
print(as.data.frame(method_summary), digits = 3, row.names = FALSE)

# Save results
output_dir <- "inst/simulation/results"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

saveRDS(pilot_results, file.path(output_dir, "pilot_results.rds"))
saveRDS(metrics, file.path(output_dir, "pilot_metrics.rds"))

cat(sprintf("\nResults saved to %s/\n", output_dir))

cat("\n========================================\n")
cat("PILOT SIMULATION COMPLETE\n")
cat("========================================\n")
