#' @title Filters supported by CompDb
#'
#' @description
#'
#' A variety of different filters can be applied to the `CompDb` object to
#' retrieve only subsets of the data. These filters extend the
#' [AnnotationFilter::AnnotationFilter] class and support the filtering concepts
#' introduced by Bioconductor's `AnnotationFilter` package.
#'
#' The supported filters are:
#' - `CompoundIdFilter`: filter based on the compound ID.
#' - `CompoundNameFilter`: filter based on the compound name.
#' - `MsmsMzRangeMinFilter`: retrieve entries based on the smallest m/z of all
#'   peaks of their MS/MS spectra. Requires that MS/MS spectra data are present
#'   (i.e. `hasMsMsSpectra(cmp_db)` returns `TRUE`).
#' - `MsmsMzRangeMaxFilter`: retrieve entries based on the largest m/z of all
#'   peaks of their MS/MS spectra. Requires that MS/MS spectra data are present
#'   (i.e. `hasMsMsSpectra(cmp_db)` returns `TRUE`).
#'
#' @param value The value for the filter. For details see
#'     [AnnotationFilter::AnnotationFilter()].
#'
#' @param condition The condition for the filter. For details see
#'     [AnnotationFilter::AnnotationFilter()].
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @name Filter-classes
#'
#' @seealso [supportedFilters()] for the method to list all supported filters
#'     for a `CompDb` object.
#'
#' @examples
#' library(CompoundDb)
#'
#' ## Create a filter for the compound id
#' cf <- CompoundIdFilter("comp_a")
#' cf
#'
#' ## Create a filter using a formula expression
#' AnnotationFilter(~ compound_id == "comp_b")
#'
#' ## Combine filters
#' AnnotationFilterList(CompoundIdFilter("a"), CompoundNameFilter("b"))
#'
#' ## Using a formula expression
#' AnnotationFilter(~ compound_id == "a" | compound_name != "b")
NULL

#' @importClassesFrom AnnotationFilter CharacterFilter AnnotationFilter
#'
#' @exportClass CompoundIdFilter
#'
#' @rdname Filter-classes
setClass("CompoundIdFilter", contains = "CharacterFilter",
         prototype = list(
             condition = "==",
             value = "",
             field = "compound_id"
         ))
#' @export CompoundIdFilter
#'
#' @rdname Filter-classes
CompoundIdFilter <- function(value, condition = "==") {
    new("CompoundIdFilter", value = as.character(value), condition = condition)
}

#' @exportClass CompoundNameFilter
#'
#' @rdname Filter-classes
setClass("CompoundNameFilter", contains = "CharacterFilter",
         prototype = list(
             condition = "==",
             value = "",
             field = "compound_name"
         ))
#' @export CompoundNameFilter
#'
#' @rdname Filter-classes
CompoundNameFilter <- function(value, condition = "==") {
    new("CompoundNameFilter", value = as.character(value),
        condition = condition)
}

#' @importClassesFrom AnnotationFilter DoubleFilter
#'
#' @exportClass MsmsMzRangeMinFilter
#'
#' @rdname Filter-classes
setClass("MsmsMzRangeMinFilter", contains = "DoubleFilter",
         prototype = list(
             condition = ">=",
             value = 0,
             field = "msms_mz_range_min"
         ))
#' @export MsmsMzRangeMinFilter
#'
#' @rdname Filter-classes
MsmsMzRangeMinFilter <- function(value, condition = ">=") {
    new("MsmsMzRangeMinFilter", value = as.numeric(value),
        condition = condition)
}

#' @exportClass MsmsMzRangeMaxFilter
#'
#' @rdname Filter-classes
setClass("MsmsMzRangeMaxFilter", contains = "DoubleFilter",
         prototype = list(
             condition = "<=",
             value = 0,
             field = "msms_mz_range_max"
         ))
#' @export MsmsMzRangeMaxFilter
#'
#' @rdname Filter-classes
MsmsMzRangeMaxFilter <- function(value, condition = "<=") {
    new("MsmsMzRangeMaxFilter", value = as.numeric(value),
        condition = condition)
}

#' @description Returns the field (database column name) for the provided
#'     `AnnotationFilter`. Returns by default the value from `@field` but can
#'     be overwritten if the name differs.
#'
#' @importClassesFrom AnnotationFilter AnnotationFilterList
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @noRd
.field <- function(x) {
    if (is(x, "AnnotationFilterList"))
        unlist(lapply(x, .field), use.names = FALSE)
    else x@field
}

#' @description Utility function to map the condition of an AnnotationFilter
#'     condition to SQL.
#'
#' @param x `AnnotationFilter`.
#'
#' @return A `character(1)` representing the condition for the SQL call.
#'
#' @importMethodsFrom AnnotationFilter condition value
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @noRd
.sql_condition <- function(x) {
    cond <- condition(x)
    if (length(unique(value(x))) > 1) {
        if (cond == "==")
            cond <- "in"
        if (cond == "!=")
            cond <- "not in"
    }
    if (cond == "==")
        cond <- "="
    if (cond %in% c("startsWith", "endsWith", "contains"))
        cond <- "like"
    cond
}

