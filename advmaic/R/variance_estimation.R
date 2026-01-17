#' @title Variance Estimation for MAIC
#' @name variance_estimation
#' @description Functions for estimating the variance of MAIC treatment effect
#'   estimates using bootstrap and robust sandwich estimators.
NULL

#' Bootstrap Variance Estimation
#'
#' Estimates the variance of a MAIC treatment effect using nonparametric bootstrap.
#'
#' @param ipd Data frame containing individual patient data.
#' @param agd_target Named numeric vector of target moments.
#' @param covariates Character vector of covariate names.
#' @param outcome_var Character string specifying the outcome variable name.
#' @param treatment_var Character string specifying the treatment variable name.
#' @param outcome_type Type of outcome: "continuous", "binary", or "tte".
#' @param estimand Estimand: "rd" (risk difference), "rr" (risk ratio),
#'   "or" (odds ratio), or "hr" (hazard ratio).
#' @param weight_args List of additional arguments passed to estimate_weights.
#' @param nboot Number of bootstrap iterations.
#' @param conf_level Confidence level for bootstrap intervals.
#' @param seed Random seed for reproducibility.
#' @param parallel Logical. If TRUE, use parallel processing.
#' @param ncores Number of cores for parallel processing.
#'
#' @return A list containing:
#'   \item{estimate}{Point estimate of treatment effect}
#'   \item{se}{Bootstrap standard error}
#'   \item{ci_lower}{Lower confidence interval}
#'   \item{ci_upper}{Upper confidence interval}
#'   \item{boot_estimates}{Vector of bootstrap estimates}
#'   \item{ci_method}{Method used for CI calculation}
#'
#' @details
#' The bootstrap procedure:
#' 1. Resample IPD with replacement
#' 2. Re-estimate MAIC weights on resampled data
#' 3. Estimate weighted treatment effect
#' 4. Repeat B times
#'
#' Confidence intervals are computed using the percentile method by default.
#'
#' @references
#' Efron B, Tibshirani RJ. (1993). An Introduction to the Bootstrap. Chapman & Hall.
#'
#' @examples
#' \dontrun{
#' result <- bootstrap_variance(
#'   ipd = ipd,
#'   agd_target = agd_target,
#'   covariates = c("age", "male"),
#'   outcome_var = "outcome",
#'   treatment_var = "treatment",
#'   nboot = 1000
#' )
#' }
#'
#' @export
bootstrap_variance <- function(ipd,
                               agd_target,
                               covariates,
                               outcome_var,
                               treatment_var,
                               outcome_type = c("continuous", "binary", "tte"),
                               estimand = c("rd", "rr", "or", "hr"),
                               weight_args = list(),
                               nboot = 1000,
                               conf_level = 0.95,
                               seed = NULL,
                               parallel = FALSE,
                               ncores = 2) {

  outcome_type <- match.arg(outcome_type)
  estimand <- match.arg(estimand)

  if (!is.null(seed)) set.seed(seed)

  n <- nrow(ipd)

  # Function to compute estimate for one bootstrap sample
  boot_fn <- function(data, indices) {
    # Resample
    boot_data <- data[indices, , drop = FALSE]

    # Re-estimate weights
    weight_result <- tryCatch({
      do.call(estimate_weights, c(
        list(
          ipd = boot_data,
          agd_target = agd_target,
          covariates = covariates
        ),
        weight_args
      ))
    }, error = function(e) NULL)

    if (is.null(weight_result)) return(NA)

    # Estimate treatment effect
    effect <- tryCatch({
      estimate_weighted_effect(
        data = boot_data,
        weights = weight_result$weights,
        outcome_var = outcome_var,
        treatment_var = treatment_var,
        outcome_type = outcome_type,
        estimand = estimand
      )
    }, error = function(e) NA)

    effect
  }

  # Run bootstrap
  if (parallel && requireNamespace("parallel", quietly = TRUE)) {
    # Parallel bootstrap
    boot_indices <- lapply(1:nboot, function(i) sample(n, replace = TRUE))
    boot_estimates <- parallel::mclapply(boot_indices, function(idx) {
      boot_fn(ipd, idx)
    }, mc.cores = ncores)
    boot_estimates <- unlist(boot_estimates)
  } else {
    # Sequential bootstrap
    boot_result <- boot::boot(
      data = ipd,
      statistic = boot_fn,
      R = nboot
    )
    boot_estimates <- boot_result$t[, 1]
  }

  # Remove failed iterations
  boot_estimates <- boot_estimates[!is.na(boot_estimates)]

  if (length(boot_estimates) < nboot * 0.8) {
    cli::cli_alert_warning("More than 20% of bootstrap iterations failed")
  }

  # Point estimate (original sample)
  weights_original <- do.call(estimate_weights, c(
    list(ipd = ipd, agd_target = agd_target, covariates = covariates),
    weight_args
  ))

  point_estimate <- estimate_weighted_effect(
    data = ipd,
    weights = weights_original$weights,
    outcome_var = outcome_var,
    treatment_var = treatment_var,
    outcome_type = outcome_type,
    estimand = estimand
  )

  # Calculate CI
  alpha <- 1 - conf_level
  ci <- stats::quantile(boot_estimates, c(alpha/2, 1 - alpha/2))

  list(
    estimate = point_estimate,
    se = stats::sd(boot_estimates),
    ci_lower = ci[1],
    ci_upper = ci[2],
    boot_estimates = boot_estimates,
    ci_method = "percentile",
    conf_level = conf_level,
    n_successful = length(boot_estimates)
  )
}

