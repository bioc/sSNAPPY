# Stimulate logCPM matrix for 5 genes and 6 sample
# 6 samples are from 2 patients and 3 treatment levels: Control, Treat1, Treat2

y <- matrix(c(c(1:5, 2:6, 3:7), c(1:5, 2:6, 3:7)+ 0.2), 5, 6)
rownames(y) <- c("7105","8813","57147","55732","2268" )
colnames(y) <- c("patient1_control", "patient1_treat1", "patient1_treat2", "patient2_control", "patient2_treat1", "patient2_treat2")
sample <- colnames(y) %>%
    as.data.frame()
colnames(sample) <- c("sample")
sample <- sample %>%
    dplyr::mutate(
        treatment = vapply(.$sample, function(x){
            stringr::str_split(x, "_")[[1]][2]
        }, character(1)),
        treatment = factor(treatment, levels = c("control", "treat1", "treat2")),
        patient = vapply(.$sample, function(x){
            stringr::str_split(x, "_")[[1]][1]
        }, character(1)))
ssFC <- weight_ss_fc(y, sample, sampleColumn = "sample", groupBy = "patient", treatColumn = "treatment")
pathwayDir <- system.file("extdata", "gsTopology.rda", package = "sSNAPPY")
load(pathwayDir)
# the number of pathways with at least one of those five genes in it
interesectName <- names(gsTopology[lapply(gsTopology, function(x){length(intersect(rownames(ssFC$weighted_logFC),rownames(x)))}) != 0])

# create logCPM matrix with gene_id as rownames (instead of entrezID required)
y_wrongIdentifier <- y
rownames(y_wrongIdentifier) <- c("ENSG00000000003","ENSG00000000419","ENSG00000000457","ENSG00000000460","ENSG00000000938")
ssFC_wrongIdentifier <- weight_ss_fc(y_wrongIdentifier, sample, sampleColumn = "sample", groupBy = "patient", treatColumn = "treatment")


test_that("raw_gene_pert returns error when expected", {
    expect_error(raw_gene_pert(ssFC_wrongIdentifier$weighted_logFC, gsTopology), "None of the expressed gene was matched to pathways. Check if gene identifiers match")
})

notExpressed <- setdiff(unique(unlist(unname(lapply(gsTopology, rownames)))), rownames(ssFC$weighted_logFC))
if (length(notExpressed) != 0){
    # set the FCs of unexpressed pathway genes to 0
    temp <- matrix(0, nrow = length(notExpressed), ncol = ncol(ssFC$weighted_logFC))
    rownames(temp) <- notExpressed
    colnames(temp) <- colnames(ssFC$weighted_logFC)
    # set the weights of unexpressed pathway genes to 0
    ssFC$weighted_logFC <- rbind(ssFC$weighted_logFC, temp)}

ls <- raw_gene_pert( ssFC$weighted_logFC, gsTopology)

test_that("raw_gene_pert produces the expected output",{

    expect_true(is.list(ls))
    # the returned output shouldn't contain any all 0 element
    expect_false(any(sapply(ls, function(x){any(x != 0)}) == FALSE))


    # create an artificial gstopology matrix and FC to test the scoring algorithm
    # row captures downstream where column capture upstream
    test_gs <- matrix(c(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0 , 0, 0, 0, 0, -1, 0, 0), nrow = 5)
    colnames(test_gs) <- LETTERS[1:5]
    rownames(test_gs) <- LETTERS[1:5]
    nd <- apply(test_gs, 1, function(x){sum(x!=0)})
    nd[nd == 0] <-  1
    test_gs <- test_gs/nd
    diag(test_gs) <- diag(test_gs) - 1
    test_FC <-  matrix(
        c(1.2, 0.8, -1, 2, -2),
        ncol = 1
    )
    rownames(test_FC) <- LETTERS[1:5]
    test_genePer <- raw_gene_pert( test_FC, list("GS" = test_gs))
    res <- c(1.2, 1.4, -1.6, 3.4, -0.4)


})

