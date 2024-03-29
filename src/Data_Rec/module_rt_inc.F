module module_rt_inc
   use overland_data
   use module_subsurface_data
   use module_subsurface_static_data
   use module_subsurface_input
   use module_subsurface_output
   use module_reservoir, only: reservoir_container
   use iso_fortran_env, only: int64
   implicit none

   TYPE RT_FIELD
   type (overland_struct) :: overland
   type (subsurface_struct) :: subsurface
   type (subsurface_static_interface) :: subsurface_static
   type (subsurface_input_interface) :: subsurface_input
   type (subsurface_output_interface) :: subsurface_output

   class (reservoir_container), allocatable, dimension(:) :: reservoirs
   integer, allocatable, dimension(:) :: reservoir_type ! specifying type of reservoir
   integer, allocatable, dimension(:) :: final_reservoir_type   ! resolved reservoir type (since it can change)
   real, allocatable, dimension(:) :: reservoir_assimilated_value ! observation or forecast assimilated to reservoir discharge
   character(len=256), allocatable, dimension(:) :: reservoir_assimilated_source_file ! source file of assimilated value

   INTEGER :: IX, JX
   logical :: initialized
   logical :: restQSTRM
  REAL    :: DX,GRDAREART,SUBFLORT,WATAVAILRT,QSUBDRYRT
  !REAL    :: SFHEAD1RT,INFXS1RT,QSTRMVOLTRT,QBDRYTRT,SFHEADRT,ETPND1,INFXSRTOT
  REAL    :: SFHEAD1RT,INFXS1RT,SFHEADRT,ETPND1,INFXSRTOT
  !REAL    :: LAKE_INFLOTRT,accsuminfxs,diffsuminfxs,RETDEPFRAC
  REAL    :: accsuminfxs,diffsuminfxs,RETDEPFRAC
  REAL    :: VERTKSAT,l3temp,l4temp,l3moist,l4moist,RNOF1TOT,RNOF2TOT,RNOF3TOT
  INTEGER :: IXRT,JXRT,vegct
  INTEGER :: AGGFACYRT, AGGFACXRT, KRTel_option, FORC_TYP
  INTEGER :: SATLYRCHKRT,DT_FRACRT
  INTEGER ::  LAKE_CT, STRM_CT
  REAL                                 :: RETDEP_CHAN  ! Channel retention depth
  INTEGER :: NLINKS  !maximum number of unique links in channel
  INTEGER :: GNLINKS  !maximum number of unique links in channel for parallel computation
  INTEGER :: NLAKES !number of lakes modeled
  INTEGER :: NLINKSL !maximum number of links using linked routing
  INTEGER :: MAXORDER !maximum stream order
  integer :: timestep_flag    ! 1 cold start run else continue run

  INTEGER :: GNLINKSL, linklsS, linklsE , nlinksize  !## for reach based channel routing

  INTEGER :: iswater     !id for water in vegtyp
  INTEGER :: islake      !id for lake in vegtyp
  INTEGER :: isurban     !id for urban in vegtyp
  INTEGER :: isoilwater  !id for water in soiltyp

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!DJG   VARIABLES FOR ROUTING
  !INTEGER, allocatable, DIMENSION(:,:)      :: CH_NETRT !-- keeps track of the 0-1 channel network ! moved to overland%streams_and_lakes
  INTEGER(kind=int64), allocatable, DIMENSION(:,:)      :: CH_LNKRT !-- linked routing grid (should combine with CH_NETRT.. redundant Gochis!)


  INTEGER(kind=int64), allocatable, DIMENSION(:,:)      :: CH_NETLNK, GCH_NETLNK !-- assigns a unique value to each channel gridpoint, called links
  REAL,    allocatable, DIMENSION(:,:)      :: LATVAL,LONVAL !-- lat lon
  REAL,    allocatable, DIMENSION(:,:)      :: TERRAIN
  REAL,    allocatable, DIMENSION(:,:)      :: landRunOff   ! used for NHDPLUS only
  REAL, allocatable,    DIMENSION(:)        :: CHLAT,CHLON   !  channel lat and lon
  ! INTEGER, allocatable, DIMENSION(:,:)    :: LAKE_MSKRT, BASIN_MSK,LAK_1K
  INTEGER, allocatable, DIMENSION(:,:)      :: LAK_1K
  INTEGER, allocatable, DIMENSION(:,:)      :: g_LAK_1K
  ! REAL,    allocatable, DIMENSION(:,:)      :: ELRT,SOXRT,SOYRT,OVROUGHRT,RETDEPRT, QSUBBDRYTRT
  !REAL :: QSUBBDRYTRT    ! QSUBBDRYTRT moved to subsurface io module
  !REAL,    allocatable, DIMENSION(:,:)      :: ELRT,SOXRT,SOYRT,OVROUGHRT,RETDEPRT
  REAL,    allocatable, DIMENSION(:,:)      :: ELRT
  !REAL,    allocatable, DIMENSION(:,:,:)    :: SO8RT
  INTEGER,    allocatable, DIMENSION(:,:,:) ::  SO8LD_D ! SO8RT_D moved to overland properties module
  REAL,    allocatable, DIMENSION(:,:)      :: SO8LD_Vmax
  REAL   Vmax
  !REAL,    allocatable, DIMENSION(:,:)      :: LKSATRT !  LKSATRT moved to subsurface properties module
  !REAL,    allocatable, DIMENSION(:,:)      :: SFCHEADRT,INFXSRT,LKSAT  ! SFCHEAD moved to overland control module
  REAL,    allocatable, DIMENSION(:,:)      :: INFXSRT,LKSAT,LKSATRT
  !REAL,    allocatable, DIMENSION(:,:)      :: SFCHEADSUBRT,INFXSUBRT,LKSATFAC  ! SFCHEADSUBRT, INFXSUBRT moved to overland control module
  REAL,    allocatable, DIMENSION(:,:)      :: LKSATFAC
  REAL,    allocatable, DIMENSION(:,:)      :: IMPERVFRAC
  !REAL,    allocatable, DIMENSION(:,:)      :: SOLDEPRT ! QSUBRT, QSUBBDRYRT moved to subsurface io module, SOLDEPRT, ZWATTABLRT move to susurface properties
  REAL,    allocatable, DIMENSION(:,:)      :: SUB_RESID
  REAL,    allocatable, DIMENSION(:,:)      :: q_sfcflx_x,q_sfcflx_y
  INTEGER,    allocatable, DIMENSION(:)      :: map_l2g, map_g2l

  INTEGER :: nToInd
  INTEGER,    allocatable, DIMENSION(:)      :: toNodeInd
  INTEGER(kind=int64),    allocatable, DIMENSION(:,:)      :: gtoNode

