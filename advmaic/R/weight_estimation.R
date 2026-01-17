#' @title Weight Estimation for MAIC
#' @name weight_estimation
#' @description Core functions for estimating MAIC weights using various methods.
NULL

#' Estimate MAIC Weights
#'
#' Main function for estimating matching-adjusted indirect comparison weights.
#' Supports multiple weighting methods including entropy balancing, method of
#' moments, and empirical likelihood.
#'
#' @param ipd Data frame containing individual patient data from the index trial.
#' @param agd_target Named numeric vector of target moments from the aggregate
#'   data. Names should match covariate names, with optional "_var" suffix for
#'   variance targets.
#' @param covariates Character vector of covariate names to balance.
#' @param method Character string specifying the weighting method. One of
#'   "entropy" (default), "moments", or "empirical_likelihood".
#' @param base_weights Optional numeric vector of non-uniform base weights.
#'   If NULL (default), uniform weights (1/n) are used.
#' @param by_arm Logical. If TRUE, estimate weights separately by treatment arm.
#' @param arm_var Character string specifying the arm variable name when
#'   by_arm = TRUE.
#' @param match_variance Logical. If TRUE, also match variances of covariates.
#' @param loss_function Character string specifying the loss function. One of
#'   "entropy" (default), "empirical_likelihood", or "cressie_read".
#' @param gamma Numeric. Parameter for Cressie-Read divergence when
#'   loss_function = "cressie_read". Default is 0 (entropy).
#' @param max_iter Maximum number of iterations for optimization.
#' @param tol Convergence tolerance.
#' @param verbose Logical. If TRUE, print optimization progress.
#'
#' @return An object of class "advmaic_weights" containing:
#'   \item{weights}{Numeric vector of estimated weights}
#'   \item{alpha}{Estimated Lagrange multipliers}
#'   \item{method}{Method used for estimation}
#'   \item{covariates}{Covariates that were balanced}
#'   \item{base_weights}{Base weights used}
#'   \item{convergence}{Convergence information}
#'   \item{n}{Sample size}
#'   \item{ess}{Effective sample size}
#'
#' @details
#' This function implements the unified framework for MAIC weight estimation
#' described in Phillippo et al. (2020). The method of moments and entropy
#' balancing approaches are mathematically equivalent for uniform base weights.
#'
#' For non-uniform base weights, the entropy balancing formulation minimizes:
#' \deqn{H_{EB}(\alpha) = \log\left(\sum_i w_i^{(0)} \exp(x_i^T \alpha)\right)}
#'
#' where \eqn{w_i^{(0)}} are the base weights and \eqn{x_i} are the centered

