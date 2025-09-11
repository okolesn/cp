#!/usr/bin/env nextflow

/*
 * A simple Nextflow pipeline that reads files from Azure Blob storage
 * and processes each file in parallel on Azure Batch,
 * printing a Hello world message for each file.
 */

nextflow.enable.dsl = 2

params.input_files = params.input_files

// Channel.fromPath("azure://${params.container}/${params.input_files}")
//     .set { input_files }

process RUN_COUNT_LINES {
    tag "{ input_file.getName() }"

    // machineType "Standard_E*d_v5"
    cpus 2
    memory 1.GB

    container 'ubuntu:20.04'

    input:
    tuple val(meta), file(input_file)

    output:
    tuple val(meta), stdout

    script:
    """
    wc -l < ${input_file}
    """
}

process RUN_REPORT {
    publishDir params.outputDir, mode: 'copy'
    
    tag("report")
    container 'ubuntu:20.04'

    input:
    path report, name: "input-report.tsv"

    output:
    path "report.tsv"
    
    script:
    """
    cp ${report} "report.tsv"
    """
}

workflow {
    def input_files = params.input_files.split(',')

    def inputs = Channel.from(input_files)
        .map { [[id: it.toString()], file(it)] }

    inputs.dump(tag: "MAIN: inputs", pretty: true)
    RUN_COUNT_LINES(inputs)
    RUN_COUNT_LINES.out
        .map { it }
        .dump(tag: "MAIN: outputs", pretty: true)
        .map { meta, count -> "${meta.id}\t${count.trim()}\n" }
        .dump(tag: "MAIN: report_lines", pretty: true)
        .collectFile(name: "report.tsv")
        .dump(tag: "MAIN: report_file", pretty: true)
        | RUN_REPORT
}