! temp arrary cwatavail
  !real, allocatable, DIMENSION(:,:,:)      :: SMCREFRT  ! SMCREFRT moved to subsurface grid_transform module
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!DJG   VARIABLES FOR GW/Baseflow
  INTEGER :: numbasns
  INTEGER :: gnumbasns
  integer(kind=int64), allocatable, dimension(:)     :: basnsInd ! basin index for tile
  INTEGER, allocatable, DIMENSION(:,:)   :: GWSUBBASMSK  !GW basin mask grid
  REAL,    allocatable, DIMENSION(:,:)   :: qinflowbase  !strm inflow/baseflow from GW
  REAL,    allocatable, DIMENSION(:,:)   :: SOLDRAIN     !time-step drainage
  INTEGER, allocatable, DIMENSION(:,:)   :: gw_strm_msk  !GW basin mask grid
  INTEGER, allocatable, DIMENSION(:,:)   :: gw_strm_msk_lind  !GW basin mask grid tile maping index
  REAL,    allocatable, DIMENSION(:)     :: z_gwsubbas   !depth in GW bucket
  REAL,    allocatable, DIMENSION(:)     :: qin_gwsubbas !flow to GW bucket
  REAL,    allocatable, DIMENSION(:)     :: qout_gwsubbas!flow from GW bucket
  REAL,    allocatable, DIMENSION(:)     :: qloss_gwsubbas   !flow from GW bucket
  REAL,    allocatable, DIMENSION(:)     :: gwbas_pix_ct !ct of strm pixels in
  REAL,    allocatable, DIMENSION(:)     :: basns_area   !basin area
  REAL,    allocatable, DIMENSION(:)     :: node_area   !nodes area

  REAL,    allocatable, DIMENSION(:)     :: z_q_bas_parm     !GW bucket parameters
  INTEGER, allocatable, DIMENSION(:)     :: nhdBuckMask      !GW bucket mask for NHDPLUS
  INTEGER, allocatable, DIMENSION(:)     :: ct2_bas          !ct of land pixels in basin
  REAL,    allocatable, DIMENSION(:)     :: bas_pcp      !sub-basin avg'd pcp
  INTEGER                                :: bas
  INTEGER, allocatable, DIMENSION(:)        :: bas_id
  CHARACTER(len=19)                      :: header
  CHARACTER(len=1)                       :: jnk
  REAL, allocatable, DIMENSION(:)        :: gw_buck_coeff    !GW bucket model coefficient
  REAL, allocatable, DIMENSION(:)        :: gw_buck_exp      !GW bucket model exponent
  REAL, allocatable, DIMENSION(:)        :: gw_buck_loss     !GW bucket model loss fraction
  REAL, allocatable, DIMENSION(:)        :: z_max            !Height of GW bucket
