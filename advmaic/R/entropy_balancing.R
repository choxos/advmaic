#' @title Entropy Balancing Implementation
#' @name entropy_balancing
#' @description Core entropy balancing optimization algorithm for MAIC.
NULL

#' Entropy Balancing Optimization
#'
#' Estimates weights by minimizing divergence from base weights subject to
#' moment balance constraints. This implements the dual formulation using
#' Lagrange multipliers.
#'
#' @param C Constraint matrix (n x p) where each column represents a constraint.
#'   Typically constructed as (X - target) for mean constraints.
#' @param base_weights Numeric vector of base weights (must sum to 1).
#' @param loss_function Character string specifying the loss function.
#' @param gamma Numeric parameter for Cressie-Read divergence.
#' @param max_iter Maximum number of iterations.
#' @param tol Convergence tolerance.
#' @param verbose Logical. If TRUE, print progress.
#'
#' @return List containing:
#'   \item{weights}{Estimated weights (normalized to sum to 1)}
#'   \item{alpha}{Estimated Lagrange multipliers}
#'   \item{convergence}{List with convergence information}
#'
#' @details
#' The entropy balancing problem is:
#' \deqn{\min_{w} D(w || w^{(0)}) \quad \text{s.t.} \quad \sum_i w_i C_{ik} = 0, \quad \sum_i w_i = 1}
#'
#' For entropy (Kullback) divergence, this has a closed-form solution:
#' \deqn{w_i = \frac{w_i^{(0)} \exp(x_i^T \alpha)}{\sum_j w_j^{(0)} \exp(x_j^T \alpha)}}
#'
#' The dual problem minimizes:
#' \deqn{H(\alpha) = \log\left(\sum_i w_i^{(0)} \exp(C_i^T \alpha)\right)}
#'
#' @references
#' Hainmueller J. (2012). Entropy balancing for causal effects. Political Analysis.
#'
#' @examples
#' \dontrun{
#' # Simple example
#' n <- 100
#' X <- matrix(rnorm(n * 2), n, 2)
#' target <- c(0.5, -0.3)
#' C <- sweep(X, 2, target, "-")
#' base_weights <- rep(1/n, n)
#'
#' result <- entropy_balance(C, base_weights)
#' }
#'
#' @export
entropy_balance <- function(C,
                            base_weights,
                            loss_function = c("entropy", "empirical_likelihood", "cressie_read"),
                            gamma = 0,
                            max_iter = 1000,
                            tol = 1e-8,
                            verbose = FALSE) {

  loss_function <- match.arg(loss_function)

  C <- as.matrix(C)
  n <- nrow(C)
  p <- ncol(C)

  # Validate inputs
  if (length(base_weights) != n) {
    cli::cli_abort("base_weights must have length {n}")
  }

  # Normalize base weights
  base_weights <- base_weights / sum(base_weights)

  # Initialize alpha (Lagrange multipliers)
  alpha <- rep(0, p)

  # Choose optimization method based on loss function
  if (loss_function == "entropy" || (loss_function == "cressie_read" && gamma == 0)) {
    result <- eb_optimize_entropy(C, base_weights, alpha, max_iter, tol, verbose)
  } else if (loss_function == "empirical_likelihood" || (loss_function == "cressie_read" && gamma == -1)) {
    result <- eb_optimize_el(C, base_weights, alpha, max_iter, tol, verbose)
  } else if (loss_function == "cressie_read") {
    result <- eb_optimize_cr(C, base_weights, alpha, gamma, max_iter, tol, verbose)
  }

  result
}

