test_that("check_balance identifies perfect balance", {
  set.seed(111)
  n <- 100
  ipd <- data.frame(
    x1 = rnorm(n, 0, 1),
    x2 = rnorm(n, 0, 1)
  )
  agd_target <- c(x1 = 0.5, x2 = -0.3)

  # Get weights that achieve balance
  weights <- estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = c("x1", "x2")
  )

  balance <- check_balance(ipd, agd_target, weights, c("x1", "x2"))

  expect_s3_class(balance, "advmaic_balance")
  expect_true(balance$all_balanced)
  expect_true(balance$max_smd < 0.001)
})

test_that("weight_summary returns correct structure", {
  w <- c(rep(1, 50), rep(2, 50))
  summary <- weight_summary(w)

  expect_type(summary, "list")
  expect_true("ess" %in% names(summary))
  expect_true("ess_pct" %in% names(summary))
  expect_true("min" %in% names(summary))
  expect_true("max" %in% names(summary))
})

test_that("balance_table returns data frame", {
  set.seed(222)
  n <- 100
  ipd <- data.frame(
    age = rnorm(n, 55, 10),
    male = rbinom(n, 1, 0.6)
  )
  agd_target <- c(age = 60, male = 0.5)
  weights <- estimate_weights(ipd, agd_target, c("age", "male"))

  tbl <- balance_table(ipd, agd_target, weights, c("age", "male"))

  expect_s3_class(tbl, "data.frame")
  expect_true("Covariate" %in% names(tbl))
  expect_equal(nrow(tbl), 2)
})