!DJG Switch for Deep Sat GW Init:
  INTEGER                                :: DEEPGWSPIN  !Switch to setup deep GW spinp
!BF Variables for gw2d
  integer, allocatable, dimension(:,:)      :: soiltyp, soiltypRT

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!DJG,DNY   VARIABLES FOR CHANNEL ROUTING
!-- channel params
  INTEGER(kind=int64), allocatable, DIMENSION(:)   :: LINK       !channel link
  INTEGER(kind=int64), allocatable, DIMENSION(:)   :: TO_NODE    !link's to node
  INTEGER(kind=int64), allocatable, DIMENSION(:)   :: FROM_NODE  !link's from node
  INTEGER, allocatable, DIMENSION(:)   :: ORDER      !link's order
  INTEGER, allocatable, DIMENSION(:)   :: STRMFRXSTPTS      !frxst point flag
  CHARACTER(len=15), allocatable, DIMENSION(:) :: gages
  !                                                    123456789012345
  CHARACTER(len=15)                     :: gageMiss = '               '
!  CHARACTER(len=15)                     :: gageMiss = '          -9999'

  INTEGER, allocatable, DIMENSION(:)   :: TYPEL       !type of link Muskingum: 0 strm 1 lake
                                                      !-- Diffusion: 0 edge or pour; 1 interior; 2 lake
  INTEGER, allocatable, DIMENSION(:)   :: TYPEN      !type of link 0 strm 1 lake
  REAL, allocatable, DIMENSION(:)      :: QLAKEI      !lake inflow in difussion scheme
  REAL, allocatable, DIMENSION(:)      :: QLAKEO      !lake outflow in difussion scheme
  INTEGER(kind=int64), allocatable, DIMENSION(:)   :: LAKENODE   !which nodes flow into which lakes
  integer(kind=int64), allocatable, dimension(:)   :: LINKID     ! id of links on linked routing
  REAL, allocatable, DIMENSION(:)      :: CVOL       ! channel volume
  INTEGER(kind=int64), allocatable, DIMENSION(:,:)   :: pnode    !parent nodes : start from 2
  integer :: maxv_p              ! array size for  second column of the pnode

  REAL, allocatable, DIMENSION(:)      :: MUSK, MUSX !muskingum params
  REAL, allocatable, DIMENSION(:)      :: CHANLEN    !link length
  REAL, allocatable, DIMENSION(:)      :: MannN      !mannings N
  REAL, allocatable, DIMENSION(:)      :: So     !link slope and channel conductivity (m/s)
  REAL, allocatable, DIMENSION(:)      :: Channk ! channel infiltration parameter
  REAL, allocatable, DIMENSION(:)      :: ChSSlp ! channel side slope
  REAL, allocatable, DIMENSION(:)      :: Bw     ! Bottom width of channel
  REAL, allocatable, DIMENSION(:)      :: Tw     ! top width of channel
  REAL, allocatable, DIMENSION(:)      :: Tw_CC  ! top width of the (CC) compound channel
  REAL, allocatable, DIMENSION(:)      :: n_CC   ! mannings N of (CC) compound channel
  REAL, allocatable, DIMENSION(:,:)    :: QLINK      !flow in link
  integer, allocatable, DIMENSION(:)   :: ascendIndex !sorting of routelink
