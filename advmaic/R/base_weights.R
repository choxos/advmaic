#' @title Non-Uniform Base Weights Generators
#' @name base_weights
#' @description Functions to generate non-uniform base weights for entropy
#'   balancing MAIC. These implement the novel framework from Phillippo et al.
#'   (2020) for combining MAIC with other adjustment methods.
NULL

#' Nonparametric Covariate Adjustment Base Weights
#'
#' Generates base weights using the inverse probability of treatment weighting
#' (IPTW) approach for nonparametric covariate adjustment, as described in
#' Williamson et al. (2013). This can be combined with MAIC to achieve variance
#' reduction while adjusting for population differences.
#'
#' @param ipd Data frame containing individual patient data.
#' @param covariates Character vector of covariate names for the propensity model.
#' @param treatment_var Character string specifying the treatment variable name.
#' @param treatment_value Value indicating the treatment arm (default is 1).
#' @param ps_method Method for propensity score estimation: "logistic" (default)
#'   or "gbm" for gradient boosted machines.
#' @param stabilize Logical. If TRUE, use stabilized weights.
#' @param trim_quantile Numeric. Quantile for trimming extreme propensity scores.
#'   Set to 0 for no trimming.
#'
#' @return A numeric vector of base weights (normalized to sum to 1).
#'
#' @details
#' The nonparametric covariate adjustment (NPCA) approach uses IPTW to create
#' weights that, when applied to the treated group, balance prognostic covariates
#' with the control group within the trial. This leads to variance reduction
#' without introducing bias in the treatment effect estimate.
#'
#' Following Williamson et al. (2013), the weights for treated subjects are:
#' \deqn{w_i^{NPCA} = \frac{1 - e(X_i)}{e(X_i)}}
#'
#' where \eqn{e(X_i)} is the propensity score (probability of treatment given
#' covariates).
#'
#' When combined with MAIC entropy balancing, these base weights allow
#' simultaneous adjustment for:
#' 1. Population differences (via MAIC)
#' 2. Prognostic imbalances within the trial (via NPCA)
#'
#' @references
#' Williamson EJ, Forbes A, White IR. (2014). Variance reduction in randomised
#' trials by inverse probability weighting using the propensity score.
#' Statistics in Medicine. 33:721-737.
#'
#' Phillippo DM, et al. (2020). Equivalence of entropy balancing and the method
#' of moments for matching-adjusted indirect comparison. Research Synthesis
#' Methods. 11:568-572.
#'
#' @examples
#' \dontrun{
#' # Simulate trial data
#' set.seed(123)
#' n <- 200
#' ipd <- data.frame(
#'   age = rnorm(n, 55, 10),
#'   biomarker = rnorm(n, 100, 20),
#'   treatment = rbinom(n, 1, 0.5)
#' )
#'
#' # Generate NPCA base weights
#' w0 <- npca_base_weights(
#'   ipd = ipd,
#'   covariates = c("age", "biomarker"),
#'   treatment_var = "treatment"
#' )
#'
#' # Use in MAIC
#' agd_target <- c(age = 60, biomarker = 110)
#' weights <- estimate_weights(
#'   ipd = ipd[ipd$treatment == 1, ],
#'   agd_target = agd_target,
#'   covariates = c("age", "biomarker"),
#'   base_weights = w0[ipd$treatment == 1]
#' )
#' }
#'
#' @export
npca_base_weights <- function(ipd,
                              covariates,
                              treatment_var,
                              treatment_value = 1,
                              ps_method = c("logistic", "gbm"),
                              stabilize = TRUE,
                              trim_quantile = 0.01) {

  ps_method <- match.arg(ps_method)

  # Validate inputs
  if (!is.data.frame(ipd)) {
    cli::cli_abort("ipd must be a data frame")
  }

  if (!(treatment_var %in% names(ipd))) {
    cli::cli_abort("treatment_var '{treatment_var}' not found in ipd")
  }

  missing_covs <- setdiff(covariates, names(ipd))
  if (length(missing_covs) > 0) {
    cli::cli_abort("Covariates not found in ipd: {paste(missing_covs, collapse = ', ')}")
  }

  n <- nrow(ipd)

  # Create treatment indicator
  trt <- as.numeric(ipd[[treatment_var]] == treatment_value)

  # Estimate propensity scores
  if (ps_method == "logistic") {
    # Logistic regression
    ps_formula <- stats::as.formula(
      paste("trt ~", paste(covariates, collapse = " + "))
    )
    ps_data <- cbind(ipd[, covariates, drop = FALSE], trt = trt)
    ps_model <- stats::glm(ps_formula, data = ps_data, family = stats::binomial())
    ps <- stats::predict(ps_model, type = "response")
  } else if (ps_method == "gbm") {
    # Would require gbm package - for now use logistic
    cli::cli_alert_warning("GBM not yet implemented, using logistic regression")
    ps_formula <- stats::as.formula(
      paste("trt ~", paste(covariates, collapse = " + "))
    )
    ps_data <- cbind(ipd[, covariates, drop = FALSE], trt = trt)
    ps_model <- stats::glm(ps_formula, data = ps_data, family = stats::binomial())
    ps <- stats::predict(ps_model, type = "response")
  }

  # Trim extreme propensity scores
  if (trim_quantile > 0) {
    lower <- stats::quantile(ps, trim_quantile)
    upper <- stats::quantile(ps, 1 - trim_quantile)
    ps <- pmax(pmin(ps, upper), lower)
  }

  # Calculate IPTW weights
  # For treated: w = 1/e(X)
  # For control: w = 1/(1-e(X))
  # Following Williamson 2013 for variance reduction in treated group:
  # w_treated = (1 - e(X)) / e(X)
  weights <- numeric(n)
  weights[trt == 1] <- (1 - ps[trt == 1]) / ps[trt == 1]
  weights[trt == 0] <- ps[trt == 0] / (1 - ps[trt == 0])

  # Stabilize weights
  if (stabilize) {
    p_trt <- mean(trt)
    weights[trt == 1] <- weights[trt == 1] * p_trt
    weights[trt == 0] <- weights[trt == 0] * (1 - p_trt)
  }

  # Normalize
  weights <- weights / sum(weights)

  weights
}

