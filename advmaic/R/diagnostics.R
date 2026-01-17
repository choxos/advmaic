#' @title Diagnostic Functions for MAIC
#' @name diagnostics
#' @description Functions for assessing weight quality and covariate balance
#'   in MAIC analyses.
NULL

#' Calculate Effective Sample Size
#'
#' Computes the effective sample size (ESS) of a weighted sample. ESS measures
#' the information loss due to weighting and is a key diagnostic for MAIC.
#'
#' @param weights Numeric vector of weights.
#'
#' @return Numeric value of the effective sample size.
#'
#' @details
#' The effective sample size is calculated as:
#' \deqn{ESS = \frac{(\sum_i w_i)^2}{\sum_i w_i^2}}
#'
#' For uniform weights, ESS equals the actual sample size. As weights become
#' more variable, ESS decreases. A very low ESS relative to the original
#' sample size indicates potential issues with the MAIC analysis.
#'
#' Rules of thumb:
#' \itemize{
#'   \item ESS > 50% of n: Generally acceptable
#'   \item ESS 30-50% of n: Caution warranted
#'   \item ESS < 30% of n: Consider whether MAIC is appropriate
#' }
#'
#' @references
#' Kish L. (1965). Survey Sampling. Wiley.
#'
#' @examples
#' # Uniform weights: ESS = n
#' w_uniform <- rep(1, 100)
#' calculate_ess(w_uniform)  # 100
#'
#' # Variable weights: ESS < n
#' w_variable <- c(rep(1, 50), rep(5, 50))
#' calculate_ess(w_variable)  # Less than 100
#'
#' @export
calculate_ess <- function(weights) {
  if (length(weights) == 0) {
    return(0)
  }

  # Remove any zero weights
  w <- weights[weights > 0]

  if (length(w) == 0) {
    return(0)
  }

  sum(w)^2 / sum(w^2)
}

#' Weight Summary Statistics
#'
#' Provides a comprehensive summary of weight distribution and quality metrics.
#'
#' @param weights Numeric vector of weights (or advmaic_weights object).
#'
#' @return A list containing weight summary statistics.
#'
#' @details
#' The summary includes:
#' \itemize{
#'   \item Basic statistics (min, max, mean, median, sd)
#'   \item Percentiles (1%, 5%, 25%, 75%, 95%, 99%)
#'   \item Quality metrics (ESS, ESS percentage, coefficient of variation)
#'   \item Extreme weight indicators
#' }
#'
#' @examples
#' \dontrun{
#' weights <- estimate_weights(ipd, agd_target, covariates)
#' weight_summary(weights)
#' }
#'
#' @export
weight_summary <- function(weights) {

  # Handle advmaic_weights objects
  if (inherits(weights, "advmaic_weights")) {
    w <- weights$weights
    n <- weights$n
    ess <- weights$ess
  } else {
    w <- weights
    n <- length(w)
    ess <- calculate_ess(w)
  }

  # Normalize weights
  w_norm <- w / sum(w)
  w_rescaled <- w_norm * n

  # Calculate statistics
  stats <- list(
    n = n,
    ess = ess,
    ess_pct = 100 * ess / n,

    # Distribution of rescaled weights
    min = min(w_rescaled),
    max = max(w_rescaled),
    mean = mean(w_rescaled),
    median = stats::median(w_rescaled),
    sd = stats::sd(w_rescaled),
    cv = stats::sd(w_rescaled) / mean(w_rescaled),

    # Percentiles
    p01 = stats::quantile(w_rescaled, 0.01),
    p05 = stats::quantile(w_rescaled, 0.05),
    p25 = stats::quantile(w_rescaled, 0.25),
    p75 = stats::quantile(w_rescaled, 0.75),
    p95 = stats::quantile(w_rescaled, 0.95),
    p99 = stats::quantile(w_rescaled, 0.99),

    # Extreme weights
    n_zero = sum(w <= 0),
    n_extreme_low = sum(w_rescaled < 0.1),
    n_extreme_high = sum(w_rescaled > 10),
    max_weight_multiple = max(w_rescaled)
  )

  class(stats) <- "advmaic_weight_summary"
  stats
}

