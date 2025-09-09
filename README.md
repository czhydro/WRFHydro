#  WRF-Hydro <img src=".github/images/wrf_hydro_symbol_logo_2017_09.png" width=100 align="left" />

[![Build Status](https://travis-ci.org/NCAR/wrf_hydro_nwm_public.svg?branch=v5.1.0)](https://travis-ci.org/NCAR/wrf_hydro_nwm_public)
[![Release](https://img.shields.io/github/release/NCAR/wrf_hydro_nwm_public.svg)](https://github.com/NCAR/wrf_hydro_nwm_public/releases/latest)
[![DOI](.github/badges/doi.svg)](https://ezid.cdlib.org/id/doi:10.5065/D6J38RBJ)

## Description
This is the code repository for [WRF-Hydro](https://ral.ucar.edu/projects/wrf_hydro). 

WRF-Hydro is a community modeling system and framework for hydrologic modeling and model coupling.  In 2016 a configuration of WRF-Hydro was implemented as the [National Water Model](http://water.noaa.gov/about/nwm) (NWM) for the continental United States. Documentation can be found on our [project website](https://ral.ucar.edu/projects/wrf_hydro/technical-description-user-guide).


## UAH Changes
The UAH repository of the model includes two significant updates to the model:
 - A rule-curve based reservoir routing
 - Anthropogenic withdrawal (withdrawals from irrigation, municipalities etc.) at HUC12 level

Sample rule-curve and withdrawal files are provided. The rule curve files contains the reservoir location information in addition to the specified rule-curves and area-capacity data. All elevation data are in meters and volume is in million of cubic meter. Withdrawal files are expressed as mean monthly withdrawals in cubic meter/sec at HUC12 level. Mean withdrawal value can change for each month based on usage. 

<img src="https://github.com/czhydro/WRFHydro/blob/UAH/MartinDam.PNG" width="50">
