#' Simulation Results Analysis
#'
#' Functions for analyzing and visualizing simulation study results.

library(dplyr)
library(tidyr)
library(ggplot2)
library(knitr)
library(kableExtra)

source(here::here("inst/simulation/config.R"))

# =============================================================================
# PERFORMANCE METRICS CALCULATION
# =============================================================================

#' Calculate performance metrics for simulation results
#'
#' @param results Data frame of simulation results
#' @param group_vars Variables to group by (e.g., c("scenario_id", "method"))
#'
#' @return Data frame with performance metrics
calculate_performance_metrics <- function(results, group_vars = c("scenario_id", "method")) {

  results %>%
    filter(success == TRUE) %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      # Number of successful iterations
      n_success = n(),
      n_total = n() + sum(!success, na.rm = TRUE),

      # True value (should be same for all iterations in a scenario)
      true_value = first(true_value),

      # Bias
      bias = mean(estimate, na.rm = TRUE) - first(true_value),
      bias_pct = 100 * bias / abs(first(true_value)),

      # Empirical standard error
      empirical_se = sd(estimate, na.rm = TRUE),

      # Mean model-based SE
      model_se = mean(se, na.rm = TRUE),

      # SE ratio (should be ~1 if model SE is well calibrated)
      se_ratio = model_se / empirical_se,

      # Mean squared error
      mse = mean((estimate - first(true_value))^2, na.rm = TRUE),

      # Root MSE
      rmse = sqrt(mse),

      # Coverage probability
      coverage = mean(ci_lower <= first(true_value) & ci_upper >= first(true_value), na.rm = TRUE),
      coverage_pct = 100 * coverage,

      # Effective sample size
      ess_mean = mean(ess, na.rm = TRUE),
      ess_median = median(ess, na.rm = TRUE),
      ess_min = min(ess, na.rm = TRUE),
      ess_max = max(ess, na.rm = TRUE),

      # Convergence rate
      convergence_rate = mean(converged, na.rm = TRUE),
      convergence_pct = 100 * convergence_rate,

      # Computation time
      time_mean = mean(compute_time, na.rm = TRUE),
      time_median = median(compute_time, na.rm = TRUE),

      .groups = "drop"
    )
}

#' Calculate metrics by scenario characteristics
#'
#' @param results Raw simulation results
#' @param scenarios Scenario grid data frame
#'
#' @return Data frame with metrics including scenario characteristics
calculate_metrics_with_scenarios <- function(results, scenarios = NULL) {

  if (is.null(scenarios)) {
    scenarios <- generate_scenario_grid()
  }

  metrics <- calculate_performance_metrics(results)

  # Join with scenario characteristics
  metrics %>%
    left_join(scenarios, by = "scenario_id")
}

# =============================================================================
# SUMMARY TABLES
# =============================================================================

