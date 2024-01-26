!
!***********************************************************************
!
module module_global_rinfo

use module_rinfo_def

implicit none
save

!***********************************************************************
!
!  Missing Values

real, parameter :: rmiss = -9999.0
integer, parameter :: imiss = -9999
character ( len = 8 ), parameter :: cmiss = '99999999'

!***********************************************************************
!
!  Logical Units ...

integer, parameter :: lulog = 999

!***********************************************************************
! Reservoir and HUC Info

integer :: nrmax = 0
integer :: ndmax = 0
integer :: nsmax = 0
integer :: nacmax = 0
integer, parameter :: ncmax = 35

type (rrinfo) :: rinfo

!***********************************************************************
! MPI

integer :: mpi_rule_curve_data

end module
!
!***********************************************************************
!