#' IPCW Base Weights for Treatment Switching
#'
#' Generates base weights using inverse probability of censoring weighting (IPCW)
#' to adjust for treatment switching in the index trial. This allows combining
#' MAIC population adjustment with treatment switching adjustment while
#' maintaining randomization benefits in anchored comparisons.
#'
#' @param ipd Data frame containing individual patient data.
#' @param time_var Character string specifying the follow-up time variable.
#' @param event_var Character string specifying the event indicator (1 = event).
#' @param switch_var Character string specifying the switching indicator
#'   (1 = switched treatment).
#' @param switch_time_var Character string specifying the time of switching
#'   (NA if no switch).
#' @param covariates Character vector of covariate names for the censoring model.
#' @param method Method for IPCW: "cox" for Cox model or "pooled_logistic" for
#'   pooled logistic regression.
#' @param stabilize Logical. If TRUE, use stabilized weights.
#'
#' @return A numeric vector of base weights (normalized to sum to 1).
#'
#' @details
#' Treatment switching occurs when patients randomized to one arm switch to
#' receive treatment from another arm, typically due to disease progression.
#' This violates the intention-to-treat principle and can bias treatment effect
#' estimates.
#'
#' IPCW adjusts for switching by weighting patients who did not switch to
#' account for those who would have been similar but switched. The weights are
#' based on the inverse probability of remaining uncensored (not switching).
#'
#' When combined with MAIC, this approach allows:
#' 1. Adjustment for treatment switching (via IPCW)
#' 2. Adjustment for population differences (via MAIC)
#' 3. Preservation of randomization in anchored comparisons
#'
#' @references
#' Robins JM, Finkelstein DM. (2000). Correcting for noncompliance and dependent
#' censoring in an AIDS Clinical Trial with inverse probability of censoring
#' weighted (IPCW) log-rank tests. Biometrics. 56:779-788.
#'
#' @examples
#' \dontrun
#' # Simulate trial data with treatment switching
#' set.seed(123)
#' n <- 200
#' ipd <- data.frame(
#'   time = rexp(n, 0.1),
#'   event = rbinom(n, 1, 0.7),
#'   switched = rbinom(n, 1, 0.2),
#'   switch_time = NA,
#'   age = rnorm(n, 55, 10),
#'   biomarker = rnorm(n, 100, 20)
#' )
#' ipd$switch_time[ipd$switched == 1] <- runif(sum(ipd$switched), 0, ipd$time[ipd$switched == 1])
#'
#' # Generate IPCW base weights
#' w0 <- ipcw_base_weights(
#'   ipd = ipd,
#'   time_var = "time",
#'   event_var = "event",
#'   switch_var = "switched",
#'   switch_time_var = "switch_time",
#'   covariates = c("age", "biomarker")
#' )
#' }
#'
#' @export
ipcw_base_weights <- function(ipd,
                              time_var,
                              event_var,
                              switch_var,
                              switch_time_var = NULL,
                              covariates,
                              method = c("cox", "pooled_logistic"),
                              stabilize = TRUE) {

  method <- match.arg(method)

  # Validate inputs
  required_vars <- c(time_var, event_var, switch_var)
  missing_vars <- setdiff(required_vars, names(ipd))
  if (length(missing_vars) > 0) {
    cli::cli_abort("Variables not found in ipd: {paste(missing_vars, collapse = ', ')}")
  }

  n <- nrow(ipd)
  time <- ipd[[time_var]]
  event <- ipd[[event_var]]
  switched <- ipd[[switch_var]]

  # For IPCW, we model the probability of NOT switching (censoring)
  # Create censoring indicator: 1 if censored due to switching, 0 otherwise
  cens <- as.numeric(switched == 1)

  if (method == "cox") {
    # Cox model for censoring
    # Survival object: time to switch or end of follow-up
    if (!is.null(switch_time_var) && switch_time_var %in% names(ipd)) {
      cens_time <- ifelse(switched == 1, ipd[[switch_time_var]], time)
    } else {
      # If no switch time provided, use event time
      cens_time <- time
    }

    # Create survival formula
    cens_formula <- stats::as.formula(
      paste("survival::Surv(cens_time, cens) ~", paste(covariates, collapse = " + "))
    )

    cens_data <- cbind(ipd[, covariates, drop = FALSE],
                       cens_time = cens_time, cens = cens)

    # Fit Cox model
    cens_model <- survival::coxph(cens_formula, data = cens_data)

    # Get cumulative hazard at each person's time
    # H(t|X) = H_0(t) * exp(X'beta)
    basehaz <- survival::basehaz(cens_model, centered = FALSE)

    # For each individual, get H(t_i|X_i)
    linear_pred <- stats::predict(cens_model, type = "lp")

    # Find cumulative baseline hazard at each person's time
    H0 <- approx(basehaz$time, basehaz$hazard, xout = cens_time,
                 method = "constant", rule = 2, f = 0)$y

    # Cumulative hazard for each person
    H <- H0 * exp(linear_pred)

    # Probability of not switching by time t: S(t|X) = exp(-H(t|X))
    prob_no_switch <- exp(-H)

  } else if (method == "pooled_logistic") {
    # Pooled logistic regression (approximate Cox model)
    # This requires creating person-period data

    cli::cli_alert_warning("Pooled logistic not fully implemented, using Cox model")
    # Fall back to Cox for now
    return(ipcw_base_weights(ipd, time_var, event_var, switch_var,
                             switch_time_var, covariates, "cox", stabilize))
  }

  # IPCW weights: 1 / P(no switch)
  # For those who switched, weight is typically 0 or handled separately
  weights <- rep(1, n)
  weights[switched == 0] <- 1 / prob_no_switch[switched == 0]
  weights[switched == 1] <- 0  # Exclude switchers

  # Handle extreme weights
  max_weight <- stats::quantile(weights[weights > 0], 0.99)
  weights <- pmin(weights, max_weight)

  # Stabilize weights
  if (stabilize) {
    # Marginal probability of not switching
    marg_prob <- mean(switched == 0)
    weights[switched == 0] <- weights[switched == 0] * marg_prob
  }

  # Normalize
  if (sum(weights) > 0) {
    weights <- weights / sum(weights)
  }

  weights
}

