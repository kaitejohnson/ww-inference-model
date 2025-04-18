#' Validate user-provided wastewater concentration data
#'
#' @param ww_data tibble containing the input wastewater data
#' @param conc_col_name string indicating the name of the column containing
#' the concentration measurements in the wastewater data
#' @param lod_col_name string indicating the name of the column containing
#' the limit of detection for each measurement in the wastewater data
#' @param call Calling environment to be passed to [cli::cli_abort()] for
#' traceback.
#'
#' @return NULL, invisibly
validate_ww_conc_data <- function(ww_data,
                                  conc_col_name,
                                  lod_col_name,
                                  call = rlang::caller_env()) {
  assert_df_not_empty(ww_data, arg = "ww_data", call)

  ww_conc <- ww_data |> dplyr::pull({
    conc_col_name
  })
  arg <- conc_col_name
  assert_non_missingness(ww_conc, arg, call,
    add_err_msg =
      c(
        "Package expects that there are no missing",
        " values in wastewater concentration data.",
        "Observations below the limit of detection must",
        " indicate a numeric value less than the limit",
        "of detection"
      )
  )
  checkmate::assert_vector(ww_conc)

  # Check for repeated wastewater observations within a site and lab
  assert_cols_det_unique_row(
    df = ww_data,
    unique_key_columns = c("date", "site", "lab"),
    arg = "lab-site-day",
    add_err_msg =
      c(
        "Package expects either at most one ",
        "wastewater observation per a given a site, lab, ",
        "and sample collection date. Got date(s) with ",
        "more than one observation for a given site and lab."
      )
  )

  ww_lod <- ww_data |> dplyr::pull({
    lod_col_name
  })
  arg <- "lod_col_name"
  assert_non_missingness(ww_lod, arg, call)
  checkmate::assert_vector(ww_lod)

  # Wastewater date column should be of date type!
  ww_obs_dates <- ww_data$date
  arg <- "ww_obs_dates"
  assert_non_missingness(ww_obs_dates, arg, call)
  checkmate::assert_date(ww_obs_dates)

  # Sites  either need to be integers or characters and must not be missing
  site_labels <- ww_data$site
  arg <- "site_labels"
  assert_int_or_char(site_labels, arg, call)
  assert_non_missingness(site_labels, arg, call)

  # Labs either need to be integers or characters, not be missing, and be
  # non-negative
  lab_labels <- ww_data$lab
  arg <- "lab_labels"
  assert_int_or_char(lab_labels, arg, call)
  assert_non_missingness(lab_labels, arg, call)


  # Site populations should be integers, not be missing, and be
  # non-negative
  site_pops <- ww_data$site_pop
  arg <- "site_pops"
  checkmate::assert_integerish(site_pops)
  assert_non_missingness(site_pops, arg, call)
  assert_elements_non_neg(site_pops, arg, call)

  # Check that there are no repeated site populations
  records_per_site_per_pop <- ww_data |>
    dplyr::select("site", "site_pop") |>
    unique() |>
    dplyr::group_by(.data$site) |>
    dplyr::summarize(n = dplyr::n())

  if (any(records_per_site_per_pop$n != 1)) {
    stop(
      "The package expects constant population size per site.",
      "The data contains at least one site with varying population size: ",
      paste0(
        records_per_site_per_pop$site[records_per_site_per_pop$n > 1],
        " (",
        records_per_site_per_pop$n[records_per_site_per_pop$n > 1],
        " records)",
        collapse = ", "
      )
    )
  }


  invisible()
}

#' Validate user-provided count data
#'
#' @param count_data tibble containing the input count data
#' @param count_col_name string indicating the name of the column containing
#' the count data
#' @param pop_size_col_name string indicating the name of the column containing
#' the population size of the count catchment area
#' @param call Calling environment to be passed to [cli::cli_abort()] for
#' traceback.
#'
#' @return NULL, invisibly
validate_count_data <- function(count_data,
                                count_col_name,
                                pop_size_col_name,
                                call = rlang::caller_env()) {
  assert_df_not_empty(count_data, arg = "count_data", call)
  # Count data should be non negative and a vector of integers
  counts <- count_data |> dplyr::pull({
    count_col_name
  })
  arg <- "counts"
  checkmate::assert_vector(counts)
  checkmate::assert_integerish(counts)
  assert_elements_non_neg(counts, arg, call)

  # Right now the model expects daily data! Check that the dates are each day
  assert_daily_data(
    count_data$date,
    add_err_msg =
      c(
        "Count dataset does not appear to be daily.",
        "The current model only supports daily data"
      )
  )

  # Currently, the framework only supports a single population size for
  # an individual model fit. Therefore, check that there are not multiple
  # "global" population sizes being passed in.
  pop <- count_data |> dplyr::pull({
    pop_size_col_name
  })
  arg <- "global_pop"

  checkmate::assert_integerish(pop)
  assert_elements_non_neg(pop)
  assert_non_missingness(pop, arg, call)
  add_err_msg <- paste0(
    "Multiple/time-varying count catchment area populations ",
    "are not currently supported. Check that data is from a ",
    "single location, and if so, consider replacing with an ",
    "average population size over the inference period"
  )
  assert_single_value(pop, arg, call, add_err_msg)


  # Date column should be of date type, for count data, there should only
  # be one observation per day
  count_dates <- count_data$date
  arg <- "count_obs_dates"
  checkmate::assert_date(count_dates)
  add_err_msg <- paste0(
    "Check that data is from a single location, and if so, ",
    "ensure that there are not multiple count data streams"
  )
  assert_no_repeated_elements(count_dates, arg, call, add_err_msg)

  invisible()
}

