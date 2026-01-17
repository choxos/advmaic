#' @title Outcome Analysis for MAIC
#' @name outcome_analysis
#' @description Functions for estimating treatment effects and conducting
#'   indirect comparisons using MAIC weights.
NULL

#' Estimate Average Treatment Effect
#'
#' Estimates the treatment effect from weighted IPD using appropriate
#' regression models based on outcome type.
#'
#' @param ipd Data frame containing individual patient data.
#' @param weights Numeric vector of MAIC weights (or advmaic_weights object).
#' @param outcome_var Character string specifying the outcome variable name.
#' @param treatment_var Character string specifying the treatment variable name.
#' @param time_var Character string specifying time variable for TTE outcomes.
#' @param event_var Character string specifying event indicator for TTE outcomes.
#' @param covariates Optional character vector of covariate names to include
#'   in the outcome model (for adjusted estimates).
#' @param outcome_type Type of outcome: "continuous", "binary", or "tte".
#' @param estimand Estimand: "rd" (risk difference), "rr" (risk ratio),
#'   "or" (odds ratio), or "hr" (hazard ratio).
#' @param variance_method Method for variance estimation: "robust" (sandwich),
#'   "model" (model-based), or "bootstrap".
#' @param nboot Number of bootstrap iterations if variance_method = "bootstrap".
#' @param conf_level Confidence level.
#'
#' @return A list of class "advmaic_ate" containing:
#'   \item{estimate}{Point estimate of treatment effect}
#'   \item{se}{Standard error}
#'   \item{ci_lower}{Lower confidence interval}
#'   \item{ci_upper}{Upper confidence interval}
#'   \item{estimand}{Estimand type}
#'   \item{model}{Fitted model object}
#'   \item{variance_method}{Method used for variance estimation}
#'
#' @details
#' For continuous outcomes, uses weighted linear regression.
#' For binary outcomes, uses weighted logistic regression.
#' For time-to-event outcomes, uses weighted Cox regression.
#'
#' The robust (sandwich) variance estimator is recommended for MAIC as it
#' accounts for the unequal weighting.
#'
#' @examples
#' \dontrun{
#' # Estimate weights first
#' weights <- estimate_weights(ipd, agd_target, covariates)
#'
#' # Estimate treatment effect
#' ate <- estimate_ate(
#'   ipd = ipd,
#'   weights = weights,
#'   outcome_var = "response",
#'   treatment_var = "treatment",
#'   outcome_type = "binary",
#'   estimand = "or"
#' )
#'
#' print(ate)
#' }
#'
#' @export
estimate_ate <- function(ipd,
                         weights,
                         outcome_var,
                         treatment_var,
                         time_var = NULL,
                         event_var = NULL,
                         covariates = NULL,
                         outcome_type = c("continuous", "binary", "tte"),
                         estimand = c("rd", "rr", "or", "hr"),
                         variance_method = c("robust", "model", "bootstrap"),
                         nboot = 1000,
                         conf_level = 0.95) {

  outcome_type <- match.arg(outcome_type)
  estimand <- match.arg(estimand)
  variance_method <- match.arg(variance_method)

  # Extract weights if advmaic_weights object
  if (inherits(weights, "advmaic_weights")) {
    w <- weights$weights
  } else {
    w <- weights
  }

  # Rescale weights to sum to sample size
  w <- rescale_weights(w, nrow(ipd))

  # Build formula
  if (is.null(covariates)) {
    formula_str <- paste(outcome_var, "~", treatment_var)
  } else {
    formula_str <- paste(outcome_var, "~", treatment_var, "+",
                         paste(covariates, collapse = " + "))
  }

  if (outcome_type == "continuous") {
    # Linear regression for continuous outcomes
    model <- stats::lm(
      stats::as.formula(formula_str),
      data = ipd,
      weights = w
    )

    # Treatment effect is coefficient on treatment variable
    coef_idx <- which(names(stats::coef(model)) == treatment_var)
    estimate <- stats::coef(model)[coef_idx]

    # Variance
    if (variance_method == "robust") {
      V <- sandwich::vcovHC(model, type = "HC1")
      se <- sqrt(V[coef_idx, coef_idx])
    } else if (variance_method == "model") {
      se <- summary(model)$coefficients[coef_idx, "Std. Error"]
    }

  } else if (outcome_type == "binary") {
    # Logistic regression for binary outcomes
    if (estimand %in% c("or", "rr")) {
      model <- stats::glm(
        stats::as.formula(formula_str),
        data = ipd,
        family = stats::binomial(link = "logit"),
        weights = w
      )
    } else if (estimand == "rd") {
      model <- stats::glm(
        stats::as.formula(formula_str),
        data = ipd,
        family = stats::binomial(link = "identity"),
        weights = w
      )
    }

    coef_idx <- which(names(stats::coef(model)) == treatment_var)
    estimate <- stats::coef(model)[coef_idx]  # Log OR or RD depending on link

    # Variance
    if (variance_method == "robust") {
      V <- sandwich::vcovHC(model, type = "HC1")
      se <- sqrt(V[coef_idx, coef_idx])
    } else if (variance_method == "model") {
      se <- summary(model)$coefficients[coef_idx, "Std. Error"]
    }

  } else if (outcome_type == "tte") {
    # Cox regression for time-to-event outcomes
    if (is.null(time_var) || is.null(event_var)) {
      cli::cli_abort("time_var and event_var required for TTE outcomes")
    }

    surv_formula <- stats::as.formula(
      paste("survival::Surv(", time_var, ",", event_var, ") ~",
            treatment_var,
            if (!is.null(covariates)) paste("+", paste(covariates, collapse = " + ")) else "")
    )

    model <- survival::coxph(
      surv_formula,
      data = ipd,
      weights = w
    )

    coef_idx <- which(names(stats::coef(model)) == treatment_var)
    estimate <- stats::coef(model)[coef_idx]  # Log HR

    # Variance
    if (variance_method == "robust") {
      V <- sandwich::vcovHC(model, type = "HC1")
      se <- sqrt(V[coef_idx, coef_idx])
    } else if (variance_method == "model") {
      se <- sqrt(stats::vcov(model)[coef_idx, coef_idx])
    }
  }

  # Bootstrap variance if requested
  if (variance_method == "bootstrap") {
    cli::cli_alert_info("Bootstrap variance estimation...")
    boot_fn <- function(data, indices) {
      boot_data <- data[indices, ]
      boot_w <- w[indices]

      if (outcome_type == "continuous") {
        boot_model <- stats::lm(stats::as.formula(formula_str),
                                data = boot_data, weights = boot_w)
      } else if (outcome_type == "binary") {
        boot_model <- stats::glm(stats::as.formula(formula_str),
                                 data = boot_data,
                                 family = stats::binomial(),
                                 weights = boot_w)
      } else {
        boot_model <- survival::coxph(surv_formula, data = boot_data,
                                      weights = boot_w)
      }
      stats::coef(boot_model)[treatment_var]
    }

    boot_result <- boot::boot(ipd, boot_fn, R = nboot)
    se <- stats::sd(boot_result$t, na.rm = TRUE)
  }

  # Confidence interval
  alpha <- 1 - conf_level
  z <- stats::qnorm(1 - alpha/2)
  ci_lower <- estimate - z * se
  ci_upper <- estimate + z * se

  # Create result object
  result <- list(
    estimate = estimate,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    estimand = estimand,
    outcome_type = outcome_type,
    variance_method = variance_method,
    conf_level = conf_level,
    model = model
  )

  class(result) <- "advmaic_ate"
  result
}

