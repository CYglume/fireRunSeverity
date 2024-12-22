
<!-- README.md is generated from README.Rmd. Please edit that file -->

# FireRuns post fire analysis project

<!-- badges: start -->
<!-- badges: end -->

This project aims to analyse the post fire effects and relate the
influence of fire run speed to environmental change.

### Package Requirement

**R Environment**:`FireRuns`, `ecmwfr`

**Python Environment**: `earthengine-api`, `geemap`

## Workflow

<img src="./man/figures/workflow.png" style="width:100.0%"
alt="Image Title" />.

------------------------------------------------------------------------

## Installation

You can install the development version of FireRuns like so:

``` r
# devtools::install_github("AndreaDuane/FireRuns")
```

## Example

`area_process()` will look into the data folder named with `"GIF14_Au"`
to process the fire run calculation. The results are like the following:

``` r
area_process("GIF14_Au")
```

<img src="man/figures/README-example-1.png" width="100%" />