#ifdef WRF_HYDRO_NUDGING
  REAL, allocatable, DIMENSION(:)      :: nudge      !difference between modeled and DA adj link flow
#endif
  REAL, allocatable, DIMENSION(:)      :: HLINK      !head in link
  REAL, allocatable, DIMENSION(:)      :: ZELEV      !elevation of nodes for channel
  INTEGER, allocatable, DIMENSION(:)   :: CHANXI,CHANYJ !map chan to fine grid
  REAL,  DIMENSION(50)     :: BOTWID,CHANN_K,TOPWID,HLINK_INIT,CHAN_SS,CHMann !Channel parms from table
  REAL,  DIMENSION(50)     :: TOPWIDCC, NCC  !topwidth and mannings n of compund

  ! VARIABLES FOR  RESERVOIRS
  REAL, allocatable, DIMENSION(:)      :: RESHT  !reservoir height
!-- lake params
  integer(kind=int64), allocatable, dimension(:) :: LAKEIDA     !id of lakes in routlink file
  integer(kind=int64), allocatable, dimension(:) :: LAKEIDM     !id of LAKES Modeled in LAKEPARM.nc or tbl
  REAL, allocatable, DIMENSION(:)    :: HRZAREA    !horizontal extent of lake, km^2
  REAL, allocatable, DIMENSION(:)    :: WEIRL      !overtop weir length (m)
  REAL, allocatable, DIMENSION(:)    :: DAML      !overtop weir length (m)
  REAL, allocatable, DIMENSION(:)    :: ORIFICEC   !coefficient of orifice
  REAL, allocatable, DIMENSION(:)    :: ORIFICEA   !orifice opening area (m^2)
  REAL, allocatable, DIMENSION(:)    :: ORIFICEE   !orifice elevation (m)
  REAL, allocatable, DIMENSION(:)    :: LATLAKE, LONLAKE,ELEVLAKE ! lake info

  INTEGER, allocatable, DIMENSION(:) :: LAKEIDX ! integer index for lakes, mapped to linkid

!!! accumulated variables for reach beased rt
  Real*8, allocatable, DIMENSION(:)  :: accSfcLatRunoff, accBucket
  REAL  , allocatable, DIMENSION(:)  ::   qSfcLatRunoff,   qBucket, qBtmVertRunoff
  REAL, allocatable, DIMENSION(:)    :: accLndRunOff, accQLateral, accStrmvolrt
  !REAL, allocatable, DIMENSION(:)    :: qqLndRunOff, qqStrmvolrt, qqBucket
  REAL, allocatable, DIMENSION(:)    :: QLateral, velocity, qloss

#ifdef MPP_LAND
  INTEGER, allocatable, DIMENSION(:)    :: lake_index,nlinks_index
  INTEGER(kind=int64), allocatable, DIMENSION(:,:)  :: Link_location
  integer(kind=int64), allocatable, dimension(:)  :: LLINKID
  integer mpp_nlinks, yw_mpp_nlinks, LNLINKSL
