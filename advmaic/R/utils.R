#' @title Utility Functions for advmaic
#' @name utils
#' @description Internal utility functions for the advmaic package.
#' @keywords internal
NULL

#' Check if input is a valid numeric matrix
#' @param x Object to check
#' @param name Name for error message
#' @return Invisible TRUE if valid, otherwise throws error
#' @keywords internal
check_numeric_matrix <- function(x, name = "x") {
  if (!is.matrix(x) && !is.data.frame(x)) {
    cli::cli_abort("{name} must be a matrix or data frame")
  }
  if (!all(sapply(x, is.numeric))) {
    cli::cli_abort("{name} must contain only numeric values")
  }
  invisible(TRUE)
}

#' Check if target moments are valid
#' @param target Named numeric vector of target moments
#' @param covariates Character vector of covariate names
#' @return Invisible TRUE if valid, otherwise throws error
#' @keywords internal
check_target_moments <- function(target, covariates) {
  if (!is.numeric(target)) {
    cli::cli_abort("Target moments must be numeric")
  }
  if (is.null(names(target))) {
    cli::cli_abort("Target moments must be a named vector")
  }
  missing_covs <- setdiff(covariates, names(target))
  if (length(missing_covs) > 0) {
    cli::cli_abort("Target moments missing for covariates: {paste(missing_covs, collapse = ', ')}")
  }
  invisible(TRUE)
}

#' Standardize covariate matrix
#' @param X Covariate matrix
#' @param center Logical, whether to center
#' @param scale Logical, whether to scale
#' @return List with standardized matrix and transformation parameters
#' @keywords internal
standardize_covariates <- function(X, center = TRUE, scale = TRUE) {
  X <- as.matrix(X)
  means <- colMeans(X)
  sds <- apply(X, 2, sd)
  sds[sds == 0] <- 1

  X_std <- X
  if (center) {
    X_std <- sweep(X_std, 2, means, "-")
  }
  if (scale) {
    X_std <- sweep(X_std, 2, sds, "/")
  }

  list(
    X = X_std,
    center = if (center) means else NULL,
    scale = if (scale) sds else NULL
  )
}

#' Calculate constraint matrix for moment matching
#' @param X Covariate matrix (n x p)
#' @param target Target moments (named vector)
#' @param covariates Covariate names to match
#' @param match_variance Logical, whether to also match variances
#' @return Constraint matrix where each column is a constraint
#' @keywords internal
build_constraint_matrix <- function(X, target, covariates, match_variance = FALSE) {
  X <- as.matrix(X)
  n <- nrow(X)
  p <- length(covariates)

  # Mean constraints: X_ik - mu_k for each covariate k
  C_mean <- X[, covariates, drop = FALSE]
  for (k in seq_along(covariates)) {
    C_mean[, k] <- C_mean[, k] - target[covariates[k]]
  }

  if (!match_variance) {
    return(C_mean)
  }

  # Variance constraints: (X_ik - mu_k)^2 - sigma_k^2
  var_names <- paste0(covariates, "_var")
  if (!all(var_names %in% names(target))) {
    cli::cli_abort("Target variances must be provided when match_variance = TRUE")
  }

  C_var <- matrix(0, n, p)
  for (k in seq_along(covariates)) {
    mu_k <- target[covariates[k]]
    sigma2_k <- target[var_names[k]]
    C_var[, k] <- (X[, covariates[k]] - mu_k)^2 - sigma2_k
  }

  cbind(C_mean, C_var)
}

#' Normalize weights to sum to 1
#' @param w Numeric vector of weights
#' @return Normalized weights
#' @keywords internal
normalize_weights <- function(w) {
  w / sum(w)
}

#' Normalize weights to sum to sample size
#' @param w Numeric vector of weights
#' @param n Target sum (usually original sample size)
#' @return Rescaled weights
#' @keywords internal
rescale_weights <- function(w, n = length(w)) {
  w * n / sum(w)
}

#' Calculate weighted mean
#' @param x Numeric vector
#' @param w Weights
#' @return Weighted mean
#' @keywords internal
wmean <- function(x, w) {
  sum(x * w) / sum(w)
}