#' Check Covariate Balance
#'
#' Assesses how well the weighted IPD matches the aggregate data targets.
#'
#' @param ipd Data frame containing individual patient data.
#' @param agd_target Named numeric vector of target moments.
#' @param weights Numeric vector of weights (or advmaic_weights object).
#' @param covariates Character vector of covariate names to check. If NULL,
#'   uses all names from agd_target.
#'
#' @return An object of class "advmaic_balance" containing balance diagnostics.
#'
#' @details
#' For each covariate, the function calculates:
#' \itemize{
#'   \item Unweighted mean in IPD
#'   \item Weighted mean in IPD
#'   \item Target mean from AgD
#'   \item Absolute difference between weighted mean and target
#'   \item Standardized mean difference (SMD)
#' }
#'
#' Good balance is typically indicated by:
#' \itemize{
#'   \item Absolute difference close to 0
#'   \item SMD < 0.1 (excellent) or < 0.25 (acceptable)
#' }
#'
#' @examples
#' \dontrun{
#' weights <- estimate_weights(ipd, agd_target, covariates)
#' balance <- check_balance(ipd, agd_target, weights, covariates)
#' print(balance)
#' }
#'
#' @export
check_balance <- function(ipd, agd_target, weights, covariates = NULL) {

  # Handle advmaic_weights objects
  if (inherits(weights, "advmaic_weights")) {
    w <- weights$weights
    if (is.null(covariates)) {
      covariates <- weights$covariates
    }
  } else {
    w <- weights
  }

  if (is.null(covariates)) {
    covariates <- names(agd_target)
  }

  # Filter to covariates that don't end with _var (those are variances)
  mean_covariates <- covariates[!grepl("_var$", covariates)]

  # Calculate balance metrics for each covariate
  balance_df <- lapply(mean_covariates, function(cov) {
    x <- ipd[[cov]]

    # Unweighted statistics
    mean_unweighted <- mean(x)
    sd_unweighted <- stats::sd(x)

    # Weighted statistics
    mean_weighted <- wmean(x, w)

    # Target
    target <- agd_target[cov]

    # Differences
    abs_diff <- abs(mean_weighted - target)
    smd <- (mean_weighted - target) / sd_unweighted

    data.frame(
      covariate = cov,
      mean_unweighted = mean_unweighted,
      mean_weighted = mean_weighted,
      target = target,
      abs_diff = abs_diff,
      smd = smd,
      stringsAsFactors = FALSE
    )
  })

  balance_df <- do.call(rbind, balance_df)
  rownames(balance_df) <- NULL

  # Check variance balance if variance targets provided
  var_covariates <- covariates[grepl("_var$", covariates)]
  if (length(var_covariates) > 0) {
    var_balance <- lapply(var_covariates, function(var_cov) {
      base_cov <- sub("_var$", "", var_cov)
      if (base_cov %in% names(ipd)) {
        x <- ipd[[base_cov]]
        var_weighted <- wvar(x, w)
        target_var <- agd_target[var_cov]
        data.frame(
          covariate = var_cov,
          var_weighted = var_weighted,
          target = target_var,
          abs_diff = abs(var_weighted - target_var),
          stringsAsFactors = FALSE
        )
      } else {
        NULL
      }
    })
    var_balance <- do.call(rbind, var_balance[!sapply(var_balance, is.null)])
  } else {
    var_balance <- NULL
  }

  result <- list(
    means = balance_df,
    variances = var_balance,
    max_smd = max(abs(balance_df$smd)),
    all_balanced = all(abs(balance_df$smd) < 0.001)
  )

  class(result) <- "advmaic_balance"
  result
}

#' Print method for advmaic_balance
#' @param x advmaic_balance object
#' @param digits Number of digits to print
#' @param ... Additional arguments (ignored)
#' @return Invisible x
#' @export
print.advmaic_balance <- function(x, digits = 4, ...) {
  cat("\n=== Covariate Balance Check ===\n\n")

  # Print mean balance
  cat("Mean Balance:\n")
  df <- x$means
  df$mean_unweighted <- round(df$mean_unweighted, digits)
  df$mean_weighted <- round(df$mean_weighted, digits)
  df$target <- round(df$target, digits)
  df$abs_diff <- format(df$abs_diff, digits = digits, scientific = TRUE)
  df$smd <- round(df$smd, digits)
  print(df, row.names = FALSE)

  cat("\n")

  # Print variance balance if available
  if (!is.null(x$variances) && nrow(x$variances) > 0) {
    cat("Variance Balance:\n")
    var_df <- x$variances
    var_df$var_weighted <- round(var_df$var_weighted, digits)
    var_df$target <- round(var_df$target, digits)
    var_df$abs_diff <- format(var_df$abs_diff, digits = digits, scientific = TRUE)
    print(var_df, row.names = FALSE)
    cat("\n")
  }

  # Summary
  cat("Maximum absolute SMD:", round(x$max_smd, 6), "\n")
  if (x$all_balanced) {
    cli::cli_alert_success("All covariates balanced (|SMD| < 0.001)")
  } else if (x$max_smd < 0.1) {
    cli::cli_alert_success("Good balance achieved (max |SMD| < 0.1)")
  } else if (x$max_smd < 0.25) {
    cli::cli_alert_warning("Acceptable balance (max |SMD| < 0.25)")
  } else {
    cli::cli_alert_warning("Poor balance (max |SMD| >= 0.25)")
  }

  invisible(x)
}