#endif
  INTEGER(kind=int64), allocatable, DIMENSION(:,:)      :: CH_LNKRT_SL !-- reach based links used for mapping


  REAL,    allocatable, DIMENSION(:,:)      :: OVROUGHRTFAC,RETDEPRTFAC


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!DJG   VARIABLES FOR AGGREGATION/DISAGGREGATION
  REAL,    allocatable, DIMENSION(:,:,:)   :: SH2OWGT,SICE ! SMCRT, SMCMAXRT, SMCWLTRT moved to subsurface grid transform module
  REAL,    allocatable, DIMENSION(:,:)     :: INFXSAGGRT
  !REAL,    allocatable, DIMENSION(:,:)     :: DHRT,QSTRMVOLRT,QBDRYRT,LAKE_INFLORT ! dhrt and qbdryrt moved to overland control qstrmvolrt and lake_inflrt moved to overland stream and lakes
  REAL,    allocatable, DIMENSION(:,:)     :: QSTRMVOLRT_TS,LAKE_INFLORT_TS
  REAL,    allocatable, DIMENSION(:,:)     :: QSTRMVOLRT_ACC, LAKE_INFLORT_DUM
  REAL,    allocatable, DIMENSION(:,:)       :: INFXSWGT, ywtmp
  REAL,    allocatable, DIMENSION(:)       :: SMCAGGRT,STCAGGRT,SH2OAGGRT
  REAL    :: INFXSAGG1RT,SFCHEADAGG1RT,SFCHEADAGGRT
  !REAL,    allocatable, DIMENSION(:,:,:)       :: dist  ! 8 direction of distance moved to overland properties
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!DJG   VARIABLES FOR ONLINE MASS BALANCE CALCULATION
  REAL(KIND=8)    :: DCMC,DSWE,DACRAIN,DSFCEVP,DCANEVP,DEDIR,DETT,DEPND,DESNO,DSFCRNFF
  REAL(KIND=8)    :: RESID,SUMEVP,DUG1RNFF,DUG2RNFF,DETP ! DSMCTOT, SMCTOT1, SMCTOT2 moved to overland mass balance
  REAL(KIND=8)    :: suminfxs2,dprcp_ts ! suminfxsrt, suminfxs1 moved to overland mass balance
  REAL(KIND=8)    :: CHAN_IN1,CHAN_IN2,LAKE_IN1,LAKE_IN2,zzz, CHAN_STOR,CHAN_OUT
  REAL(KIND=8)    :: CHAN_INV,LAKE_INV  !-channel and lake inflow in volume
  REAL(KIND=8)    :: DQBDRY
  REAL    :: QSTRMVOLTRT1,LAKE_INFLOTRT1,QBDRYTOT1,LSMVOL
  REAL(KIND=8),    allocatable, DIMENSION(:)   :: DSMC,SMCRTCHK
  REAL(KIND=8),    allocatable, DIMENSION(:,:)  :: CMC_INIT,SWE_INIT
!  REAL(KIND=8),    allocatable, DIMENSION(:,:,:) :: SMC_INIT
  REAL(KIND=8)            :: SMC_INIT,SMC_FINAL,resid2,resid1
  REAL(KIND=8)            :: chcksm1,chcksm2,CMC1,CMC2,prcp_in,ETATOT,dsmctot_av

  integer :: g_ixrt,g_jxrt,flag
  integer :: allo_status = -99
  integer iywtmp


!-- lake params
  REAL, allocatable, DIMENSION(:)    :: LAKEMAXH   !maximum depth (m)
  REAL, allocatable, DIMENSION(:)    :: WEIRC      !coeff of overtop weir
  REAL, allocatable, DIMENSION(:)    :: WEIRH      !depth of Lake coef




!DJG Modified namelist for routing and agg. variables
  real Z_tmp

  !!! define land surface grid variables
      REAL,    allocatable, DIMENSION(:,:,:) :: SMC,STC,SH2OX
      REAL,    allocatable, DIMENSION(:,:)   :: SMCMAX1,SMCWLT1,SMCREF1
      INTEGER, allocatable, DIMENSION(:,:)   :: VEGTYP
      REAL, allocatable, DIMENSION(:,:)      :: OV_ROUGH2d
      !REAL,    allocatable, DIMENSION(:)   :: SLDPTH
      REAL,    allocatable, DIMENSION(:,:)   :: NEXP

!!! define constant/parameter
    real ::   ov_rough(50)!, ZSOIL(100) ! ZSOIL moved to subsurface properties module
!  out_counts: couput counts for current run.
!  his_out_counts: used for channel routing output and  special for restart.
!  his_out_counts = previous run + out_counts
    integer :: out_counts, rst_counts, his_out_counts

    REAL,    allocatable, DIMENSION(:,:)   :: lat_lsm, lon_lsm
    REAL,    allocatable, DIMENSION(:,:,:) :: dist_lsm

   END TYPE RT_FIELD
end module module_rt_inc