' covariates.
#'
#' @references
#' Phillippo DM, et al. (2020). Equivalence of entropy balancing and the method
#' of moments for matching-adjusted indirect comparison. Research Synthesis
#' Methods. 11:568-572.
#'
#' Hainmueller J. (2012). Entropy balancing for causal effects: A multivariate
#' reweighting method to produce balanced samples in observational studies.
#' Political Analysis. 20:25-46.
#'
#' @examples
#' \dontrun{
#' # Example with simulated data
#' set.seed(123)
#' n <- 200
#' ipd <- data.frame(
#'   age = rnorm(n, 55, 10),
#'   male = rbinom(n, 1, 0.6),
#'   biomarker = rnorm(n, 100, 20),
#'   treatment = rbinom(n, 1, 0.5),
#'   outcome = rnorm(n, 0, 1)
#' )
#'
#' # Target moments from aggregate data
#' agd_target <- c(age = 60, male = 0.5, biomarker = 110)
#'
#' # Estimate weights
#' weights <- estimate_weights(
#'   ipd = ipd,
#'   agd_target = agd_target,
#'   covariates = c("age", "male", "biomarker"),
#'   method = "entropy"
#' )
#'
#' print(weights)
#' }
#'
#' @export
estimate_weights <- function(ipd,
                             agd_target,
                             covariates,
                             method = c("entropy", "moments", "empirical_likelihood"),
                             base_weights = NULL,
                             by_arm = FALSE,
                             arm_var = NULL,
                             match_variance = FALSE,
                             loss_function = c("entropy", "empirical_likelihood", "cressie_read"),
                             gamma = 0,
                             max_iter = 1000,
                             tol = 1e-8,
                             verbose = FALSE) {

  # Argument matching
  method <- match.arg(method)
  loss_function <- match.arg(loss_function)

  # Input validation
  if (!is.data.frame(ipd)) {
    cli::cli_abort("ipd must be a data frame")
  }

  missing_covs <- setdiff(covariates, names(ipd))
  if (length(missing_covs) > 0) {
    cli::cli_abort("Covariates not found in ipd: {paste(missing_covs, collapse = ', ')}")
  }

  check_target_moments(agd_target, covariates)

  # Handle by_arm estimation
 if (by_arm) {
    if (is.null(arm_var)) {
      cli::cli_abort("arm_var must be specified when by_arm = TRUE")
    }
    if (!(arm_var %in% names(ipd))) {
      cli::cli_abort("arm_var '{arm_var}' not found in ipd")
    }
    return(estimate_weights_by_arm(
      ipd = ipd,
      agd_target = agd_target,
      covariates = covariates,
      arm_var = arm_var,
      method = method,
      base_weights = base_weights,
      match_variance = match_variance,
      loss_function = loss_function,
      gamma = gamma,
      max_iter = max_iter,
      tol = tol,
      verbose = verbose
    ))
  }

  # Extract covariate matrix
  X <- as.matrix(ipd[, covariates, drop = FALSE])
  n <- nrow(X)

  # Set up base weights
  if (is.null(base_weights)) {
    base_weights <- rep(1 / n, n)
  } else {
    if (length(base_weights) != n) {
      cli::cli_abort("base_weights must have length equal to nrow(ipd)")
    }
    base_weights <- normalize_weights(base_weights)
  }

  # Build constraint matrix (centered covariates)
  C <- build_constraint_matrix(X, agd_target, covariates, match_variance)

  # Estimate weights based on method
  if (method == "entropy") {
    result <- entropy_balance(
      C = C,
      base_weights = base_weights,
      loss_function = loss_function,
      gamma = gamma,
      max_iter = max_iter,
      tol = tol,
      verbose = verbose
    )
  } else if (method == "moments") {
    result <- method_of_moments(
      C = C,
      base_weights = base_weights,
      max_iter = max_iter,
      tol = tol,
      verbose = verbose
    )
  } else if (method == "empirical_likelihood") {
    result <- entropy_balance(
      C = C,
      base_weights = base_weights,
      loss_function = "empirical_likelihood",
      gamma = -1,
      max_iter = max_iter,
      tol = tol,
      verbose = verbose
    )
  }

  # Create output object
  new_advmaic_weights(
    weights = result$weights,
    alpha = result$alpha,
    method = method,
    covariates = covariates,
    base_weights = base_weights,
    convergence = result$convergence,
    call = match.call()
  )
}

#' Estimate Weights Separately by Treatment Arm
#'
#' Internal function to estimate weights separately for each treatment arm.
#'
#' @inheritParams estimate_weights
#' @return advmaic_weights object with weights for all observations
#' @keywords internal
estimate_weights_by_arm <- function(ipd, agd_target, covariates, arm_var,
                                    method, base_weights, match_variance,
                                    loss_function, gamma, max_iter, tol,
                                    verbose) {

  arms <- unique(ipd[[arm_var]])
  n <- nrow(ipd)
  weights <- numeric(n)
  alpha_list <- list()

  for (arm in arms) {
    arm_idx <- which(ipd[[arm_var]] == arm)
    ipd_arm <- ipd[arm_idx, , drop = FALSE]

    # Subset base weights if provided
    base_weights_arm <- if (is.null(base_weights)) {
      NULL
    } else {
      base_weights[arm_idx]
    }

    # Estimate weights for this arm
    result_arm <- estimate_weights(
      ipd = ipd_arm,
      agd_target = agd_target,
      covariates = covariates,
      method = method,
      base_weights = base_weights_arm,
      by_arm = FALSE,
      match_variance = match_variance,
      loss_function = loss_function,
      gamma = gamma,
      max_iter = max_iter,
      tol = tol,
      verbose = verbose
    )

    weights[arm_idx] <- result_arm$weights
    alpha_list[[as.character(arm)]] <- result_arm$alpha
  }

  # Create output object
  new_advmaic_weights(
    weights = weights,
    alpha = alpha_list,
    method = paste0(method, "_by_arm"),
    covariates = covariates,
    base_weights = base_weights,
    convergence = list(converged = TRUE, message = "Estimated by arm"),
    call = match.call()
  )
}