#' Propensity Score Base Weights
#'
#' Generates base weights from a custom propensity score model. This is a
#' flexible function that allows users to specify their own propensity score
#' formula for generating base weights.
#'
#' @param ipd Data frame containing individual patient data.
#' @param ps_formula Formula for the propensity score model.
#' @param target_estimand Character string specifying the target estimand:
#'   "ATE" (average treatment effect), "ATT" (average treatment effect on treated),
#'   or "ATC" (average treatment effect on controls).
#' @param treatment_var Character string specifying the treatment variable name.
#' @param stabilize Logical. If TRUE, use stabilized weights.
#'
#' @return A numeric vector of base weights (normalized to sum to 1).
#'
#' @details
#' This function provides flexibility for users to define custom propensity
#' score models for generating base weights. The weights are calculated based
#' on the inverse propensity score, with the specific formula depending on the
#' target estimand.
#'
#' @export
ps_base_weights <- function(ipd,
                            ps_formula,
                            target_estimand = c("ATT", "ATE", "ATC"),
                            treatment_var,
                            stabilize = TRUE) {

  target_estimand <- match.arg(target_estimand)

  # Validate inputs
  if (!is.data.frame(ipd)) {
    cli::cli_abort("ipd must be a data frame")
  }

  n <- nrow(ipd)
  trt <- ipd[[treatment_var]]

  # Fit propensity score model
  ps_model <- stats::glm(ps_formula, data = ipd, family = stats::binomial())
  ps <- stats::predict(ps_model, type = "response")

  # Trim extreme propensity scores
  ps <- pmax(pmin(ps, 0.99), 0.01)

  # Calculate weights based on estimand
  weights <- numeric(n)

  if (target_estimand == "ATT") {
    # Target treated population
    weights[trt == 1] <- 1
    weights[trt == 0] <- ps[trt == 0] / (1 - ps[trt == 0])
  } else if (target_estimand == "ATC") {
    # Target control population
    weights[trt == 1] <- (1 - ps[trt == 1]) / ps[trt == 1]
    weights[trt == 0] <- 1
  } else if (target_estimand == "ATE") {
    # Target overall population
    weights[trt == 1] <- 1 / ps[trt == 1]
    weights[trt == 0] <- 1 / (1 - ps[trt == 0])
  }

  # Stabilize
  if (stabilize) {
    p_trt <- mean(trt)
    if (target_estimand == "ATT") {
      weights[trt == 0] <- weights[trt == 0] * (1 - p_trt)
    } else if (target_estimand == "ATC") {
      weights[trt == 1] <- weights[trt == 1] * p_trt
    } else {
      weights[trt == 1] <- weights[trt == 1] * p_trt
      weights[trt == 0] <- weights[trt == 0] * (1 - p_trt)
    }
  }

  # Normalize
  weights <- weights / sum(weights)

  weights
}
