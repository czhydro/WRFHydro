!
!***********************************************************************
!
module module_rinfo_def
implicit none

type :: rrinfo
  integer, allocatable, dimension(:) :: ndates
  integer, allocatable, dimension(:,:) :: nmo
  integer, allocatable, dimension(:,:) :: ndy
  real, allocatable, dimension(:,:) :: elev
  real, allocatable, dimension(:,:) :: area_capacity_vol
  real, allocatable, dimension(:,:) :: area_capacity_elev
  real, allocatable, dimension(:) :: celev
  real, allocatable, dimension(:) :: cvol
  real, allocatable, dimension(:) :: dvol
  integer, allocatable, dimension(:) :: area_capacity_npts
  integer, allocatable, dimension(:,:) :: dname_int
  integer, allocatable, dimension(:,:) :: rname_int
  real, allocatable, dimension(:) :: dlat
  real, allocatable, dimension(:) :: dlon
  integer, allocatable, dimension(:) :: simple_rule_curve
  real :: base_elev
  integer, allocatable, dimension(:) :: res_lake_index
  integer, allocatable, dimension(:) :: lake_mpi_index
end type rrinfo

end module module_rinfo_def
!
!***********************************************************************
!