#' Balance Table
#'
#' Creates a formatted balance table comparing unweighted and weighted IPD
#' with aggregate data targets.
#'
#' @param ipd Data frame containing individual patient data.
#' @param agd_target Named numeric vector of target moments.
#' @param weights Numeric vector of weights (or advmaic_weights object).
#' @param covariates Character vector of covariate names.
#' @param format Output format: "data.frame" or "gt" (if gt package available).
#'
#' @return A data frame or gt table with balance statistics.
#'
#' @export
balance_table <- function(ipd, agd_target, weights, covariates,
                          format = c("data.frame", "gt")) {

  format <- match.arg(format)

  balance <- check_balance(ipd, agd_target, weights, covariates)

  df <- balance$means
  names(df) <- c("Covariate", "IPD (unweighted)", "IPD (weighted)",
                 "AgD Target", "Abs. Diff", "SMD")

  if (format == "gt" && requireNamespace("gt", quietly = TRUE)) {
    gt::gt(df) |>
      gt::tab_header(
        title = "Covariate Balance Table",
        subtitle = "Comparison of IPD and AgD covariate distributions"
      ) |>
      gt::fmt_number(
        columns = c("IPD (unweighted)", "IPD (weighted)", "AgD Target"),
        decimals = 2
      ) |>
      gt::fmt_scientific(columns = "Abs. Diff", decimals = 2) |>
      gt::fmt_number(columns = "SMD", decimals = 4)
  } else {
    df
  }
}

#' Weight Distribution Plot
#'
#' Creates a visualization of the weight distribution.
#'
#' @param weights Numeric vector of weights (or advmaic_weights object).
#' @param type Type of plot: "histogram", "density", or "both".
#' @param rescale Logical. If TRUE, rescale weights so mean = 1.
#'
#' @return A ggplot2 object.
#'
#' @export
weight_distribution_plot <- function(weights,
                                     type = c("histogram", "density", "both"),
                                     rescale = TRUE) {

  type <- match.arg(type)

  # Handle advmaic_weights objects
  if (inherits(weights, "advmaic_weights")) {
    w <- weights$weights
    n <- weights$n
    ess <- weights$ess
  } else {
    w <- weights
    n <- length(w)
    ess <- calculate_ess(w)
  }

  # Rescale weights
  if (rescale) {
    w <- w / mean(w)
    x_label <- "Weight (relative to uniform)"
  } else {
    x_label <- "Weight"
  }

  df <- data.frame(weight = w)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$weight))

  if (type == "histogram" || type == "both") {
    p <- p + ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 30,
      fill = "steelblue",
      alpha = 0.7
    )
  }

  if (type == "density" || type == "both") {
    p <- p + ggplot2::geom_density(
      color = "darkblue",
      linewidth = 1
    )
  }

  p <- p +
    ggplot2::geom_vline(xintercept = 1, linetype = "dashed", color = "red") +
    ggplot2::labs(
      title = "MAIC Weight Distribution",
      subtitle = sprintf("n = %d, ESS = %.1f (%.1f%%)", n, ess, 100 * ess / n),
      x = x_label,
      y = "Density"
    ) +
    ggplot2::theme_minimal()

  p
}

#' Plot method for advmaic_weights
#' @param x advmaic_weights object
#' @param type Type of plot
#' @param ... Additional arguments passed to weight_distribution_plot
#' @return A ggplot2 object
#' @export
plot.advmaic_weights <- function(x, type = "both", ...) {
  weight_distribution_plot(x, type = type, ...)
}

#' Compare Weight Distributions Across Methods
#'
#' Creates a side-by-side comparison of weight distributions from different
#' weighting methods.
#'
#' @param ... Named advmaic_weights objects or numeric weight vectors to compare.
#' @param labels Character vector of labels for each set of weights. If NULL,
#'   uses names from ... or defaults to "Method 1", "Method 2", etc.
#'
#' @return A ggplot2 object with faceted weight distributions.
#'
#' @examples
#' \dontrun{
#' weights_eb <- estimate_weights(ipd, agd_target, covariates, method = "entropy")
#' weights_mm <- estimate_weights(ipd, agd_target, covariates, method = "moments")
#' compare_weight_distributions(EB = weights_eb, MM = weights_mm)
#' }
#'
#' @export
compare_weight_distributions <- function(..., labels = NULL) {

  weight_list <- list(...)

  if (is.null(labels)) {
    labels <- names(weight_list)
    if (is.null(labels) || any(labels == "")) {
      labels <- paste("Method", seq_along(weight_list))
    }
  }

  # Extract weights and create data frame
  df_list <- lapply(seq_along(weight_list), function(i) {
    w <- weight_list[[i]]
    if (inherits(w, "advmaic_weights")) {
      w <- w$weights
    }
    w <- w / mean(w)  # Rescale
    data.frame(
      weight = w,
      method = labels[i],
      ess = calculate_ess(weight_list[[i]]$weights %||% weight_list[[i]])
    )
  })

  df <- do.call(rbind, df_list)

  # Create faceted plot
  ggplot2::ggplot(df, ggplot2::aes(x = .data$weight)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 30,
      fill = "steelblue",
      alpha = 0.7
    ) +
    ggplot2::geom_density(color = "darkblue", linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = 1, linetype = "dashed", color = "red") +
    ggplot2::facet_wrap(~method, scales = "free_y") +
    ggplot2::labs(
      title = "Weight Distribution Comparison",
      x = "Weight (relative to uniform)",
      y = "Density"
    ) +
    ggplot2::theme_minimal()
}

#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x
