## see end of file for some cURL notes

#' Download course materials
#'
#' Special-purpose function to download a folder of course materials. The only
#' demand on the user is to confirm or specify where the new folder should be
#' stored. Workflow:
#' * User executes something like: `use_course("bit.ly/xxx-yyy-zzz")`.
#' * User is asked to notice and confirm the location of the new folder. Specify
#' `destdir` to skip this.
#' * User is asked if they'd like to delete the ZIP file.
#' * If new folder contains an `.Rproj` file, it is opened. Otherwise, the
#' folder is opened in the file manager, e.g. Finder or File Explorer.
#'
#' If `url` has no "http" prefix, "https://" is prepended, allowing for even
#' less typing by the user. Most URL shorteners give HTTPS links and,
#' anecdotally, we note this appears to work with [bit.ly](https://bitly.com/)
#' links, even though they are nominally HTTP.
#'
#' @param url Link to a ZIP file containing the materials, possibly behind a
#'   shortlink. Function developed with DropBox and GitHub in mind, but should
#'   work for ZIP files generally. If no "http" prefix is found, "https://" is
#'   prepended. See [use_course_details] for more.
#' @param destdir The new folder is stored here. Defaults to user's Desktop.
#'
#' @return Path to the new directory holding the course materials, invisibly.
#' @export
#' @family download functions
#' @examples
#' \dontrun{
#' ## bit.ly shortlink example
#' ## should work with and without http prefix
#' use_course("bit.ly/usethis-shortlink-example")
#' use_course("http://bit.ly/usethis-shortlink-example")
#'
#' ## demo with a small CRAN package available in various places
#'
#' ## from CRAN
#' use_course("https://cran.r-project.org/bin/windows/contrib/3.4/rematch2_2.0.1.zip")
#'
#' ## from GitHub, 2 ways
#' use_course("https://github.com/r-lib/rematch2/archive/master.zip")
#' use_course("https://api.github.com/repos/r-lib/rematch2/zipball/master")
#' }
use_course <- function(url, destdir = NULL) {
  url <- normalize_url(url)
  zipfile <- download_zip(
    url,
    destdir = destdir %||% conspicuous_place(),
    pedantic = is.null(destdir) && interactive()
  )
  tidy_unzip(zipfile)
}

#' Download and unpack a ZIP file
#'
#' Details on the two functions that power [use_course()]. These internal
#' functions are currently unexported but a course instructor may want more
#' details.
#'
#' @name use_course_details
#' @family download functions
#' @keywords internal
#'
#' @section download_zip():
#'
#' ```
#' ## function signature
#' download_zip(url, destdir = getwd(), pedantic = FALSE)
#'
#' ## as called inside use_course()
#' download_zip(
#'   url, ## after post-processing with normalize_url()
#'   ## conspicuous_place() = Desktop or home directory or working directory
#'   destdir = destdir \\%||\\% conspicuous_place(),
#'   pedantic = is.null(destdir) && interactive()
#' )
#' ```
#'
#' Special-purpose function to download a ZIP file and automatically determine
#' the file name, which often determines the folder name after unpacking.
#' Developed with DropBox and GitHub as primary targets, possibly via
#' shortlinks. Both platforms offer a way to download an entire folder or repo
#' as a ZIP file, with information about the original folder or repo transmitted
#' in the `Content-Disposition` header. In the absence of this header, a
#' filename is generated from the input URL. In either case, the filename is
#' sanitized. Returns the path to downloaded ZIP file, invisibly.
#'
#' **DropBox:**
#'
#' To make a folder available for ZIP download, create a shared link for it:
#' * <https://www.dropbox.com/help/files-folders/view-only-access>
#'
#' A shared link will have this form:
#' ```
#' https://www.dropbox.com/sh/12345abcde/6789wxyz?dl=0
#' ```
#' Replace the `dl=0` at the end with `dl=1` to create a download link. The ZIP
#' download link will have this form:
#' ```
#' https://www.dropbox.com/sh/12345abcde/6789wxyz?dl=1
#' ```
#' This download link (or a shortlink that points to it) is suitable as input
#' for `download_zip()`. After one or more redirections, this link will
#' eventually lead to a download URL. For more details, see
#' <https://www.dropbox.com/help/desktop-web/force-download> and
#' <https://www.dropbox.com/en/help/desktop-web/download-entire-folders>.
#'
#' **GitHub:**
#'
#' Click on the repo's "Clone or download" button, to reveal a "Download ZIP"
#' button. Capture this URL, which will have this form:
#' ```
#' https://github.com/r-lib/usethis/archive/master.zip
#' ```
#' This download link (or a shortlink that points to it) is suitable as input
#' for `download_zip()`. After one or more redirections, this link will
#' eventually lead to a download URL. Here's an alternative link that also leads
#' to ZIP download, albeit with a different filenaming scheme:
#' ```
#' https://api.github.com/repos/r-lib/usethis/zipball/master
#' ```
#'
#' @param url Download link for the ZIP file, possibly behind a shortlink or
#'   other redirect. See Details.
#' @param destdir Path to existing local directory where the ZIP file will be
#'   stored. Defaults to current working directory, but note that [use_course()]
#'   has different default behavior.
#' @param pedantic Logical. When `TRUE` and in an interactive session, the user
#'   is told where the ZIP file will be stored. If happy, user can elect to
#'   proceed. Otherwise, user can abort and try again with the desired
#'   `destdir`. Intentional friction for a pedagogical setting.
#'
#' @examples
#' \dontrun{
#' download_zip("https://github.com/r-lib/rematch2/archive/master.zip")
#' }
#'
#' @section tidy_unzip():
#'
#' Special-purpose function to unpack a ZIP file and (attempt to) create the
#' directory structure most people want. When unpacking an archive, it is easy
#' to get one more or one less level of nesting than you expected.
#'
#' It's especially important to finesse the directory structure here: we want
#' the same local result when unzipping the same content from either GitHub or
#' DropBox ZIP files, which pack things differently. Here is the intent:
#' * If the ZIP archive `foo.zip` does not contain a single top-level directory,
#' i.e. it is packed as "loose parts", unzip into a directory named `foo`.
#' Typical of DropBox ZIP files.
#' * If the ZIP archive `foo.zip` has a single top-level directory (which, by
#' the way, is not necessarily called "foo"), unpack into said directory.
#' Typical of GitHub ZIP files.
#'
#' Returns path to the directory holding the unpacked files, invisibly.
#'
#' **DropBox:**
#' The ZIP files produced by DropBox are special. The file list tends to contain
#' a spurious directory `"/"`, which we ignore during unzip. Also, if the
#' directory is a Git repo and/or RStudio Project, we unzip-ignore various
#' hidden files, such as `.RData`, `.Rhistory`, and those below `.git/` and
#' `.Rproj.user`.
#'
#' @param zipfile Path to local ZIP file.
#'
#' @examples
#' \dontrun{
#' download_zip("https://github.com/r-lib/rematch2/archive/master.zip")
#' tidy_unzip("rematch2-master.zip")
#' }
NULL