#' Print method for advmaic_ate
#' @param x advmaic_ate object
#' @param ... Additional arguments
#' @return Invisible x
#' @export
print.advmaic_ate <- function(x, ...) {
  cat("\n=== MAIC Treatment Effect Estimate ===\n\n")

  estimand_label <- switch(
    x$estimand,
    "rd" = "Risk Difference",
    "rr" = "Log Risk Ratio",
    "or" = "Log Odds Ratio",
    "hr" = "Log Hazard Ratio"
  )

  cat("Estimand:", estimand_label, "\n")
  cat("Outcome type:", x$outcome_type, "\n")
  cat("Variance method:", x$variance_method, "\n\n")

  cat("Estimate:", round(x$estimate, 4), "\n")
  cat("SE:", round(x$se, 4), "\n")
  cat(sprintf("%.0f%% CI: [%.4f, %.4f]\n",
              100 * x$conf_level, x$ci_lower, x$ci_upper))

  # Also show exponentiated estimates for log-scale estimands
  if (x$estimand %in% c("or", "rr", "hr")) {
    cat("\nExponentiated:\n")
    cat(sprintf("  %s: %.4f [%.4f, %.4f]\n",
                toupper(x$estimand),
                exp(x$estimate),
                exp(x$ci_lower),
                exp(x$ci_upper)))
  }

  invisible(x)
}