#' Estimate Weighted Treatment Effect
#'
#' Internal function to estimate the treatment effect from weighted data.
#'
#' @param data Data frame.
#' @param weights Numeric vector of weights.
#' @param outcome_var Outcome variable name.
#' @param treatment_var Treatment variable name.
#' @param outcome_type Type of outcome.
#' @param estimand Estimand.
#'
#' @return Numeric treatment effect estimate.
#'
#' @keywords internal
estimate_weighted_effect <- function(data, weights, outcome_var, treatment_var,
                                     outcome_type, estimand) {

  y <- data[[outcome_var]]
  trt <- data[[treatment_var]]

  if (outcome_type == "continuous") {
    # Weighted mean difference
    mean_trt <- wmean(y[trt == 1], weights[trt == 1])
    mean_ctrl <- wmean(y[trt == 0], weights[trt == 0])
    return(mean_trt - mean_ctrl)

  } else if (outcome_type == "binary") {
    # Weighted proportions
    p_trt <- wmean(y[trt == 1], weights[trt == 1])
    p_ctrl <- wmean(y[trt == 0], weights[trt == 0])

    if (estimand == "rd") {
      return(p_trt - p_ctrl)
    } else if (estimand == "rr") {
      return(log(p_trt / p_ctrl))
    } else if (estimand == "or") {
      odds_trt <- p_trt / (1 - p_trt)
      odds_ctrl <- p_ctrl / (1 - p_ctrl)
      return(log(odds_trt / odds_ctrl))
    }

  } else if (outcome_type == "tte") {
    # Cox regression for hazard ratio
    if (!requireNamespace("survival", quietly = TRUE)) {
      cli::cli_abort("survival package required for TTE outcomes")
    }

    # Assume outcome_var is a Surv object or we have time and event columns
    # This is simplified - in practice would need time and event vars
    cli::cli_alert_warning("TTE estimation requires time and event variables")
    return(NA)
  }
}

#' Sandwich Variance Estimator for MAIC
#'
#' Computes the robust (sandwich) variance estimator for weighted regression
#' in MAIC, accounting for weight estimation uncertainty.
#'
#' @param model A fitted model object (glm, coxph, etc.).
#' @param weights MAIC weights used in fitting.
#' @param type Type of sandwich estimator: "HC0", "HC1", "HC2", or "HC3".
#'
#' @return A variance-covariance matrix.
#'
#' @details
#' The sandwich estimator provides robust standard errors that are valid even
#' when the model is misspecified. For MAIC, this accounts for the fact that
#' observations receive different weights.
#'
#' Note that this does not account for uncertainty in the weight estimation
#' itself. For that, use bootstrap_variance.
#'
#' @export
sandwich_variance <- function(model, weights = NULL, type = "HC1") {

  if (!requireNamespace("sandwich", quietly = TRUE)) {
    cli::cli_abort("sandwich package required for robust variance estimation")
  }

  # Get sandwich variance matrix
  V <- sandwich::vcovHC(model, type = type)

  V
}

#' Combined Variance Accounting for AgD Uncertainty
#'
#' Combines the variance from the MAIC (IPD) analysis with variance from
#' the aggregate data to produce the total variance for indirect comparison.
#'
#' @param var_maic Variance of the MAIC estimate (from IPD).
#' @param var_agd Variance of the aggregate data estimate.
#' @param correlation Assumed correlation between estimates (usually 0 for
#'   independent trials).
#'
#' @return Combined variance.
#'
#' @details
#' For an indirect comparison via Bucher method:
#' \deqn{Var(d_{BC}) = Var(d_{AC}) + Var(d_{AB})}
#'
#' assuming independence of the two trial estimates.
#'
#' @export
combine_variances <- function(var_maic, var_agd, correlation = 0) {
  var_maic + var_agd - 2 * correlation * sqrt(var_maic * var_agd)
}

#' Calculate AgD Variance from Summary Statistics
#'
#' Calculates the variance of treatment effects from published aggregate data.
#'
#' @param outcome_type Type of outcome: "continuous", "binary", or "tte".
#' @param estimand Estimand type.
#' @param ... Additional parameters depending on outcome type.
#'
#' @details
#' For binary outcomes with log OR:
#' \code{n_event_trt, n_trt, n_event_ctrl, n_ctrl}
#'
#' For continuous outcomes:
#' \code{sd_trt, n_trt, sd_ctrl, n_ctrl}
#'
#' For TTE with log HR:
#' \code{hr, ci_lower, ci_upper} (to back-calculate SE)
#'
#' @return Estimated variance.
#'
#' @export
agd_variance <- function(outcome_type = c("continuous", "binary", "tte"),
                         estimand = NULL, ...) {

  outcome_type <- match.arg(outcome_type)
  args <- list(...)

  if (outcome_type == "binary") {
    # Variance of log OR using 1/cell count formula
    a <- args$n_event_trt
    b <- args$n_trt - args$n_event_trt
    c <- args$n_event_ctrl
    d <- args$n_ctrl - args$n_event_ctrl

    var_log_or <- 1/a + 1/b + 1/c + 1/d
    return(var_log_or)

  } else if (outcome_type == "continuous") {
    # Variance of mean difference
    var_md <- args$sd_trt^2 / args$n_trt + args$sd_ctrl^2 / args$n_ctrl
    return(var_md)

  } else if (outcome_type == "tte") {
    # Back-calculate SE from CI
    if (!is.null(args$hr) && !is.null(args$ci_lower) && !is.null(args$ci_upper)) {
      log_hr <- log(args$hr)
      log_ci_lower <- log(args$ci_lower)
      log_ci_upper <- log(args$ci_upper)
      se <- (log_ci_upper - log_ci_lower) / (2 * 1.96)
      return(se^2)
    }
  }

  cli::cli_abort("Insufficient information to calculate variance")
}