download_zip <- function(url, destdir = getwd(), pedantic = FALSE) {
  stopifnot(is_string(url))
  dl <- curl::curl_fetch_memory(url)

  httr::stop_for_status(dl$status_code)
  check_is_zip(dl)

  cd <- content_disposition(dl)

  base_path <- destdir
  check_is_dir(base_path)
  base_name <- make_filename(cd, fallback = basename(url))

  ## DO YOU KNOW WHERE YOUR STUFF IS GOING?!?
  if (interactive() && pedantic) {
    message(
      "A ZIP file named:\n",
      "  ", value(base_name), "\n",
      "will be downloaded to this folder:\n",
      "  ", value(base_path), "\n",
      "Prefer a different location? Cancel, try again, and specify ",
      code("destdir"), ".\n"
    )
    if (nope("Proceed with this download?")) {
      stop("Aborting download", call. = FALSE)
    }
  }
  full_path <- file.path(base_path, base_name)

  if (!can_overwrite(full_path)) {
    ## TO DO: it pains me that can_overwrite() always strips to basename
    stop("Aborting download", call. = FALSE)
  }

  done(
    "Downloading ZIP file to ",
    if (is.null(destdir)) value(base_name) else value(full_path)
  )
  writeBin(dl$content, full_path)
  invisible(full_path)
}

tidy_unzip <- function(zipfile) {
  filenames <- utils::unzip(zipfile, list = TRUE)[["Name"]]

  ## deal with DropBox's peculiar habit of including "/" as a file --> drop it
  filenames <- filenames[filenames != "/"]

  ## DropBox ZIP files often include lots of hidden R, RStudio, and Git files
  filenames <- filenames[keep_lgl(filenames)]

  td <- top_directory(filenames)
  loose_parts <- is.na(td)

  if (loose_parts) {
    target <- tools::file_path_sans_ext(zipfile)
    utils::unzip(zipfile, files = filenames, exdir = target)
  } else {
    target <- file.path(dirname(zipfile), td)
    utils::unzip(zipfile, files = filenames, exdir = dirname(zipfile))
  }
  done(
    "Unpacking ZIP file into ", value(target),
    " (", length(filenames), " files extracted)"
  )

  if (interactive()) {
    if (yep("Shall we delete the ZIP file ", value(zipfile), "?")) {
      done("Deleting ", value(zipfile))
      unlink(zipfile)
    }

    if (is_rstudio_project(target) && rstudioapi::hasFun("openProject")) {
      done("Opening project in RStudio")
      rstudioapi::openProject(target, newSession = TRUE)
    } else if (!in_rstudio_server()) {
      done("Opening ", value(target), " in the file manager")
      utils::browseURL(normalizePath(target))
    }
  }

  invisible(target)
}