#' Bucher Indirect Comparison
#'
#' Performs an indirect comparison using the Bucher method to compare
#' treatment B vs C via common comparator A.
#'
#' @param d_AB Treatment effect of B vs A (from MAIC-adjusted IPD).
#' @param var_AB Variance of d_AB.
#' @param d_AC Treatment effect of C vs A (from aggregate data).
#' @param var_AC Variance of d_AC.
#' @param conf_level Confidence level.
#'
#' @return A list of class "advmaic_idc" containing:
#'   \item{d_BC}{Indirect comparison estimate (B vs C)}
#'   \item{se_BC}{Standard error}
#'   \item{ci_lower}{Lower confidence interval}
#'   \item{ci_upper}{Upper confidence interval}
#'   \item{z}{Z-statistic}
#'   \item{p_value}{P-value for test of no difference}
#'
#' @details
#' The Bucher method estimates the indirect comparison as:
#' \deqn{d_{BC} = d_{AC} - d_{AB}}
#'
#' with variance:
#' \deqn{Var(d_{BC}) = Var(d_{AC}) + Var(d_{AB})}
#'
#' assuming independence between the two trial estimates.
#'
#' @references
#' Bucher HC, et al. (1997). The results of direct and indirect treatment
#' comparisons in meta-analysis of randomized controlled trials.
#' J Clin Epidemiol. 50:683-691.
#'
#' @examples
#' \dontrun{
#' # From MAIC analysis of AB trial
#' d_AB <- 0.5  # Log OR of B vs A
#' var_AB <- 0.04
#'
#' # From aggregate data of AC trial
#' d_AC <- 0.3  # Log OR of C vs A
#' var_AC <- 0.03
#'
#' # Indirect comparison
#' result <- bucher_idc(d_AB, var_AB, d_AC, var_AC)
#' print(result)
#' }
#'
#' @export
bucher_idc <- function(d_AB, var_AB, d_AC, var_AC, conf_level = 0.95) {

  # Indirect comparison: d_BC = d_AC - d_AB
  # (C vs A) - (B vs A) = C vs B, but we want B vs C
  # So d_BC = d_AB - d_AC (B vs A - C vs A = B vs C)
  # Or equivalently: d_BC = -(d_AC - d_AB) = d_AB - d_AC

  # Note: Convention matters here. If both d_AB and d_AC are relative to A,

  # then d_BC (B vs C) = d_AB - d_AC
  d_BC <- d_AB - d_AC

  # Variance (assuming independence)
  var_BC <- var_AB + var_AC
  se_BC <- sqrt(var_BC)

  # Confidence interval
  alpha <- 1 - conf_level
  z <- stats::qnorm(1 - alpha/2)
  ci_lower <- d_BC - z * se_BC
  ci_upper <- d_BC + z * se_BC

  # Test statistic and p-value
  z_stat <- d_BC / se_BC
  p_value <- 2 * (1 - stats::pnorm(abs(z_stat)))

  result <- list(
    d_BC = d_BC,
    se_BC = se_BC,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    z = z_stat,
    p_value = p_value,
    conf_level = conf_level,
    d_AB = d_AB,
    var_AB = var_AB,
    d_AC = d_AC,
    var_AC = var_AC
  )

  class(result) <- "advmaic_idc"
  result
}

