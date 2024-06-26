#' Query awards from the Bill & Melinda Gates Foundation
#' @inheritParams get_ssrc
#' @return a data.frame
#' @export
#' @examples
#' gates <- get_gates("qualitative", 2018, 2020)
get_gates <- function(keyword, from_year, to_year, verbose=FALSE) {
 base_url <- "https://www.gatesfoundation.org/api/grantssearch"

 params <- paste0("?date&displayedTaxonomy&",
 "listingId=d2a41504-f557-4f1e-88d6-ea109d344feb",
 "&loadAllPages=false",
 "&pageId=31242fca-dcf8-466a-a296-d6411f85b0a5&perPage=999")

 params <- paste0(params, "&q=", xml2::url_escape(keyword),
                  "&sc_site=gfo&showContentTypes=false&showDates=false",
                  "&showImages&showSummaries=false&sortBy=date-desc",
                  "&sortOrder=desc")

 params <- paste0(params, "&yearAwardedEnd=", to_year,
                  "&yearAwardedStart=", from_year)

 page <- 1
 page_params <- paste0(params, "&page=", page)

 page_url <- paste0(base_url, page_params)

 response <- request(page_url, "get", verbose)

 # Did we get HTML back?
 if (class(response)[1]=="xml_document") {
    return(NULL)
 }

 # Count total results
 total_results <- response$totalResults

 # No results?
 if (total_results==0) {
    return(NULL)
 }

 all_results <- response$results

 while (length(all_results) < total_results) {
   page <- page + 1
   page_params <- paste0(params, "&page=", page)
   page_url <- paste0(base_url, page_params)
   response <- request(page_url, "get", verbose)
   all_results <- c(all_results, response$results)
   Sys.sleep(3) # Be NICE to the API!
 }
 df <- lapply(all_results, function(x) {
   x <- unlist(x, recursive=FALSE)
   with(x, data.frame(
      awardedAmount, grantee, url, date, id,
      stringsAsFactors = FALSE))
 })
 df <- do.call(rbind.data.frame, df)

 df$grantee[df$grantee==""] <- NA
 # Get rid of all the $ and commas
 df$awardedAmount <- gsub("^\\$|,", "", df$awardedAmount)
 df$year <- .substr_right(df$date, 4)
 df$keyword <- keyword

 df
}

.standardize_gates <- function(keywords, from_date, to_date, verbose) {
   raw <- lapply(keywords, get_gates,
                 format.Date(from_date, "%Y"), format.Date(to_date, "%Y"),
                 verbose)
   raw <- do.call(rbind.data.frame, raw)
   if (nrow(raw)==0) {
      message("No results from Gates")
      return(NULL)
   }

   with(raw, data.frame(
      institution=grantee, pi=NA, year, start=NA, end=NA,
      program=NA, amount=awardedAmount, id=url, title=NA, abstract=NA,
      keyword, source="Gates", stringsAsFactors = FALSE
   ))
}
