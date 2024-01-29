#  WRF-Hydro <img src=".github/images/wrf_hydro_symbol_logo_2017_09.png" width=100 align="left" />

[![Build Status](https://travis-ci.org/NCAR/wrf_hydro_nwm_public.svg?branch=v5.1.0)](https://travis-ci.org/NCAR/wrf_hydro_nwm_public)
[![Release](https://img.shields.io/github/release/NCAR/wrf_hydro_nwm_public.svg)](https://github.com/NCAR/wrf_hydro_nwm_public/releases/latest)
[![DOI](.github/badges/doi.svg)](https://ezid.cdlib.org/id/doi:10.5065/D6J38RBJ)

## Description
This is the code repository for [WRF-Hydro](https://ral.ucar.edu/projects/wrf_hydro).

WRF-Hydro is a community modeling system and framework for hydrologic modeling and model coupling.  In 2016 a configuration of WRF-Hydro was implemented as the [National Water Model](http://water.noaa.gov/about/nwm) (NWM) for the continental United States.

## Documentation
Documentation can be found on our [project website](https://ral.ucar.edu/projects/wrf_hydro/technical-description-user-guide).

## Resources and Support
For news and updates regarding the WRF-Hydro project please subscribe to our [email list](https://ral.ucar.edu/projects/wrf_hydro/subscribe).

For user support and general inquiries please use our [contact form](https://ral.ucar.edu/projects/wrf_hydro/contact).

If you have found a bug or would like to propose changes to the model code please refer to our [contributing guidelines](.github/CONTRIBUTING.md).

## Contributions
For more information on how to contribute to this project please refer to our [contributing guidelines](.github/CONTRIBUTING.md).

## License
The license and terms of use for this software can be found [here](LICENSE.txt).

## Acknowledgements
Funding support for the development and application of the WRF-Hydro system has been provided by:
- The National Science Foundation and the National Center for Atmospheric Research
- The National Oceanic and Atmospheric Administration (NOAA) Office of Water Prediction (OWP)
- The U.S. National Weather Service (NWS)
- The U.S. Department of Energy (DOE)
- The Colorado Water Conservation Board
- Baron Advanced Meteorological Services
- National Aeronautics and Space Administration (NASA)

 
## UAH Changes
The UAH repository of the model includes two significant updates to the model:
 - A rule-curve based reservoir routing
 - Anthropogenic withdrawal (withdrawals from irrigation, municipalities etc.) at HUC12 level

Sample rule-curve and withdrawal files are provided. The rule curve files contains the reservoir location information in addition to the specified rule-curves and area-capacity data. All elevation data are in meters and volume is in million of cubic meter. Withdrawal files are expressed as mean monthly withdrawals in cubic meter/sec at HUC12 level. Mean withdrawal value can change for each month based on usage. 
