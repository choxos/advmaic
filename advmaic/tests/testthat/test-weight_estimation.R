test_that("estimate_weights returns correct structure", {
  set.seed(123)
  n <- 100
  ipd <- data.frame(
    age = rnorm(n, 55, 10),
    male = rbinom(n, 1, 0.6)
  )
  agd_target <- c(age = 60, male = 0.5)

  result <- estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = c("age", "male"),
    method = "entropy"
  )

  expect_s3_class(result, "advmaic_weights")
  expect_length(result$weights, n)
  expect_true(result$ess > 0)
  expect_true(result$ess <= n)
})

test_that("entropy balancing achieves balance", {
  set.seed(456)
  n <- 200
  ipd <- data.frame(
    age = rnorm(n, 55, 10),
    male = rbinom(n, 1, 0.6)
  )
  agd_target <- c(age = 60, male = 0.5)

  result <- estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = c("age", "male"),
    method = "entropy"
  )

  # Check that weighted means match targets
  w <- result$weights
  weighted_age <- sum(w * ipd$age) / sum(w)
  weighted_male <- sum(w * ipd$male) / sum(w)

  expect_equal(weighted_age, agd_target["age"], tolerance = 1e-4)
  expect_equal(weighted_male, agd_target["male"], tolerance = 1e-4)
})

test_that("method of moments equals entropy balancing", {
  set.seed(789)
  n <- 150
  ipd <- data.frame(
    x1 = rnorm(n, 0, 1),
    x2 = rnorm(n, 0, 1)
  )
  agd_target <- c(x1 = 0.5, x2 = -0.3)

  result_eb <- estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = c("x1", "x2"),
    method = "entropy"
  )

  result_mm <- estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = c("x1", "x2"),
    method = "moments"
  )

  # Weights should be equal (Phillippo 2020)
  expect_equal(result_eb$weights, result_mm$weights, tolerance = 1e-6)
})

test_that("ESS calculation is correct for uniform weights", {
  n <- 100
  uniform_weights <- rep(1/n, n)
  ess <- calculate_ess(uniform_weights)
  expect_equal(ess, n, tolerance = 1e-10)
})

test_that("ESS decreases with weight variability", {
  n <- 100

  # Uniform weights
  w1 <- rep(1, n)
  ess1 <- calculate_ess(w1)

  # Variable weights
  w2 <- c(rep(1, 50), rep(5, 50))
  ess2 <- calculate_ess(w2)

  expect_true(ess2 < ess1)
})
