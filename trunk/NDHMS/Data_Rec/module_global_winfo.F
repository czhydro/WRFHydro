!
!***********************************************************************
!
module module_global_winfo

use module_winfo_def

implicit none
save

!***********************************************************************
!
!  Missing Values

real, parameter :: rmissw = -9999.0
integer, parameter :: imissw = -9999
character ( len = 8 ), parameter :: cmissw = '99999999'

!***********************************************************************
!
!  Logical Units ...

integer, parameter :: lulog = 998

!***********************************************************************

integer :: linkid_min = imissw
integer :: linkid_max = imissw
integer :: jmin_min = imissw
integer :: jmin_max = imissw
integer :: ntmax_winfo = imissw
integer :: linkid_max_winfo = imissw

type (wwinfo) :: winfo

!***********************************************************************

end module
!
!***********************************************************************
!