normalize_url <- function(url) {
  stopifnot(is.character(url))
  has_scheme <- grepl("^http[s]?://", url)
  ifelse(has_scheme, url, paste0("https://", url))
}

conspicuous_place <- function() {
  Filter(dir.exists, c(
    file.path(Sys.getenv("HOME"), "Desktop"), # typical macOS = ~/Desktop
    file.path(Sys.getenv("USERPROFILE"), "Desktop"), # typical Windows Desktop
    "~",
    getwd()
  ))[[1]]
}

keep_lgl <- function(file,
                     ignores = c(".Rproj.user", ".rproj.user", ".Rhistory", ".RData", ".git")) {
  ignores <- paste0("((\\/|\\A)", gsub("\\.", "[.]", ignores), "(\\/|\\Z))", collapse = "|")
  !grepl(ignores, file, perl = TRUE)
}

top_directory <- function(filenames) {
  in_top <- dirname(filenames) == "."
  unique_top <- unique(filenames[in_top])
  is_directory <- grepl("/$", unique_top)
  if (length(unique_top) > 1 || !is_directory) {
    NA_character_
  } else {
    unique_top
  }
}

check_is_zip <- function(download) {
  headers <- curl::parse_headers_list(download$headers)
  if (headers[["content-type"]] != "application/zip") {
    stop(
      "Download does not have MIME type ", value("application/zip"), "\n",
      "Instead it's ", value(headers[["content-type"]]), call. = FALSE
    )
  }
  invisible()
}

content_disposition <- function(download) {
  headers <- curl::parse_headers_list(download$headers)
  cd <- headers[["content-disposition"]]
  if (is.null(cd)) {
    return()
  }
  parse_content_disposition(cd)
}

## https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition
## https://tools.ietf.org/html/rfc6266
## DropBox eg: "attachment; filename=\"foo.zip\"; filename*=UTF-8''foo.zip\"
##  GitHub eg: "attachment; filename=foo-master.zip"
parse_content_disposition <- function(cd) {
  if (!grepl("^attachment;", cd)) {
    stop(
      code("Content-Disposition"), " header doesn't start with ",
      value("attachment"), "\n",
      "Actual header: ", value(cd), call. = FALSE
    )
  }

  cd <- sub("^attachment;\\s*", "", cd, ignore.case = TRUE)
  cd <- strsplit(cd, "\\s*;\\s*")[[1]]
  cd <- strsplit(cd, "=")
  stats::setNames(
    vapply(cd, `[[`, character(1), 2),
    vapply(cd, `[[`, character(1), 1)
  )
}

make_filename <- function(cd,
                          fallback = basename(tempfile())) {
  ## TO DO(jennybc): the element named 'filename*' is preferred but I'm not
  ## sure how to parse it yet, so targetting 'filename' for now
  ## https://tools.ietf.org/html/rfc6266
  cd <- cd[["filename"]]
  if (is.null(cd) || is.na(cd)) {
    stopifnot(is_string(fallback))
    return(sanitize_filename(fallback))
  }

  ## I know I could use regex and lookahead but this is easier for me to
  ## maintain
  cd <- sub("^\"(.+)\"$", "\\1", cd)

  sanitize_filename(cd)
}

## replace this with something more robust when exists
## https://github.com/r-lib/fs/issues/32
## in the meantime ...
## 1. take basename
## 2. URL encode it
## 3. Replace remaining obvious no-no's: C0 and C1 control characters, ".",
##    "..", Windows reserved filenames, trailing dot or space (Windows thing)
## 4. Truncate to 255 characters
sanitize_filename <- function(x) {
  x <- vapply(
    basename(x),
    function(z) utils::URLencode(z, reserved = TRUE),
    character(1),
    USE.NAMES = FALSE
  )

  alt <- "_"
  x <- gsub(control_regex, alt, x)
  x <- gsub(unix_reserved_regex, alt, x)
  x <- gsub(windows_reserved_regex, alt, x, ignore.case = TRUE)
  x <- gsub(windows_trailing_regex, alt, x)
  substr(x, start = 1, stop = 255)
}

## R itself will truncate and warn on \x00 = embedded nul, leave it off
control_regex <- "[\x01-\x1f\x80-\x9f]"
unix_reserved_regex <- "^[.]{1,2}$"
## https://msdn.microsoft.com/en-us/library/aa365247.aspx
windows_reserved_regex <- "^(con|prn|aux|nul|com[0-9]|lpt[0-9])([.].*)?$"
windows_trailing_regex <- "[. ]+$"

## https://stackoverflow.com/questions/21322614/use-curl-to-download-a-dropbox-folder-via-shared-link-not-public-link
## lesson: if using cURL, you'd want these options
## -L, --location (follow redirects)
## -O, --remote-name (name local file like the file part of remote name)
## -J, --remote-header-name (tells -O option to consult Content-Disposition
##   instead of the URL)
## https://curl.haxx.se/docs/manpage.html#OPTIONS