#' Create main results table
#'
#' @param metrics Performance metrics data frame
#' @param digits Number of decimal places
#'
#' @return Formatted table
create_main_results_table <- function(metrics, digits = 3) {

  summary_table <- metrics %>%
    group_by(method) %>%
    summarise(
      `Mean Bias` = mean(bias, na.rm = TRUE),
      `Mean RMSE` = mean(rmse, na.rm = TRUE),
      `Mean Coverage (%)` = mean(coverage_pct, na.rm = TRUE),
      `Mean ESS` = mean(ess_mean, na.rm = TRUE),
      `Convergence (%)` = mean(convergence_pct, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(`Mean RMSE`)

  # Format
  summary_table %>%
    mutate(across(where(is.numeric), ~round(., digits))) %>%
    kable(
      caption = "Summary of Performance Metrics Across All Scenarios",
      booktabs = TRUE,
      format = "latex"
    ) %>%
    kable_styling(latex_options = c("striped", "hold_position"))
}

#' Create results table by scenario type
#'
#' @param metrics Metrics with scenario characteristics
#' @param by_var Variable to stratify by (e.g., "population_overlap")
#'
#' @return Formatted table
create_stratified_table <- function(metrics, by_var = "population_overlap") {

  metrics %>%
    group_by(method, .data[[by_var]]) %>%
    summarise(
      Bias = mean(bias, na.rm = TRUE),
      RMSE = mean(rmse, na.rm = TRUE),
      `Coverage (%)` = mean(coverage_pct, na.rm = TRUE),
      ESS = mean(ess_mean, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    pivot_wider(
      names_from = all_of(by_var),
      values_from = c(Bias, RMSE, `Coverage (%)`, ESS),
      names_glue = "{.value}_{.name}"
    ) %>%
    kable(
      caption = sprintf("Performance Metrics by %s", by_var),
      booktabs = TRUE,
      digits = 3
    )
}

# =============================================================================
# VISUALIZATION FUNCTIONS
# =============================================================================

#' Plot bias by method
#'
#' @param metrics Performance metrics
#' @param facet_var Optional faceting variable
#'
#' @return ggplot object
plot_bias_comparison <- function(metrics, facet_var = NULL) {

  p <- ggplot(metrics, aes(x = reorder(method, bias), y = bias, fill = method)) +
    geom_boxplot(alpha = 0.7) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
    coord_flip() +
    labs(
      title = "Bias by Method",
      x = "Method",
      y = "Bias",
      fill = "Method"
    ) +
    theme_minimal() +
    theme(legend.position = "none")

  if (!is.null(facet_var)) {
    p <- p + facet_wrap(as.formula(paste("~", facet_var)))
  }

  p
}

#' Plot RMSE comparison
#'
#' @param metrics Performance metrics
#' @param facet_var Optional faceting variable
#'
#' @return ggplot object
plot_rmse_comparison <- function(metrics, facet_var = NULL) {

  p <- ggplot(metrics, aes(x = reorder(method, rmse), y = rmse, fill = method)) +
    geom_boxplot(alpha = 0.7) +
    coord_flip() +
    labs(
      title = "Root Mean Squared Error by Method",
      x = "Method",
      y = "RMSE",
      fill = "Method"
    ) +
    theme_minimal() +
    theme(legend.position = "none")

  if (!is.null(facet_var)) {
    p <- p + facet_wrap(as.formula(paste("~", facet_var)))
  }

  p
}

#' Plot coverage probability
#'
#' @param metrics Performance metrics
#'
#' @return ggplot object
plot_coverage <- function(metrics) {

  ggplot(metrics, aes(x = reorder(method, coverage_pct), y = coverage_pct, fill = method)) +
    geom_boxplot(alpha = 0.7) +
    geom_hline(yintercept = 95, linetype = "dashed", color = "red") +
    coord_flip() +
    labs(
      title = "95% CI Coverage Probability",
      x = "Method",
      y = "Coverage (%)",
      fill = "Method"
    ) +
    theme_minimal() +
    theme(legend.position = "none") +
    scale_y_continuous(limits = c(80, 100))
}

#' Plot ESS comparison
#'
#' @param metrics Performance metrics
#'
#' @return ggplot object
plot_ess_comparison <- function(metrics) {

  ggplot(metrics, aes(x = reorder(method, ess_mean), y = ess_mean, fill = method)) +
    geom_boxplot(alpha = 0.7) +
    coord_flip() +
    labs(
      title = "Effective Sample Size",
      x = "Method",
      y = "Mean ESS",
      fill = "Method"
    ) +
    theme_minimal() +
    theme(legend.position = "none")
}

#' Plot bias vs ESS tradeoff
#'
#' @param metrics Performance metrics
#'
#' @return ggplot object
plot_bias_ess_tradeoff <- function(metrics) {

  method_summary <- metrics %>%
    group_by(method) %>%
    summarise(
      mean_bias = mean(abs(bias), na.rm = TRUE),
      mean_ess = mean(ess_mean, na.rm = TRUE),
      .groups = "drop"
    )

  ggplot(method_summary, aes(x = mean_ess, y = mean_bias, color = method, label = method)) +
    geom_point(size = 4) +
    geom_text(hjust = -0.1, vjust = 0.5, size = 3) +
    labs(
      title = "Bias-ESS Tradeoff",
      x = "Mean Effective Sample Size",
      y = "Mean Absolute Bias"
    ) +
    theme_minimal() +
    theme(legend.position = "none")
}

#' Create comprehensive results figure
#'
#' @param metrics Performance metrics
#'
#' @return Combined ggplot
create_results_figure <- function(metrics) {

  p1 <- plot_bias_comparison(metrics) + ggtitle("A. Bias")
  p2 <- plot_rmse_comparison(metrics) + ggtitle("B. RMSE")
  p3 <- plot_coverage(metrics) + ggtitle("C. Coverage")
  p4 <- plot_ess_comparison(metrics) + ggtitle("D. ESS")

  if (requireNamespace("patchwork", quietly = TRUE)) {
    library(patchwork)
    (p1 | p2) / (p3 | p4)
  } else {
    # Return as list
    list(bias = p1, rmse = p2, coverage = p3, ess = p4)
  }
}

# =============================================================================
# REPORTING FUNCTIONS
# =============================================================================

#' Generate LaTeX results table
#'
#' @param metrics Performance metrics
#' @param filename Output filename
generate_latex_table <- function(metrics, filename = "results_table.tex") {

  summary <- metrics %>%
    group_by(method) %>%
    summarise(
      Bias = sprintf("%.3f", mean(bias, na.rm = TRUE)),
      RMSE = sprintf("%.3f", mean(rmse, na.rm = TRUE)),
      `Coverage` = sprintf("%.1f", mean(coverage_pct, na.rm = TRUE)),
      ESS = sprintf("%.1f", mean(ess_mean, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    arrange(as.numeric(RMSE))

  cat("\\begin{table}[htbp]\n", file = filename)
  cat("\\centering\n", file = filename, append = TRUE)
  cat("\\caption{Simulation Results Summary}\n", file = filename, append = TRUE)
  cat("\\begin{tabular}{lrrrr}\n", file = filename, append = TRUE)
  cat("\\toprule\n", file = filename, append = TRUE)
  cat("Method & Bias & RMSE & Coverage (\\%) & ESS \\\\\n", file = filename, append = TRUE)
  cat("\\midrule\n", file = filename, append = TRUE)

  for (i in 1:nrow(summary)) {
    cat(sprintf("%s & %s & %s & %s & %s \\\\\n",
                summary$method[i], summary$Bias[i], summary$RMSE[i],
                summary$Coverage[i], summary$ESS[i]),
        file = filename, append = TRUE)
  }

  cat("\\bottomrule\n", file = filename, append = TRUE)
  cat("\\end{tabular}\n", file = filename, append = TRUE)
  cat("\\end{table}\n", file = filename, append = TRUE)

  cat("Table saved to:", filename, "\n")
}

#' Generate full analysis report
#'
#' @param results_file Path to RDS file with results
#' @param output_dir Output directory for figures and tables
analyze_simulation_results <- function(results_file, output_dir = "results") {

  # Load results
  results <- readRDS(results_file)

  # Calculate metrics
  scenarios <- generate_scenario_grid()
  metrics <- calculate_metrics_with_scenarios(results, scenarios)

  # Create output directory
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # Generate tables
  cat("Generating summary tables...\n")
  generate_latex_table(metrics, file.path(output_dir, "table_main.tex"))

  # Generate figures
  cat("Generating figures...\n")
  ggsave(file.path(output_dir, "fig_bias.pdf"),
         plot_bias_comparison(metrics), width = 8, height = 6)
  ggsave(file.path(output_dir, "fig_rmse.pdf"),
         plot_rmse_comparison(metrics), width = 8, height = 6)
  ggsave(file.path(output_dir, "fig_coverage.pdf"),
         plot_coverage(metrics), width = 8, height = 6)
  ggsave(file.path(output_dir, "fig_ess.pdf"),
         plot_ess_comparison(metrics), width = 8, height = 6)
  ggsave(file.path(output_dir, "fig_tradeoff.pdf"),
         plot_bias_ess_tradeoff(metrics), width = 8, height = 6)

  # Save metrics
  saveRDS(metrics, file.path(output_dir, "performance_metrics.rds"))

  cat("\nAnalysis complete. Files saved to:", output_dir, "\n")

  # Return metrics for further analysis
  invisible(metrics)
}

# =============================================================================
# RUN ANALYSIS (if executed directly)
# =============================================================================

if (sys.nframe() == 0) {
  results_file <- file.path(SIM_CONFIG$output_dir, "simulation_results.rds")

  if (file.exists(results_file)) {
    metrics <- analyze_simulation_results(results_file)
    print(create_main_results_table(metrics))
  } else {
    cat("No results file found. Run simulation first.\n")
  }
}