#' Validate that both count data and wastewater data are coherent and
#' compatible with one another and the the user-specified parameters
#'
#' @param input_count_data tibble containing the input count data that has
#' been filtered and is ready to be passed into stan
#' @param input_ww_data tibble containing the input wastewater data that has
#' been filtered and is ready to be passed into stan
#' @param date_time_spine tibble mapping dates to time in days
#' @param lab_site_site_spine tibble mapping lab-sites to sites
#' @param site_subpop_spine tibble mapping sites to subpopulations
#' @param lab_site_subpop_spine tibble mapping lab-sites to subpopulations
#' @param calibration_time integer indicating the calibration time
#' @param forecast_date IS08 formatted date indicating the forecast date
#'
#' @return NULL, invisibly
validate_data_jointly <- function(input_count_data,
                                  input_ww_data,
                                  date_time_spine,
                                  lab_site_site_spine,
                                  site_subpop_spine,
                                  lab_site_subpop_spine,
                                  calibration_time,
                                  forecast_date) {
  # check that you have sufficient count data for the calibration time
  assert_sufficient_days_of_data(
    input_count_data$date,
    data_name = "input count data",
    calibration_time,
    add_err_msg = c(
      "Check that the count data supplied has sufficient values",
      " before the forecast date"
    )
  )

  assert_elements_non_neg(calibration_time,
    arg = "calibration_time"
  )
  checkmate::assert_integerish(calibration_time)

  # make sure filtering to exclude days before earliest calibration time
  # didn't eliminate
  assert_df_not_empty(input_ww_data,
    add_err_msg = c(
      "There is no wastewater data within ",
      "the count data calibration period"
    )
  )

  # check that the wastewater data has some data within the observed count
  # data
  assert_dates_within_frame(
    input_count_data$date,
    input_ww_data$date,
    forecast_date,
    add_err_msg = c(
      "Wastewater data passed in doesn't overlap",
      "with count data calibration period. ",
      "There must be at least one wastewater ",
      "observation within the date range of the count ",
      "data in order to fit a wastewater-informed model"
    )
  )

  # check that the time and date indices of both datasets line up
  ww_data_sizes <- get_ww_data_sizes(
    input_ww_data
  )

  ww_vals <- get_ww_indices_and_values(
    input_ww_data = input_ww_data,
    date_time_spine = date_time_spine,
    lab_site_site_spine = lab_site_site_spine,
    site_subpop_spine = site_subpop_spine,
    lab_site_subpop_spine = lab_site_subpop_spine
  )

  input_ww_data_w_t <- input_ww_data |>
    dplyr::mutate(t = ww_vals$ww_sampled_times)

  assert_equivalent_indexing(
    input_count_data,
    input_ww_data_w_t,
    arg1 = "count data",
    arg2 = "ww data"
  )

  # Warn if sum(site pops) are greater than total pop.
  # The package can handle this, but warn users that they may have an input
  # data error.
  sum_site_pops <- input_ww_data |>
    dplyr::distinct(.data$site_pop) |>
    sum()
  total_pop <- input_count_data |>
    dplyr::distinct(.data$total_pop)
  if (sum_site_pops > total_pop) {
    cli::cli_warn(c(
      "The sum of the populations in the wastewater catchment areas is ",
      "larger than the total population. While the model supports this ",
      "we advise checking your input data to ensure it is specified ",
      "correctly and to make sure that populations represented by the ",
      "wastewater catchment areas are not overlapping (e.g. if both ",
      " the larger wastewater treatment plant and the upstream manhole ",
      "are included)."
    ))
  }
  invisible()
}

#' Validate that the pmf vector being passed to stan
#' is a valid probability mass function. It must sum to 1 and
#' have all non-negative entries.
#'
#' @param pmf simplex vector describing a probabilty of an event ocurring on
#' each day
#' @param calibration_time integer indicating the calibration time
#' @param count_data tibble containing the input count data ready to be passed
#' to stan
#' @param tolerance numeric indicating the allowable difference between the
#' sum of the pmf and 1, default is `1e-6`
#' @param arg name of the argument supplying the object
#' @param call The calling environment to be reflected in the error message
#' @return NULL, invisibly
validate_pmf <- function(pmf,
                         calibration_time,
                         count_data,
                         tolerance = 1e-6,
                         arg = "x",
                         call = rlang::caller_env()) {
  if (!isTRUE(all.equal(sum(pmf), 1, tolerance = 1e-6))) {
    cli::cli_abort(
      c(
        "{.arg {arg}} does not sum to 1."
      ),
      call = call,
      class = "wwinference_type_error"
    )
  }

  if (length(pmf) > calibration_time || length(pmf) > nrow(count_data)) {
    cli::cli_warn(
      c(
        "Length of {.arg {arg}} is longer than calibration time. Consider",
        " increasing the calibration time. "
      )
    )
  }

  assert_elements_non_neg(pmf,
    add_err_msg = c(
      "Elements in {.arg {arg}} must",
      "be non-negative. Otherwise, ",
      "it is not a valid probability mass function"
    )
  )
  invisible()
}
