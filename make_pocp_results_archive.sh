#! /usr/bin/env bash
FAMILY_DIR=$(basename ${1})
SHORTLIST=${FAMILY_DIR//benchmark-gtdb-}
echo "Looking up $FAMILY_DIR and $SHORTLIST"
zip $FAMILY_DIR ${FAMILY_DIR}/proteins_statistics.tsv ${FAMILY_DIR}/pipeline_info/execution_trace_* ${FAMILY_DIR}/pipeline_info/execution_report_* ${FAMILY_DIR}/compare_pocp/blast-vs-all-pocpu-r2.csv ${FAMILY_DIR}/compare_pocp/blast-vs-all-pocp-r2.csv ${FAMILY_DIR}/compare_pocp/plot* ${FAMILY_DIR}/eval_genus_delineation/evaluate_genus_delineation.csv ${FAMILY_DIR}/eval_genus_delineation/counts-evaluate_genus_delineation.csv benchmark-gtdb/split_per_family/${SHORTLIST}.csv ${FAMILY_DIR}/eval_genus_delineation/comparisons_classification_pocp_rand.csv
