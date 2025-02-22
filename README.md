
<!-- README.md is generated from README.Rmd. Please edit that file -->

# FireRuns post fire analysis project

<!-- badges: start -->
<!-- badges: end -->

This project aims to analyse the post fire effects and relate the
influence of fire run speed to environmental change. The process
comprises two parts of algorithms. In `Data Preparation` we produce fire
runs using algorithms from
[AndreaDuane/FireRuns](https://github.com/AndreaDuane/FireRuns). But we
will use the modified version [Runs2](R/fun/Runs_AllArrows.r) to compare
the fire runs in a wider range.

For severity analysis, the `severityCalc` algorithm calls the Google
Earth Engine API with Python, and stores the output maps on the Google
drive. For `driveDownload` algorithm, the output maps will be downloaded
from the Google drive of the same account.

Later in the `Data Analysis`, fire runs were used to retrieve the
severity pixels on corresponding places, for the comparison with the
other pixels random sampled on the fire perimeter at the same timing.

## Workflow

<img src="./man/figures/workflow.png" style="width:100.0%"
alt="Overview of the workflow" />.

------------------------------------------------------------------------

## Installation

You can install the development version of FireRuns like so:

``` r
# devtools::install_github("AndreaDuane/FireRuns")
```

## Example

`area_process()` will look into the data folder named with `"GIF14_Au"`
to process the fire run calculation. This uses the original version of
algorithm from
[AndreaDuane/FireRuns](https://github.com/AndreaDuane/FireRuns), which
calculates one max run per `FeHo` selected regardless of the amount of
polygons included at a time. The results are like the following:

``` r
area_process("GIF14_Au", do_plot = T)
```

<img src="man/figures/README-example-maxRun-1.png" width="50%" />

The function considers the column `OBJECTID` as unique polygon ID while
`FeHo` as unique timing for calculating fire runs. Therefore you can 1.
modify the data input to select the column with unique values and
correct date time information or 2. change the argument in
`area_process()` or `area_process_allArrow()` as following:

``` r
# area_process("GIF14_Au", nameID_i = "OBJECTID", nameFeho_i = "FeHo")
# area_process_allArrow("GIF14_Au", nameID_i = "OBJECTID", nameFeho_i = "FeHo")
```

`area_process_allArrow()` outputs max runs in all polygons instead of
only one max run in one polygon per `FeHo` selected. This version uses
the modified algorithm [`Runs2()`](R/fun/Runs_AllArrows.r) in this
project. Therefore the analysis can be conducted on each polygon with
valid max fire run.

``` r
area_process_allArrow("GIF14_Au", do_plot = T)
```

<img src="man/figures/README-example-allRun-1.png" width="50%" />