#' Print method for advmaic_idc
#' @param x advmaic_idc object
#' @param ... Additional arguments
#' @return Invisible x
#' @export
print.advmaic_idc <- function(x, ...) {
  cat("\n=== Bucher Indirect Comparison ===\n\n")

  cat("Input estimates:\n")
  cat(sprintf("  d_AB (B vs A): %.4f (SE: %.4f)\n", x$d_AB, sqrt(x$var_AB)))
  cat(sprintf("  d_AC (C vs A): %.4f (SE: %.4f)\n", x$d_AC, sqrt(x$var_AC)))

  cat("\nIndirect comparison (B vs C):\n")
  cat(sprintf("  Estimate: %.4f\n", x$d_BC))
  cat(sprintf("  SE: %.4f\n", x$se_BC))
  cat(sprintf("  %.0f%% CI: [%.4f, %.4f]\n",
              100 * x$conf_level, x$ci_lower, x$ci_upper))
  cat(sprintf("  z: %.4f, p-value: %.4f\n", x$z, x$p_value))

  invisible(x)
}

#' Full MAIC Analysis Pipeline
#'
#' Conducts a complete MAIC analysis from weight estimation through
#' indirect comparison.
#'
#' @param ipd Data frame containing IPD from the index trial (A vs B).
#' @param agd_target Named numeric vector of target moments from comparator trial.
#' @param agd_effect Treatment effect estimate from comparator trial (C vs A).
#' @param agd_var Variance of treatment effect from comparator trial.
#' @param covariates Character vector of covariate names to balance.
#' @param outcome_var Outcome variable name in IPD.
#' @param treatment_var Treatment variable name in IPD.
#' @param outcome_type Type of outcome.
#' @param estimand Estimand type.
#' @param weight_method Weighting method for estimate_weights.
#' @param variance_method Method for variance estimation.
#' @param ... Additional arguments passed to estimate_weights.
#'
#' @return A list containing weights, ATE, and indirect comparison results.
#'
#' @export
maic_analysis <- function(ipd,
                          agd_target,
                          agd_effect,
                          agd_var,
                          covariates,
                          outcome_var,
                          treatment_var,
                          outcome_type = "binary",
                          estimand = "or",
                          weight_method = "entropy",
                          variance_method = "robust",
                          ...) {

  cli::cli_h1("MAIC Analysis")

  # Step 1: Estimate weights
  cli::cli_alert_info("Step 1: Estimating MAIC weights...")
  weights <- estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = covariates,
    method = weight_method,
    ...
  )
  cli::cli_alert_success("ESS: {round(weights$ess, 1)} ({round(100 * weights$ess / weights$n, 1)}%)")

  # Step 2: Check balance
  cli::cli_alert_info("Step 2: Checking covariate balance...")
  balance <- check_balance(ipd, agd_target, weights, covariates)

  if (balance$all_balanced) {
    cli::cli_alert_success("All covariates balanced")
  } else {
    cli::cli_alert_warning("Max SMD: {round(balance$max_smd, 4)}")
  }

  # Step 3: Estimate treatment effect
  cli::cli_alert_info("Step 3: Estimating treatment effect (B vs A)...")
  ate <- estimate_ate(
    ipd = ipd,
    weights = weights,
    outcome_var = outcome_var,
    treatment_var = treatment_var,
    outcome_type = outcome_type,
    estimand = estimand,
    variance_method = variance_method
  )
  cli::cli_alert_success("d_AB = {round(ate$estimate, 4)} (SE: {round(ate$se, 4)})")

  # Step 4: Indirect comparison
  cli::cli_alert_info("Step 4: Performing indirect comparison...")
  idc <- bucher_idc(
    d_AB = ate$estimate,
    var_AB = ate$se^2,
    d_AC = agd_effect,
    var_AC = agd_var
  )
  cli::cli_alert_success("d_BC = {round(idc$d_BC, 4)} (SE: {round(idc$se_BC, 4)})")

  # Return all results
  list(
    weights = weights,
    balance = balance,
    ate = ate,
    idc = idc
  )
}
