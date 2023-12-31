#' @title Compute weighted single sample LogFC from normalised logCPM
#'
#' @description Compute weighted single sample logFC for each treated samples
#' using normalized logCPM values. Fit a lowess curve on variances ~ mean of
#' logCPM values, and use it to predict gene-wise weights. The weighted single
#' sample logFC are ready to be used for computing perturbation scores.
#'
#' @details
#'
#' This function computes weighted single-sample logFC (ssFC) from normalised logCPM
#' values, used for computing single-sample perturbation scores.
#'
#' Genes with low expression tend to have larger variances, which will
#' introduce biases to the ssFC computed. Therefore, a lowess curve will be fitted to
#' estimate the relationship between the variances and the mean of logCPM, and
#' the relationship will be used to estimate the variance of each gene-wise mean
#' logCPM value. Gene-wise weights, which are defined to be the inverse of predicted
#' variances that are scaled to have a sum of 1, will then be multiplied to ssFC
#' to down-weight genes with low counts.
#'
#' It is assumed that the genes with extremely low counts have been removed and the
#' count matrix has been normalised prior to the logCPM matrix was derived. Row
#' names of the matrix must be in genes' entrez IDs to align with the fomrat of
#' pathway topology matrices.
#'
#' If a S4 object of \code{DGEList or SummarizedExperiment} is provided as input
#' to `expreMatrix`, the gene expression matrix will be extracted from it and
#' converted to a logCPM matrix. Sample metadata will also be extracted from the
#' same S4 object unless otherwise specified.
#'
#' Provided sample metadata should have the same number of rows as the number of
#' columns in the logCPM matrix and must contain the a column for treatment, one
#' for sample names and a column for how samples should be matched into pairs.
#'
#' The treatment column in the sample metadata must be a factor with the reference
#' level set to be the control condition.
#'
#' @param expreMatrix `matrix` or `data.frame` of logCPM, or `DGEList`/
#' `SummarizedExperiment` storing gene expression counts and sample metadata.
#' Feature names need to be in entrez IDs, and column names need to be sample names
#' @param metadata Sample metadata `data.frame` as described in the details section.
#' @param sampleColumn Name of the column in the `metadata` containing column
#' names of the `expreMatrix`
#' @param treatColumn Name of the column in the `metadata` containing treatment
#' information. The column must be a factor with the reference level set to be
#' the control treatment.
#' @param groupBy Name of the column in the `metadata` containing information
#' for how samples are matched in pairs (eg. patient).
#' @param prefix Character(1). Prefix to be add to the `rownames` of the
#' `expreMatrix`. Default to `ENTREZID:` to align with the format that topology
#' matrices will be retrieved in, but can be adjusted according to users' needs.
#' @importFrom stats approxfun lowess var
#' @return A list with two elements:
#' $weight  gene-wise weights;
#' $weighted_logFC weighted single sample logFC matrix
#' @examples
#' # Inspect metadata data frame to make sure it has treatment, sample
#' # and patient columns
#' data(metadata_example)
#' data(logCPM_example)
#' # Set the treatment column to be a factor where the reference is the control
#' #treatment
#' metadata_example <- dplyr::mutate(metadata_example, treatment = factor(
#'    treatment, levels = c("Vehicle", "E2+R5020", "R5020")))
#' ls <- weight_ss_fc(logCPM_example, metadata = metadata_example,
#'  sampleColumn = "sample", groupBy = "patient", treatColumn = "treatment")
#' @export

setGeneric("weight_ss_fc", function(
        expreMatrix, metadata = NULL, sampleColumn,
        treatColumn, groupBy, prefix = "ENTREZID:")
    standardGeneric("weight_ss_fc"))

#' @rdname weight_ss_fc
setMethod("weight_ss_fc",
          signature = signature(expreMatrix = "matrix"),
          function(
        expreMatrix, metadata = NULL, sampleColumn,
        treatColumn, groupBy, prefix = "ENTREZID:"){
              if (is.null(metadata)|!is.data.frame(metadata))
                  stop("sample metadata must be provided as a data frame")
              ssFC <- .compute_ssFC(expreMatrix, metadata, sampleColumn, treatColumn, groupBy)
              varFC <- apply(expreMatrix, 1, var)
              meanCPM <- apply(expreMatrix, 1, mean)
              l <- lowess(meanCPM, varFC)
              f <- approxfun(l, rule = 2, ties = list("ordered", mean))
              weight <- 1/f(meanCPM)
              scaled_w <- weight/sum(weight)
              rownames(ssFC) <- paste(prefix, rownames(ssFC), sep = "")
              list(
                  weight = scaled_w,
                  weighted_logFC = ssFC * scaled_w
              )
          })