#' Calculate weighted variance
#' @param x Numeric vector
#' @param w Weights
#' @return Weighted variance (using reliability weights formula)
#' @keywords internal
wvar <- function(x, w) {
  w <- w / sum(w)
  mu <- sum(x * w)
  sum(w * (x - mu)^2) / (1 - sum(w^2))
}

#' Calculate weighted standard deviation
#' @param x Numeric vector
#' @param w Weights
#' @return Weighted standard deviation
#' @keywords internal
wsd <- function(x, w) {
  sqrt(wvar(x, w))
}

#' Create advmaic_weights object
#' @param weights Numeric vector of estimated weights
#' @param alpha Estimated Lagrange multipliers (if applicable
#' @param method Method used for estimation
#' @param covariates Covariates that were balanced
#' @param base_weights Base weights used (if any)
#' @param convergence Convergence information
#' @param call Original function call
#' @return Object of class advmaic_weights
#' @keywords internal
new_advmaic_weights <- function(weights, alpha = NULL, method, covariates,
                                 base_weights = NULL, convergence = NULL,
                                 call = NULL) {
  structure(
    list(
      weights = weights,
      alpha = alpha,
      method = method,
      covariates = covariates,
      base_weights = base_weights,
      convergence = convergence,
      call = call,
      n = length(weights),
      ess = calculate_ess(weights)
    ),
    class = "advmaic_weights"
  )
}

#' Print method for advmaic_weights
#' @param x advmaic_weights object
#' @param ... Additional arguments (ignored)
#' @return Invisible x
#' @export
print.advmaic_weights <- function(x, ...) {
  cli::cli_h1("MAIC Weights")
  cli::cli_alert_info("Method: {x$method}")
  cli::cli_alert_info("Sample size: {x$n}")
  cli::cli_alert_info("Effective sample size: {round(x$ess, 1)} ({round(100 * x$ess / x$n, 1)}%)")
  cli::cli_alert_info("Covariates balanced: {paste(x$covariates, collapse = ', ')}")

  if (!is.null(x$convergence)) {
    if (x$convergence$converged) {
      cli::cli_alert_success("Optimization converged")
    } else {
      cli::cli_alert_warning("Optimization did not converge: {x$convergence$message}")
    }
  }

  invisible(x)
}

#' Summary method for advmaic_weights
#' @param object advmaic_weights object
#' @param ... Additional arguments (ignored)
#' @return Summary list (invisibly)
#' @export
summary.advmaic_weights <- function(object, ...) {
  w <- object$weights

  summary_stats <- list(
    method = object$method,
    n = object$n,
    ess = object$ess,
    ess_pct = 100 * object$ess / object$n,
    covariates = object$covariates,
    weight_stats = list(
      min = min(w),
      q1 = quantile(w, 0.25),
      median = median(w),
      mean = mean(w),
      q3 = quantile(w, 0.75),
      max = max(w),
      sd = sd(w),
      cv = sd(w) / mean(w)
    ),
    convergence = object$convergence
  )

  cat("\n=== MAIC Weights Summary ===\n\n")
  cat("Method:", summary_stats$method, "\n")
  cat("Sample size:", summary_stats$n, "\n")
  cat("Effective sample size:", round(summary_stats$ess, 2),
      sprintf("(%.1f%%)\n", summary_stats$ess_pct))
  cat("\nWeight distribution:\n")
  cat("  Min:", round(summary_stats$weight_stats$min, 4), "\n")
  cat("  Q1:", round(summary_stats$weight_stats$q1, 4), "\n")
  cat("  Median:", round(summary_stats$weight_stats$median, 4), "\n")
  cat("  Mean:", round(summary_stats$weight_stats$mean, 4), "\n")
  cat("  Q3:", round(summary_stats$weight_stats$q3, 4), "\n")
  cat("  Max:", round(summary_stats$weight_stats$max, 4), "\n")
  cat("  CV:", round(summary_stats$weight_stats$cv, 4), "\n")

  invisible(summary_stats)
}