#' Entropy Balancing with Entropy (Kullback) Divergence
#'
#' Uses Newton-Raphson optimization with line search for the dual problem.
#'
#' @keywords internal
eb_optimize_entropy <- function(C, base_weights, alpha, max_iter, tol, verbose) {
  # Implementation following Phillippo et al. (2020) with logSumExp for stability

  n <- nrow(C)
  p <- ncol(C)

  converged <- FALSE
  iteration <- 0
  grad_norm <- Inf

  for (iter in seq_len(max_iter)) {
    iteration <- iter

    # Compute linear predictor
    lin_pred <- as.vector(C %*% alpha)

    # Compute weights using logSumExp for numerical stability (Phillippo 2020)
    # For uniform base weights: w_i = exp(x_i' alpha) / sum(exp(x_j' alpha))
    # For non-uniform: w_i = w0_i * exp(x_i' alpha) / sum(w0_j * exp(x_j' alpha))
    log_w_unnorm <- lin_pred + log(base_weights)
    log_Z <- matrixStats::logSumExp(log_w_unnorm)
    w <- exp(log_w_unnorm - log_Z)

    # Gradient: E_w[C] = C^T w (same as Phillippo gradfn_eb0)
    grad <- as.vector(crossprod(C, w))

    # Check convergence
    grad_norm <- sqrt(sum(grad^2))
    if (verbose && iter %% 10 == 0) {
      cli::cli_alert_info("Iteration {iter}: gradient norm = {round(grad_norm, 8)}")
    }

    if (grad_norm < tol) {
      converged <- TRUE
      break
    }

    # Hessian: Var_w[C] = C^T diag(w) C - (C^T w)(C^T w)^T
    Cw <- sweep(C, 1, sqrt(w), "*")
    H <- crossprod(Cw) - tcrossprod(grad)

    # Add small ridge for numerical stability
    H <- H + diag(1e-10, p)

    # Newton direction
    direction <- tryCatch(
      solve(H, -grad),
      error = function(e) {
        # Fall back to gradient descent if Hessian is singular
        -grad / max(abs(grad))
      }
    )

    # Line search with backtracking
    step_size <- 1
    obj_current <- log_Z

    for (ls_iter in 1:20) {
      alpha_new <- alpha + step_size * direction
      lin_pred_new <- as.vector(C %*% alpha_new)
      log_w_unnorm_new <- lin_pred_new + log(base_weights)
      log_Z_new <- matrixStats::logSumExp(log_w_unnorm_new)

      if (log_Z_new < obj_current - 1e-4 * step_size * sum(grad * direction)) {
        break
      }
      step_size <- step_size * 0.5
    }

    alpha <- alpha + step_size * direction
  }

  # Final weights
  lin_pred <- as.vector(C %*% alpha)
  log_w_unnorm <- lin_pred + log(base_weights)
  log_Z <- matrixStats::logSumExp(log_w_unnorm)
  w <- exp(log_w_unnorm - log_Z)

  list(
    weights = w,
    alpha = alpha,
    convergence = list(
      converged = converged,
      iterations = iteration,
      gradient_norm = grad_norm,
      message = if (converged) "Converged" else "Maximum iterations reached"
    )
  )
}

#' Entropy Balancing with Empirical Likelihood
#'
#' Uses Newton-Raphson for empirical likelihood (gamma = -1 in CR divergence).
#'
#' @keywords internal
eb_optimize_el <- function(C, base_weights, alpha, max_iter, tol, verbose) {

  n <- nrow(C)
  p <- ncol(C)

  converged <- FALSE
  iteration <- 0

  for (iter in seq_len(max_iter)) {
    iteration <- iter

    # For empirical likelihood: w_i proportional to base_weights_i / (1 - C_i' alpha)
    lin_pred <- as.vector(C %*% alpha)

    # Ensure feasibility: 1 - lin_pred > 0
    if (any(lin_pred >= 1)) {
      # Scale alpha to ensure feasibility
      max_pred <- max(lin_pred)
      if (max_pred >= 1) {
        alpha <- alpha * 0.9 / max_pred
        lin_pred <- as.vector(C %*% alpha)
      }
    }

    denom <- 1 - lin_pred
    w_unnorm <- base_weights / denom
    Z <- sum(w_unnorm)
    w <- w_unnorm / Z

    # Gradient
    grad <- as.vector(crossprod(C, w))

    # Check convergence
    grad_norm <- sqrt(sum(grad^2))
    if (verbose && iter %% 10 == 0) {
      cli::cli_alert_info("Iteration {iter}: gradient norm = {round(grad_norm, 8)}")
    }

    if (grad_norm < tol) {
      converged <- TRUE
      break
    }

    # Hessian for EL
    w_sq <- w / denom
    Cwsq <- sweep(C, 1, sqrt(w_sq), "*")
    H <- crossprod(Cwsq)
    H <- H + diag(1e-10, p)

    # Newton direction
    direction <- tryCatch(
      solve(H, -grad),
      error = function(e) -grad / max(abs(grad))
    )

    # Line search
    step_size <- 1
    for (ls_iter in 1:20) {
      alpha_new <- alpha + step_size * direction
      lin_pred_new <- as.vector(C %*% alpha_new)

      if (all(lin_pred_new < 1)) {
        denom_new <- 1 - lin_pred_new
        w_unnorm_new <- base_weights / denom_new
        grad_new <- as.vector(crossprod(C, w_unnorm_new / sum(w_unnorm_new)))
        if (sqrt(sum(grad_new^2)) < grad_norm) {
          break
        }
      }
      step_size <- step_size * 0.5
    }

    alpha <- alpha + step_size * direction
  }

  # Final weights
  lin_pred <- as.vector(C %*% alpha)
  denom <- 1 - lin_pred
  w_unnorm <- base_weights / denom
  w <- w_unnorm / sum(w_unnorm)

  list(
    weights = w,
    alpha = alpha,
    convergence = list(
      converged = converged,
      iterations = iteration,
      gradient_norm = grad_norm,
      message = if (converged) "Converged" else "Maximum iterations reached"
    )
  )
}

