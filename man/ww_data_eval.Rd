% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data.R
\docType{data}
\name{ww_data_eval}
\alias{ww_data_eval}
\title{Example evaluation wastewater dataset.}
\format{
\subsection{ww_data_eval}{

A tibble with 126 rows and 6 columns
\describe{
\item{date}{Sample collection date, formatted in ISO8601 standards as
YYYY-MM-DD}
\item{site}{The wastewater treatment plant where the sample was collected}
\item{lab}{The lab where the sample was processed}
\item{log_genome_copies_per_ml_eval}{The natural log of the wastewater
concentration measured on the date specified, collected in the site
specified, and processed in the lab specified. The package expects
this quantity in units of log estimated genome copies per mL.}
\item{log_lod}{The log of the limit of detection in the site and lab on a
particular day of the quantification device (e.g. PCR).  This should be in
units of log estimated genome copies per mL.}
\item{site_pop}{The population size of the wastewater catchment area
represented by the site variable}
\item{location}{ A string indicating the location that all of the
data is coming from. This is not a necessary column, but instead is
included to more realistically mirror a typical workflow}
}
}
}
\source{
vignette_data.R
}
\usage{
ww_data_eval
}
\description{
A dataset containing the simulated retrospective wastewater concentrations
(labeled here as \code{log_genome_copies_per_ml_eval}) by sample collection date
(\code{date}), the site where the sample was collected (\code{site}) and the lab
where the samples were processed (\code{lab}). Additional columns that are
required attributes needed for the model are the limit of detection for
that lab on each day (labeled here as \code{log_lod}) and the population size of
the wastewater catchment area represented by the wastewater concentrations
in each \code{site}.
}
\details{
This data is generated via the default values in the
\code{generate_simulated_data()} function. They represent the bare minumum
required fields needed to pass to the model, and we recommend that users
try to format their own data to match this format.

The variables are as follows:
}
\keyword{datasets}