#' @description Single quote character values, paste multiple values and enclose
#'     in quotes.
#'
#' @param x `AnnotationFilter`.
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @noRd
.sql_value <- function(x) {
    vals <- unique(value(x))
    if (is(x, "CharacterFilter")) {
        vals <- paste0("'",
                       gsub(unique(vals), pattern = "'", replacement = "''"),
                       "'")
    }
    if (length(vals) > 1)
        vals <- paste0("(",  paste0(vals, collapse = ","), ")")
    ## Process the like/startsWith/endsWith
    if (condition(x) == "startsWith")
        vals <- paste0("'", unique(x@value), "%'")
    if (condition(x) == "endsWith")
        vals <- paste0("'%", unique(x@value), "'")
    if (condition(x) == "contains")
        vals <- paste0("'%", unique(x@value), "%'")
    vals
}

#' @description Get the logical operator(s) combining `AnnotationFilter` objects
#'     in an `AnnotationFilterList` in SQL format.
#'
#' @param x `AnnotationFilterList`
#'
#' @return `character` with the logical operator(s) in SQL format.
#'
#' @importMethodsFrom AnnotationFilter logicOp
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @noRd
.sql_logicOp <- function(x) {
    vapply(logicOp(x), FUN = function(z) {
        if (z == "&")
            "and"
        else "or"
    }, FUN.VALUE = "", USE.NAMES = FALSE)
}

#' @description Build the where condition from an `AnnotationFilter` or
#'     `AnnotationFilterList`.
#'
#' @details The function recursively calls itself if `x` is an
#'     `AnnotationFilterList`.
#' @param x `AnnotationFilter` or `AnnotationFilterList`.
#'
#' @return `character(1)` with the *where* condition for a given filter (without
#'     `"where"`).
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @noRd
.where_filter <- function(x) {
    if (is(x, "AnnotationFilter"))
        paste(.field(x), .sql_condition(x), .sql_value(x))
    else {
        whrs <- lapply(x, .where_filter)
        log_ops <- .sql_logicOp(x)
        res <- whrs[[1]]
        if (length(x) > 1) {
            ## Combine the elements with the logOp and encapsulate them in ()
            for (i in 2:length(x)) {
                res <- paste(res, log_ops[i-1], whrs[[i]])
            }
            res <- paste0("(", res, ")")
        } else
            res <- whrs[[1]]
        res
    }
}

#' @description Process the 'filter' input parameter to ensure that the expected
#'    type of objects is provided, the submitted filters are supported by the
#'    databse and the result is an `AnnotationFilterList`.
#'
#' @param x filters.
#'
#' @param db `CompDb`.
#'
#' @return `AnnotationFilterList`
#'
#' @importFrom AnnotationFilter AnnotationFilterList AnnotationFilter
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @noRd
.process_filter <- function(x, db) {
    if (is(x, "formula"))
        x <- AnnotationFilter(x)
    if (is(x, "AnnotationFilter"))
        x <- AnnotationFilterList(x)
    if (!is(x, "AnnotationFilterList"))
        stop("'filter' has to be an object excending 'AnnotationFilter', an ",
             "'AnnotationFilterList' or a valid filter expression")
    supp_flts <- .supported_filters(db)
    have_flts <- .filter_class(x)
    got_it <- have_flts %in% supp_flts$filter
    if (any(!got_it))
        stop("Filter(s) ", paste(have_flts[!got_it]), " are not supported")
    x
}


#' @description List supported filters for the database.
#'
#' @param x `CompDb`
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @noRd
.supported_filters <- function(x) {
    df <- data.frame(filter = c("CompoundIdFilter",
                                "CompoundNameFilter"),
                     field = c("compound_id",
                               "compound_name"),
                     stringsAsFactors = FALSE)
    if (!missing(x) && .has_msms_spectra(x)) {
        df <- rbind(df,
                    data.frame(filter = c("MsmsMzRangeMinFilter",
                                          "MsmsMzRangeMaxFilter"),
                               field = c("msms_mz_range_min",
                                         "msms_mz_range_max"),
                               stringsAsFactors = FALSE))
    }
    df[order(df$filter), ]
}

#' @description Get an `AnnotationFilter` class name.
#'
#' @param x `AnnotationFilterList` or `AnnotationFilter`.
#'
#' @author Johannes Rainer
#'
#' @md
#'
#' @noRd
.filter_class <- function(x) {
    if (is(x, "AnnotationFilterList"))
        unlist(lapply(x, .filter_class))
    else class(x)[1]
}