test_that("pathway_pert produces the expected output", {
    output <- pathway_pert(ls, ssFC$weighted_logFC)
    expect_true(setequal(colnames(output), c( "score", "sample","gs_name")))
    expect_false(anyNA(output$score))
    expect_equal(unique(output$sample), stringr::str_subset(sample$sample, "control", negate = TRUE))
    expect_true(length(setdiff(output$gs_name, interesectName)) == 0)
})

# test_that("rank_gene_pert returns error when expected", {
#     expect_error(rank_gene_pert(ls, gsTopology[[1]]), "Pathway topology information missing for some pathways.")
# })
#
# test_that("rank_gene_pert produces the expected output", {
#
#     geneRank <- rank_gene_pert(ls, gsTopology)
#     expect_equal(length(geneRank), length(ls))
#     expect_equal(ncol(geneRank[[1]]), ncol(ssFC$weighted_logFC)+1)
#     # since all non-zero perturbation scores of pathway kegg.Chemokine signaling pathway were positive, expect all rankings to be positives too
#     expect_false(any(geneRank[[1]] < 0))
#
#     # if all gene-wise perturbation scores are changed to negative values, expect all rankings to be negative
#     ls$`kegg.Chemokine signaling pathway` <- (-1)*ls$`kegg.Chemokine signaling pathway`
#     geneRank2 <- rank_gene_pert( ls, gsTopology)
#     expect_false(any(geneRank2[[1]] > 0))
#
#     #
#     # if only one gene's perturbation scores were changed back to positive for all samples, expect only one row in the output with 1 as ranking for all samples
#     # to test that, extract the first 9 rows, which contains 7 rows of all zeros and 2 rows of all negative
#     ls$`kegg.Chemokine signaling pathway` <- ls$`kegg.Chemokine signaling pathway`[1:9,]
#     # change the 9th row to all positive
#     ls$`kegg.Chemokine signaling pathway`[9,] <- abs(ls$`kegg.Chemokine signaling pathway`[9,])
#     geneRank5 <- rank_gene_pert(ls, lapply(gsTopology[c("kegg.Chemokine signaling pathway", "Viral myocarditis" )], function(x)x[1:9, 1:9]))
#     geneRank5 <- geneRank5$`kegg.Chemokine signaling pathway`[,-1]
#     expect_equal(sum(apply(geneRank5, 1, function(y){all(y == 1)})), 1)
#     expect_equal(sum(apply(geneRank5, 1, function(y){all(y == -1)})), 1)
#
#     # extract the first 8 rows, which contains 7 rows of all zeros and one row of all negative
#     ls$`kegg.Chemokine signaling pathway` <- ls$`kegg.Chemokine signaling pathway`[1:8,]
#     geneRank3 <- rank_gene_pert(ls, lapply(gsTopology[c("kegg.Chemokine signaling pathway", "Viral myocarditis" )], function(x)x[1:8, 1:8]))
#     expect_equal(dim(geneRank3$`kegg.Chemokine signaling pathway`), c(1, ncol(ssFC$weighted_logFC) +1))
#     expect_true(all(geneRank3$`kegg.Chemokine signaling pathway`[,-1] == -1))
#
#     # for the only non-zero gene, if the gene-wise perturbation scores for the first and third treated sample are changed to positive,
#     #expect the rank for those two samples become 1
#     ls$`kegg.Chemokine signaling pathway`[8,c(1,3)] <- abs(ls$`kegg.Chemokine signaling pathway`[8,c(1,3)])
#     geneRank4 <- rank_gene_pert(ls, lapply(gsTopology[c("kegg.Chemokine signaling pathway", "Viral myocarditis" )], function(x)x[1:8, 1:8]))
#     expect_equal(dim(geneRank4$`kegg.Chemokine signaling pathway`), c(1, ncol(ssFC$weighted_logFC) +1))
#     expect_equal(unname(unlist(as.vector(geneRank4$`kegg.Chemokine signaling pathway`[1, 2:5]), TRUE)), c(1, -1, 1, -1))
# })