#' @rdname weight_ss_fc
setMethod("weight_ss_fc",
          signature = signature(expreMatrix = "data.frame"),
          function(
        expreMatrix, metadata = NULL, sampleColumn,
        treatColumn, groupBy, prefix = "ENTREZID:"){
              weight_ss_fc(as.matrix(expreMatrix), metadata, sampleColumn, treatColumn, groupBy)

          })

#' @rdname weight_ss_fc
setMethod("weight_ss_fc",
          signature = signature(expreMatrix = "DGEList"),
          function(
        expreMatrix, metadata = NULL, sampleColumn,
        treatColumn, groupBy, prefix = "ENTREZID:"){
              cpm <- cpm(expreMatrix$counts, log = TRUE)
              if(is.null(metadata)){
                  metadata <- expreMatrix$samples
              }
              weight_ss_fc(cpm, metadata, sampleColumn, treatColumn, groupBy)
          })

#' @rdname weight_ss_fc
setMethod("weight_ss_fc",
          signature = signature(expreMatrix = "SummarizedExperiment"),
          function(
        expreMatrix, metadata = NULL, sampleColumn,
        treatColumn, groupBy, prefix = "ENTREZID:"){
              cpm <- cpm(SummarizedExperiment::assay(expreMatrix), log = TRUE)
              if(is.null(metadata)){
                  metadata <- as.data.frame(SummarizedExperiment::colData(expreMatrix))
              }
              weight_ss_fc(cpm, metadata, sampleColumn, treatColumn, groupBy)
          })

#' @title Compute single sample logFCs
#' @param logCPM Matrix of normaslised logCPM
#' @param metadata Sample metadata data frame as described in the details section.
#' @param factor The factor defines how samples can be put into matching pairs.
#' @param control The treatment level that is the control.
#' @importFrom dplyr pull filter
#' @importFrom rlang sym
#' @importFrom magrittr set_colnames
#' @return A matrix of single sample logFC
#' @keywords internal
.compute_ssFC <- function(logCPM, metadata, sampleColumn, treatColumn, groupBy){

    # checks
    if (!all(c(treatColumn, groupBy) %in% colnames(metadata)))
        stop("Sample metadata must include the columns matching the treatColumn and groupBy parameter")
    if (!sampleColumn %in% colnames(metadata))
        stop("Sample metadata does not contain the sample name column specified")
    if (!is.factor(pull(metadata,sym(treatColumn)))|
        length(levels(pull(metadata,sym(treatColumn)))) <2
        ) stop(
        "The specified treatment column must be a factor with at least 2 levels")
    if (!setequal(colnames(logCPM), pull(metadata,sym(sampleColumn))))
        stop("Sample names in the metadaata does not match with logCPM's column names")
    m <- min(logCPM)
    if (is.na(m)) stop("NA values not allowed")

    pairs <- unique(as.character(pull(metadata, sym(groupBy))))

    # extract the base level of the treatment column as the control
    control <- levels(pull(metadata, sym(treatColumn)))[1]

    ls <- lapply(pairs, function(x){
        contrSample <- dplyr::filter(metadata, !!sym(treatColumn) == control, !!sym(groupBy) == x)
        contrSample <- as.character(pull(contrSample, sym(sampleColumn)))
        treatedSample <- dplyr::filter(metadata, !!sym(treatColumn) != control, !!sym(groupBy) == x)
        treatedSample <- as.character(pull(treatedSample, sym(sampleColumn)))

        if (length(treatedSample) == 1){
            set_colnames(as.matrix(logCPM[, treatedSample] - logCPM[, contrSample]), treatedSample)
        } else {
            logCPM[, treatedSample] - logCPM[, contrSample]
        }

        })
    do.call(cbind,ls)


}




