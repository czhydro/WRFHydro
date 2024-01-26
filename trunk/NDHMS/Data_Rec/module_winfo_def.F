!
!***********************************************************************
!
module module_winfo_def
implicit none

type :: wwinfo
  integer, allocatable, dimension(:) :: jmin_store
  integer, allocatable, dimension(:,:) :: linkid
  real, allocatable, dimension(:,:) :: demand
end type wwinfo

end module module_winfo_def
!
!***********************************************************************
!