#' Entropy Balancing with Cressie-Read Divergence
#'
#' General Cressie-Read divergence optimization using numerical methods.
#'
#' @keywords internal
eb_optimize_cr <- function(C, base_weights, alpha, gamma, max_iter, tol, verbose) {

  n <- nrow(C)
  p <- ncol(C)

  # For general gamma, use nloptr for optimization
  # The dual objective function depends on gamma

  # Objective function (dual problem)
  obj_fn <- function(alpha) {
    lin_pred <- as.vector(C %*% alpha)

    if (gamma == 0) {
      # Entropy case
      exp_lin <- exp(lin_pred - max(lin_pred))
      Z <- sum(base_weights * exp_lin)
      return(log(Z) + max(lin_pred))
    } else if (gamma == -1) {
      # Empirical likelihood
      if (any(lin_pred >= 1)) return(1e10)
      return(-sum(base_weights * log(1 - lin_pred)))
    } else {
      # General Cressie-Read
      # w_i proportional to base_weights_i * (1 + gamma * lin_pred_i)^(1/gamma)
      inner <- 1 + gamma * lin_pred
      if (any(inner <= 0)) return(1e10)
      w_unnorm <- base_weights * inner^(1/gamma)
      if (gamma > 0) {
        return(sum(w_unnorm) / (1 + gamma))
      } else {
        return(-sum(base_weights * inner^((1 + gamma)/gamma)) / (1 + gamma))
      }
    }
  }

  # Gradient function
  grad_fn <- function(alpha) {
    lin_pred <- as.vector(C %*% alpha)

    if (gamma == 0) {
      exp_lin <- exp(lin_pred - max(lin_pred))
      w_unnorm <- base_weights * exp_lin
      w <- w_unnorm / sum(w_unnorm)
      return(as.vector(crossprod(C, w)))
    } else if (gamma == -1) {
      denom <- 1 - lin_pred
      w_unnorm <- base_weights / denom
      w <- w_unnorm / sum(w_unnorm)
      return(as.vector(crossprod(C, w)))
    } else {
      inner <- 1 + gamma * lin_pred
      w_unnorm <- base_weights * inner^(1/gamma)
      w <- w_unnorm / sum(w_unnorm)
      return(as.vector(crossprod(C, w)))
    }
  }

  # Use nloptr for optimization
  result <- nloptr::nloptr(
    x0 = alpha,
    eval_f = obj_fn,
    eval_grad_f = grad_fn,
    opts = list(
      algorithm = "NLOPT_LD_LBFGS",
      maxeval = max_iter,
      ftol_rel = tol,
      print_level = if (verbose) 1 else 0
    )
  )

  # Compute final weights
  alpha <- result$solution
  lin_pred <- as.vector(C %*% alpha)

  if (gamma == 0) {
    exp_lin <- exp(lin_pred - max(lin_pred))
    w_unnorm <- base_weights * exp_lin
  } else if (gamma == -1) {
    w_unnorm <- base_weights / (1 - lin_pred)
  } else {
    inner <- 1 + gamma * lin_pred
    w_unnorm <- base_weights * inner^(1/gamma)
  }
  w <- w_unnorm / sum(w_unnorm)

  list(
    weights = w,
    alpha = alpha,
    convergence = list(
      converged = result$status %in% c(1, 3, 4),
      iterations = result$iterations,
      gradient_norm = sqrt(sum(grad_fn(alpha)^2)),
      message = result$message
    )
  )
}

#' Method of Moments Estimation
#'
#' Estimates weights using the method of moments approach. This is mathematically
#' equivalent to entropy balancing for uniform base weights (Phillippo 2020).
#'
#' @param C Constraint matrix (n x p).
#' @param base_weights Base weights.
#' @param max_iter Maximum iterations.
#' @param tol Convergence tolerance.
#' @param verbose Print progress.
#'
#' @return List with weights, alpha, and convergence info.
#'
#' @details
#' The method of moments finds alpha such that:
#' \deqn{\sum_i w_i^{(0)} \exp(C_i^T \alpha) C_i = 0}
#'
#' @export
method_of_moments <- function(C, base_weights, max_iter = 1000, tol = 1e-8,
                              verbose = FALSE) {

  # Method of moments is equivalent to entropy balancing for the primal
  # Using the same optimization routine
  eb_optimize_entropy(C, base_weights, rep(0, ncol(C)), max_iter, tol, verbose)
}
