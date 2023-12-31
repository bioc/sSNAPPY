% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/genePertScore.R
\name{raw_gene_pert}
\alias{raw_gene_pert}
\title{Compute Gene-wise Perturbation Score}
\usage{
raw_gene_pert(weightedFC, gsTopology)
}
\arguments{
\item{weightedFC}{A matrix of weighted single sample logFCs
derived from function \code{weight_ss_fc()}}

\item{gsTopology}{List of pathway topology matrices generated using function
\code{retrieve_topology()}}
}
\value{
A list where each element is a matrix corresponding to a pathway.
Each column of an element corresponds to a sample, and each row corresponds
to a pathway gene.
}
\description{
Propagate weighted single sample logFCs down the pathway topologies
to compute gene-wise perturbation score per gene per sample per pathway
}
\details{
This function use the algorithm adopted from \code{SPIA} (see citation) to
integrate genes' changes in expression and gene-gene interaction to compute
gene-wise perturbation score per gene per sample per pathway. The rownames of
the weighted single sample logFC matrix and the pathway topology matrices must
use the same type of gene identifier (ie. entrez ID).

Pathways with zero perturbation scores across all genes and samples will be
dropped from the output.
}
\examples{
#compute weighted single sample logFCs
data(metadata_example)
data(logCPM_example)
metadata_example <- dplyr::mutate(metadata_example, treatment = factor(
   treatment, levels = c("Vehicle", "E2+R5020", "R5020")))
ls <- weight_ss_fc(logCPM_example, metadata = metadata_example,
groupBy = "patient", treatColumn = "treatment", sampleColumn = "sample")
# extract all the KEGG pathways
gsTopology <- retrieve_topology(database = "kegg", species = "hsapiens")
# compute raw gene-wise perturbation scores
genePertScore <- raw_gene_pert(ls$weighted_logFC, gsTopology)
}
\references{
Tarca AL, Draghici S, Khatri P, Hassan SS, Mittal P, Kim JS,
Kim CJ, Kusanovic JP, Romero R. A novel signaling pathway impact analysis.
Bioinformatics. 2009 Jan 1;25(1):75-82.
}
