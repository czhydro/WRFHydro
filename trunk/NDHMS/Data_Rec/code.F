!  Program Name:
!  Author(s)/Contact(s):
!  Abstract:
!  History Log:
! 
!  Usage:
!  Parameters: <Specify typical arguments passed>
!  Input Files:
!        <list file names and briefly describe the data they include>
!  Output Files:
!        <list file names and briefly describe the information they include>
! 
!  Condition codes:
!        <list exit condition or error codes returned >
!        If appropriate, descriptive troubleshooting instructions or
!        likely causes for failures could be mentioned here with the
!        appropriate error code
! 
!  User controllable options: <if applicable>

Module module_namelist

#ifdef MPP_LAND
          USE module_mpp_land
#endif

!   KGD

    USE module_global_rinfo

    IMPLICIT NONE
    INTEGER, PARAMETER :: max_domain=5

#include "namelist.inc"
    TYPE(namelist_rt_field) , dimension(max_domain) :: nlst_rt
    save nlst_rt 

CONTAINS 

    subroutine read_rt_nlst(nlst)     
          implicit none

          TYPE(namelist_rt_field) nlst

          integer ierr
          integer:: RT_OPTION, CHANRTSWCRT, channel_option, &
                    SUBRTSWCRT,OVRTSWCRT,AGGFACTRT, &
                    GWBASESWCRT,  GW_RESTART,RSTRT_SWC,TERADJ_SOLAR, &
                    sys_cpl, rst_typ, rst_bi_in, rst_bi_out, &
                    gwChanCondSw, GwPreCycles, GwSpinCycles, GwPreDiagInterval, gwsoilcpl, &
                    UDMP_OPT, io_form_outputs
          real:: DTRT_TER,DTRT_CH,dxrt, gwChanCondConstIn, gwChanCondConstOut, gwIhShift
          character(len=256) :: route_topo_f=""
          character(len=256) :: route_chan_f=""
          character(len=256) :: route_link_f=""
          logical            :: compound_channel
          character(len=256) :: route_lake_f=""
          character(len=256) :: route_direction_f=""
          character(len=256) :: route_order_f=""
          character(len=256) :: gwbasmskfil =""
          character(len=256) :: gwstrmfil =""
          character(len=256) :: geo_finegrid_flnm =""
          character(len=256) :: udmap_file =""
          character(len=256) :: GWBUCKPARM_file = ""
          integer :: reservoir_data_ingest ! STUB FOR USE OF REALTIME RESERVOIR DISCHARGE DATA. CURRENTLY NOT IN USE. 
       integer :: SOLVEG_INITSWC
       real*8 :: out_dt, rst_dt
       character(len=256)  :: RESTART_FILE = ""
       character(len=256)  :: hydrotbl_f   = ""
       logical            :: GwPreDiag, GwSpinUp
       integer            :: split_output_count, order_to_write
       integer :: igrid, io_config_outputs, t0OutputFlag, output_channelBucket_influx
       character(len=256) :: geo_static_flnm = ""
       character(len=1024) :: land_spatial_meta_flnm = ""
       integer  :: DEEPGWSPIN

       integer :: i

       
          integer ::CHRTOUT_DOMAIN           ! Netcdf point timeseries output at all channel points
          integer ::CHRTOUT_GRID                ! Netcdf grid of channel streamflow values
          integer ::LSMOUT_DOMAIN              ! Netcdf grid of variables passed between LSM and routing components
          integer ::RTOUT_DOMAIN                ! Netcdf grid of terrain routing variables on routing grid
          integer  :: output_gw
          integer  :: outlake
          integer :: frxst_pts_out            ! ASCII text file of streamflow at forecast points
          integer :: CHANOBS_DOMAIN           ! NetCDF point timeseries output at forecast points. 


!!! add the following two dummy variables 
       integer  :: NSOIL
       real :: ZSOIL8(8)

       logical            :: dir_e
       character(len=1024) :: reservoir_obs_dir
#ifdef WRF_HYDRO_NUDGING
       character(len=256) :: nudgingParamFile
       character(len=256) :: netwkReExFile
       logical            :: readTimesliceParallel
       logical            :: temporalPersistence
       logical            :: persistBias
       logical            :: biasWindowBeforeT0
       character(len=256) :: nudgingLastObsFile
       character(len=256) :: timeSlicePath
       integer            :: nLastObs
       integer            :: minNumPairsBiasPersist
       integer            :: maxAgePairsBiasPersist
       logical            :: invDistTimeWeightBias
       logical            :: noConstInterfBias
#endif 

!      KGD
       logical :: do_res_calc = .false.
       character( len = 256 ) :: fname_rule_curve = '9999999999'
       character( len = 256 ) :: debug_dname = '9999999999'

       logical :: use_with_data = .false.
       character( len = 256 ) :: fname_with_data = '9999999999'

       namelist /HYDRO_nlist/ NSOIL, ZSOIL8,&
            RESTART_FILE,SPLIT_OUTPUT_COUNT,IGRID,&
            geo_static_flnm, &
            land_spatial_meta_flnm, &
            out_dt, rst_dt, &
            DEEPGWSPIN, SOLVEG_INITSWC, &
            RT_OPTION, CHANRTSWCRT, channel_option, &
                    SUBRTSWCRT,OVRTSWCRT,AGGFACTRT, dtrt_ter,dtrt_ch,dxrt,&
                    GwSpinCycles, GwPreCycles, GwSpinUp, GwPreDiag, GwPreDiagInterval, gwIhShift, &
                    GWBASESWCRT, gwChanCondSw, gwChanCondConstIn, gwChanCondConstOut , &
                    route_topo_f,route_chan_f,route_link_f, compound_channel, route_lake_f, &
                    route_direction_f,route_order_f,gwbasmskfil, geo_finegrid_flnm,&
                    gwstrmfil,GW_RESTART,RSTRT_SWC,TERADJ_SOLAR, sys_cpl, &
                    order_to_write , rst_typ, rst_bi_in, rst_bi_out, gwsoilcpl, &
                    CHRTOUT_DOMAIN,CHANOBS_DOMAIN,CHRTOUT_GRID,LSMOUT_DOMAIN,&
                    RTOUT_DOMAIN, output_gw, outlake, &
                    frxst_pts_out, udmap_file, UDMP_OPT, GWBUCKPARM_file, &
                    io_config_outputs, io_form_outputs, hydrotbl_f, t0OutputFlag, &
                    output_channelBucket_influx, &
                    do_res_calc, fname_rule_curve, debug_dname, & ! KGD
                    use_with_data, fname_with_data                ! KGD
      
#ifdef WRF_HYDRO_NUDGING
   namelist /NUDGING_nlist/ nudgingParamFile,       netwkReExFile,          &
                            readTimesliceParallel,  temporalPersistence,    &
                            persistBias,            nudgingLastObsFile,     &
                            timeSlicePath,          nLastObs,               &
                            minNumPairsBiasPersist, maxAgePairsBiasPersist, &
                            biasWindowBeforeT0,     invDistTimeWeightBias,  &
                            noConstInterfBias
#endif

   !! ---- End definitions ----
   
   ! Default values for HYDRO_nlist
   UDMP_OPT = 0
   rst_bi_in = 0
   rst_bi_out = 0
   io_config_outputs = 0
   io_form_outputs = 0
   frxst_pts_out = 0
   CHANOBS_DOMAIN = 0
   t0OutputFlag = 1
   output_channelBucket_influx = 0
   TERADJ_SOLAR = 0
   reservoir_data_ingest = 0 ! STUB FOR USE OF REALTIME RESERVOIR DISCHARGE DATA. CURRENTLY NOT IN USE.  
   compound_channel = .FALSE.
   
#ifdef WRF_HYDRO_NUDGING
   ! Default values for NUDGING_nlist
   nudgingParamFile = "DOMAIN/nudgingParams.nc"
   netwkReExFile    = "DOMAIN/netwkReExFile.nc"
   readTimesliceParallel  = .true.
   temporalPersistence    = .true.
   persistBias            = .false.
   biasWindowBeforeT0     = .false.
   nudgingLastObsFile     = ""
   timeSlicePath          = "./nudgingTimeSliceObs/"
   nLastObs               = 960
   minNumPairsBiasPersist = 8
   maxAgePairsBiasPersist = -99999
   invDistTimeWeightBias  = .false.
   noConstInterfBias      = .false.
#endif 

#ifdef MPP_LAND
       if(IO_id .eq. my_id) then
#endif
#ifndef NCEP_WCOSS
          open(12, file="hydro.namelist", form="FORMATTED")
#else
          open(12, form="FORMATTED")
#endif
          read(12, HYDRO_nlist, iostat=ierr)
          if(ierr .ne. 0) call hydro_stop("HYDRO_nlst namelist error in read_rt_nlst")

#ifdef WRF_HYDRO_NUDGING          
          read(12, NUDGING_nlist, iostat=ierr)
          if(ierr .ne. 0) call hydro_stop("NUDGING_nlst namelist error in read_rt_nlst")
          !! Conditional default values for nuding_nlist
          if(maxAgePairsBiasPersist .eq. -99999) maxAgePairsBiasPersist = -1*nLastObs
#endif
          close(12)

#ifdef MPP_LAND
       endif
#endif

! ADCHANGE: move these checks to more universal namelist checks...
   if ( io_config_outputs .eq. 4 ) RTOUT_DOMAIN = 0

   if(output_channelBucket_influx .ne. 0) then
      if(nlst%dt .ne. out_dt*60) &
           call hydro_stop("read_rt_nlst:: output_channelBucket_influx =! 0 inconsistent with out_dt and NOAH_TIMESTEP choices.")
      if(output_channelBucket_influx .eq. 2 .and. GWBASESWCRT .ne. 1 .and. GWBASESWCRT .ne. 2) &
           call hydro_stop("read_rt_nlst:: output_channelBucket_influx = 2 but GWBASESWCRT != 1 or 2.")
   end if

   if(CHANRTSWCRT .eq. 0 .and. channel_option .lt. 3) channel_option = 3

#ifdef MPP_LAND
!  call mpp_land_bcast_real1(DT)
  call mpp_land_bcast_int1(SPLIT_OUTPUT_COUNT)
  call mpp_land_bcast_int1(IGRID)
  call mpp_land_bcast_int1(io_config_outputs)
  call mpp_land_bcast_int1(io_form_outputs)
  call mpp_land_bcast_int1(t0OutputFlag)
  call mpp_land_bcast_int1(output_channelBucket_influx)
  call mpp_land_bcast_real1_double(out_dt)
  call mpp_land_bcast_real1_double(rst_dt)
  call mpp_land_bcast_int1(DEEPGWSPIN)
  call mpp_land_bcast_int1(SOLVEG_INITSWC)
#endif


#ifdef MPP_LAND
      call mpp_land_bcast_int1(nlst%NSOIL)
      do i = 1, nlst%NSOIL
        call mpp_land_bcast_real1(nlst%ZSOIL8(i))
      end do
#ifdef HYDRO_D
      write(6,*) "nlst%NSOIL = ", nlst%NSOIL
      write(6,*) "nlst%ZSOIL8 = ",nlst%ZSOIL8
#endif
#endif

  !  nlst%DT = DT !!JLM: Note that %dt is set in the Land/WRF initialization, 
  !               !!JLM: e.g. CPL/NoahMP_cpl/module_hrldas_HYDRO.F:hrldas_cpl_HYDRO_ini
  nlst%RESTART_FILE = RESTART_FILE
  nlst%hydrotbl_f = trim(hydrotbl_f) 
  nlst%SPLIT_OUTPUT_COUNT = SPLIT_OUTPUT_COUNT
  nlst%IGRID = IGRID
  nlst%io_config_outputs = io_config_outputs
  nlst%io_form_outputs = io_form_outputs
  nlst%t0OutputFlag = t0OutputFlag
  nlst%output_channelBucket_influx = output_channelBucket_influx
  nlst%geo_static_flnm = geo_static_flnm
  nlst%land_spatial_meta_flnm = land_spatial_meta_flnm
  nlst%out_dt = out_dt
  nlst%rst_dt = rst_dt
  nlst%DEEPGWSPIN = DEEPGWSPIN
  nlst%SOLVEG_INITSWC = SOLVEG_INITSWC
  nlst%reservoir_obs_dir = "testDirectory"

#ifdef MPP_LAND
  call mpp_land_bcast_char(256,nlst%RESTART_FILE)
  call mpp_land_bcast_char(256,nlst%hydrotbl_f)
  call mpp_land_bcast_char(1024,nlst%reservoir_obs_dir)
#endif

  write(nlst%hgrid,'(I1)') igrid


  if(RESTART_FILE .eq. "") rst_typ = 0

  if(rst_bi_out .eq. 1) then
! This part works for intel not pgi
!     inquire(directory='restart', exist=dir_e)
      inquire(file='restart/.', exist=dir_e)
      if(.not. dir_e) then
         call system('mkdir restart')
      endif
  endif


#ifdef MPP_LAND
  !bcast namelist variable.
  call mpp_land_bcast_int1(rt_option)
  call mpp_land_bcast_int1(CHANRTSWCRT)
  call mpp_land_bcast_int1(channel_option)
  call mpp_land_bcast_int1(SUBRTSWCRT)
  call mpp_land_bcast_int1(OVRTSWCRT)
  call mpp_land_bcast_int1(AGGFACTRT)
  call mpp_land_bcast_real1(DTRT_TER)
  call mpp_land_bcast_real1(DTRT_CH)
  call mpp_land_bcast_real1(DXRT)
  call mpp_land_bcast_real1(gwChanCondConstIn)
  call mpp_land_bcast_real1(gwChanCondConstOut)
  call mpp_land_bcast_real1(gwIhShift)
  call mpp_land_bcast_int1(GWBASESWCRT)
  call mpp_land_bcast_int1(GWSOILCPL)
  call mpp_land_bcast_int1(gwChanCondSw)
  call mpp_land_bcast_int1(GwSpinCycles)
  call mpp_land_bcast_int1(GwPreCycles)
  call mpp_land_bcast_log1(GwPreDiag)
  call mpp_land_bcast_log1(GwSpinUp)
  call mpp_land_bcast_int1(GwPreDiagInterval)
  call mpp_land_bcast_int1(GW_RESTART)
  call mpp_land_bcast_int1(RSTRT_SWC  )
  call mpp_land_bcast_int1(TERADJ_SOLAR)
  call mpp_land_bcast_int1(sys_cpl)
  call mpp_land_bcast_int1(rst_typ)
  call mpp_land_bcast_int1(rst_bi_in)
  call mpp_land_bcast_int1(rst_bi_out)
  call mpp_land_bcast_int1(order_to_write)
  call mpp_land_bcast_int1(CHRTOUT_DOMAIN)
  call mpp_land_bcast_int1(CHANOBS_DOMAIN)
  call mpp_land_bcast_int1(output_gw)
  call mpp_land_bcast_int1(outlake)
  call mpp_land_bcast_int1(frxst_pts_out)
  call mpp_land_bcast_int1(CHRTOUT_GRID)
  call mpp_land_bcast_int1(LSMOUT_DOMAIN)
  call mpp_land_bcast_int1(RTOUT_DOMAIN)
  call mpp_land_bcast_int1(UDMP_OPT)
  call mpp_land_bcast_int1(reservoir_data_ingest)
#ifdef WRF_HYDRO_NUDGING
  call mpp_land_bcast_char(256, nudgingParamFile  )
  call mpp_land_bcast_char(256, netwkReExFile     )
  call mpp_land_bcast_char(256, nudgingLastObsFile)
  call mpp_land_bcast_log1(readTimesliceParallel)
  call mpp_land_bcast_log1(temporalPersistence)
  call mpp_land_bcast_log1(persistBias)
  call mpp_land_bcast_log1(biasWindowBeforeT0)
  call mpp_land_bcast_char(256, timeSlicePath)
  call mpp_land_bcast_int1(nLastObs)
  call mpp_land_bcast_int1(minNumPairsBiasPersist)
  call mpp_land_bcast_int1(maxAgePairsBiasPersist)
  call mpp_land_bcast_log1(invDistTimeWeightBias)
  call mpp_land_bcast_log1(noConstInterfBias)
#endif 
#endif /* MPP_LAND */


 
! run Rapid 
    if(channel_option .eq. 4) then
       CHANRTSWCRT = 0
       OVRTSWCRT = 0
       SUBRTSWCRT = 0
    endif

    nlst%CHRTOUT_DOMAIN = CHRTOUT_DOMAIN
    nlst%CHANOBS_DOMAIN = CHANOBS_DOMAIN
    nlst%output_gw      = output_gw
    nlst%outlake      = outlake
    nlst%frxst_pts_out = frxst_pts_out
    nlst%CHRTOUT_GRID = CHRTOUT_GRID
    nlst%LSMOUT_DOMAIN = LSMOUT_DOMAIN
    nlst%RTOUT_DOMAIN = RTOUT_DOMAIN
    nlst%RT_OPTION = RT_OPTION
    nlst%CHANRTSWCRT = CHANRTSWCRT
    nlst%GW_RESTART  = GW_RESTART 
    nlst%RSTRT_SWC   = RSTRT_SWC  
    nlst%channel_option = channel_option
    nlst%DTRT_TER   = DTRT_TER
    nlst%DTRT_CH   = DTRT_CH
    nlst%DTCT      = DTRT_CH   ! small time step for grid based channel routing

#ifdef MPP_LAND
  if(my_id .eq. IO_id) then
#endif
    if(nlst%DT .lt. DTRT_CH) then 
          print*, "nlst%DT,  DTRT_CH = ",nlst%DT,  DTRT_CH
          print*, "reset DTRT_CH=nlst%DT "
          DTRT_CH=nlst%DT
    endif
    if(nlst%DT .lt. DTRT_TER) then 
          print*, "nlst%DT,  DTRT_TER = ",nlst%DT,  DTRT_TER
          print*, "reset DTRT_TER=nlst%DT "
          DTRT_TER=nlst%DT
    endif
    if(nlst%DT/DTRT_TER .ne. real(int(nlst%DT) / int(DTRT_TER)) ) then 
         print*, "nlst%DT,  DTRT_TER = ",nlst%DT,  DTRT_TER
         call hydro_stop("module_namelist: DT not a multiple of DTRT_TER")
    endif
    if(nlst%DT/DTRT_CH .ne. real(int(nlst%DT) / int(DTRT_CH)) ) then 
         print*, "nlst%DT,  DTRT_CH = ",nlst%DT,  DTRT_CH
         call hydro_stop("module_namelist: DT not a multiple of DTRT_CH")
    endif
#ifdef MPP_LAND
  endif
#endif

    nlst%SUBRTSWCRT = SUBRTSWCRT
    nlst%OVRTSWCRT = OVRTSWCRT
    nlst%dxrt0 = dxrt
    nlst%AGGFACTRT = AGGFACTRT
    nlst%GWBASESWCRT = GWBASESWCRT
    nlst%GWSOILCPL= GWSOILCPL
    nlst%gwChanCondSw = gwChanCondSw
    nlst%gwChanCondConstIn = gwChanCondConstIn
    nlst%gwChanCondConstOut = gwChanCondConstOut
    nlst%gwIhShift = gwIhShift
    nlst%GwSpinCycles = GwSpinCycles
    nlst%GwPreCycles = GwPreCycles
    nlst%GwPreDiag = GwPreDiag
    nlst%GwSpinUp = GwSpinUp
    nlst%GwPreDiagInterval = GwPreDiagInterval
    nlst%TERADJ_SOLAR = TERADJ_SOLAR
    nlst%sys_cpl = sys_cpl
    nlst%rst_typ = rst_typ
    nlst%rst_bi_in = rst_bi_in
    nlst%rst_bi_out = rst_bi_out
    nlst%order_to_write = order_to_write
    nlst%compound_channel = compound_channel

! files
    nlst%route_topo_f   =  route_topo_f
    nlst%route_chan_f = route_chan_f 
    nlst%route_link_f = route_link_f
    nlst%route_lake_f =route_lake_f
    nlst%route_direction_f =  route_direction_f
    nlst%route_order_f =  route_order_f
    nlst%gwbasmskfil =  gwbasmskfil
    nlst%gwstrmfil =  gwstrmfil
    nlst%geo_finegrid_flnm =  geo_finegrid_flnm
    nlst%udmap_file =  udmap_file
    nlst%UDMP_OPT = UDMP_OPT
    nlst%GWBUCKPARM_file =  GWBUCKPARM_file
    nlst%reservoir_data_ingest = 0 ! STUB FOR USE OF REALTIME RESERVOIR DISCHARGE DATA. CURRENTLY NOT IN USE.
    nlst%reservoir_obs_dir = 'testDirectory'
#ifdef WRF_HYDRO_NUDGING
    nlst%nudgingParamFile       = nudgingParamFile
    nlst%netWkReExFile          = netWkReExFile
    nlst%readTimesliceParallel  = readTimesliceParallel
    nlst%temporalPersistence    = temporalPersistence
    nlst%persistBias            = persistBias
    nlst%biasWindowBeforeT0     = biasWindowBeforeT0
    nlst%nudgingLastObsFile     = nudgingLastObsFile
    nlst%timeSlicePath          = timeSlicePath
    nlst%nLastObs               = nLastObs
    nlst%minNumPairsBiasPersist = minNumPairsBiasPersist
    nlst%maxAgePairsBiasPersist = maxAgePairsBiasPersist
    nlst%invDistTimeWeightBias  = invDistTimeWeightBias
    nlst%noConstInterfBias      = noConstInterfBias
#endif

#ifdef MPP_LAND
  if(my_id .eq. IO_id) then
#endif
#ifdef HYDRO_D
     write(6,*) "output of the namelist file "
    write(6,*) "nlst%udmap_file ", trim(nlst%udmap_file)
    write(6,*) "nlst%UDMP_OPT ", nlst%UDMP_OPT
    write(6,*) " nlst%RT_OPTION ", RT_OPTION
    write(6,*) " nlst%CHANRTSWCRT ", CHANRTSWCRT
    write(6,*) " nlst%GW_RESTART  ", GW_RESTART 
    write(6,*) " nlst%RSTRT_SWC   ", RSTRT_SWC  
    write(6,*) " nlst%channel_option ", channel_option
    write(6,*) " nlst%DTRT_TER   ", DTRT_TER
    write(6,*) " nlst%DTRT_CH   ", DTRT_CH
    write(6,*) " nlst%SUBRTSWCRT ", SUBRTSWCRT
    write(6,*) " nlst%OVRTSWCRT ", OVRTSWCRT
    write(6,*) " nlst%dxrt0 ", dxrt
    write(6,*) " nlst%AGGFACTRT ", AGGFACTRT
    write(6,*) " nlst%GWBASESWCRT ", GWBASESWCRT
    write(6,*) " nlst%GWSOILCPL ", GWSOILCPL
    write(6,*) " nlst%gwChanCondSw ", gwChanCondSw
    write(6,*) " nlst%gwChanCondConstIn ", gwChanCondConstIn
    write(6,*) " nlst%gwChanCondConstOut ", gwChanCondConstOut
    write(6,*) " nlst%gwIhShift ", gwIhShift
    write(6,*) " nlst%GwSpinCycles ", GwSpinCycles
    write(6,*) " nlst%GwPreDiag ", GwPreDiag
    write(6,*) " nlst%GwPreDiagInterval ", GwPreDiagInterval
    write(6,*) " nlst%TERADJ_SOLAR ", TERADJ_SOLAR
    write(6,*) " nlst%sys_cpl ", sys_cpl
    write(6,*) " nlst%rst_typ ", rst_typ
    write(6,*) " nlst%order_to_write ", order_to_write
    write(6,*) " nlst%route_topo_f   ",  route_topo_f
    write(6,*) " nlst%route_chan_f ", route_chan_f 
    write(6,*) " nlst%route_link_f ", route_link_f
    write(6,*) " nlst%compound_channel ", compound_channel
    write(6,*) " nlst%route_lake_f ",route_lake_f
    write(6,*) " nlst%route_direction_f ",  route_direction_f
    write(6,*) " nlst%route_order_f ",  route_order_f
    write(6,*) " nlst%gwbasmskfil ",  gwbasmskfil
    write(6,*) " nlst%gwstrmfil ",  gwstrmfil
    write(6,*) " nlst%geo_finegrid_flnm ",  geo_finegrid_flnm
    write(6,*) " nlst%reservoir_data_ingest ", reservoir_data_ingest
#ifdef WRF_HYDRO_NUDGING
    write(6,*) " nlst%nudgingParamFile      ",  trim(nudgingParamFile)
    write(6,*) " nlst%netWkReExFile         ",  trim(netWkReExFile)
    write(6,*) " nlst%readTimesliceParallel ",  readTimesliceParallel
    write(6,*) " nlst%temporalPersistence   ",  temporalPersistence
    write(6,*) " nlst%persistBias           ",  persistBias
    write(6,*) " nlst%biasWindowBeforeT0    ",  biasWindowBeforeT0
    write(6,*) " nlst%nudgingLastObsFile    ",  trim(nudgingLastObsFile)
    write(6,*) " timeSlicePath              ",  trim(timeSlicePath)
    write(6,*) " nLastObs                   ",  nLastObs
    write(6,*) " minNumPairsBiasPersist     ",  minNumPairsBiasPersist
    write(6,*) " maxAgePairsBiasPersist     ",  maxAgePairsBiasPersist
    write(6,*) " invDistTimeWeightBias      ",  invDistTimeWeightBias
    write(6,*) " noConstInterfBias          ",  noConstInterfBias
#endif
#endif /* HYDRO_D */
#ifdef MPP_LAND
  endif
#endif

#ifdef MPP_LAND
  !bcast other  variable.
      call mpp_land_bcast_real1(nlst%dt)
#endif

! LRK - Add checking subroutine for hydro.namelist options
#ifdef MPP_LAND
       if(IO_id .eq. my_id) then
#endif
          call rt_nlst_check(nlst)
#ifdef MPP_LAND
       endif
#endif

! derive rtFlag
      nlst%rtFlag = 1
      if(channel_option .eq. 4) nlst%rtFlag = 0
!      if(CHANRTSWCRT .eq. 0 .and.  SUBRTSWCRT .eq. 0 .and. OVRTSWCRT .eq. 0 .and. GWBASESWCRT .eq. 0) nlst%rtFlag = 0
      if(SUBRTSWCRT .eq. 0 .and. OVRTSWCRT .eq. 0 .and. GWBASESWCRT .eq. 0) nlst%rtFlag = 0

!KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
!KGD

#ifdef MPP_LAND
  call mpp_land_bcast_log1 ( do_res_calc )
  call mpp_land_bcast_char( 256, fname_rule_curve )
  call mpp_land_bcast_char( 256, debug_dname )
  call mpp_land_bcast_log1 ( use_with_data )
  call mpp_land_bcast_char( 256, fname_with_data )
#endif

nlst%do_res_calc = do_res_calc
nlst%fname_rule_curve = fname_rule_curve
nlst%debug_dname = debug_dname

nlst%use_with_data = use_with_data
nlst%fname_with_data = fname_with_data

#ifdef MPP_LAND
if ( do_res_calc ) then
  call read_reservoir_info_driver ( my_id, numprocs, fname_rule_curve )
end if
#endif

! NOLA

!KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK

      return

    end subroutine read_rt_nlst

subroutine rt_nlst_check(nlst)
   ! Subroutine to check namelist options specified by the user.
   implicit none
  
   type(namelist_rt_field) nlst

   ! Local variables
   logical :: fileExists = .false.
   integer :: i

   ! Go through and make some logical checks for each hydro.namelist option.
   ! Some of these checks will depend on specific options chosen by the user. 
  
   if( (nlst%sys_cpl .lt. 1) .or. (nlst%sys_cpl .gt. 4) ) then
      call hydro_stop("hydro.namelist ERROR: Invalid sys_cpl value specified.")
   endif
   if(len(trim(nlst%geo_static_flnm)) .eq. 0) then
      call hydro_stop("hydro.namelist ERROR: Please specify a GEO_STATIC_FLNM file.")
   else
      inquire(file=trim(nlst%geo_static_flnm),exist=fileExists)
      if (.not. fileExists) call hydro_stop('hydro.namelist ERROR: GEO_STATIC_FLNM not found.')
   endif
   if(len(trim(nlst%geo_finegrid_flnm)) .eq. 0) then
      call hydro_stop("hydro.namelist ERROR: Please specify a GEO_FINEGRID_FLNM file.")
   else
      inquire(file=trim(nlst%geo_finegrid_flnm),exist=fileExists)
      if (.not. fileExists) call hydro_stop('hydro.namelist ERROR: GEO_FINEGRID_FLNM not found.')
   endif
   !if(len(trim(nlst%land_spatial_meta_flnm)) .eq. 0) then
   !   call hydro_stop("hydro.namelist ERROR: Please specify a LAND_SPATIAL_META_FLNM file.")
   !else
   !   inquire(file=trim(nlst%land_spatial_meta_flnm),exist=fileExists)
   !   if (.not. fileExists) call hydro_stop('hydro.namelist ERROR: LAND_SPATIAL_META_FLNM not found.')
   !endif
   if(len(trim(nlst%RESTART_FILE)) .ne. 0) then
      inquire(file=trim(nlst%RESTART_FILE),exist=fileExists)
      if (.not. fileExists) call hydro_stop('hydro.namelist ERROR:= Hydro RESTART_FILE not found.')
   endif   
   if(nlst%igrid .le. 0) call hydro_stop('hydro.namelist ERROR: Invalid IGRID specified.') 
   if(nlst%out_dt .le. 0) call hydro_stop('hydro_namelist ERROR: Invalid out_dt specified.') 
   if( (nlst%split_output_count .lt. 0 ) .or. (nlst%split_output_count .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid SPLIT_OUTPUT_COUNT specified')
   endif  
   if( (nlst%rst_typ .lt. 0 ) .or. (nlst%rst_typ .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid rst_typ specified')
   endif   
   if( (nlst%rst_bi_in .lt. 0 ) .or. (nlst%rst_bi_in .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid rst_bi_in specified')
   endif    
   if( (nlst%rst_bi_out .lt. 0 ) .or. (nlst%rst_bi_out .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid rst_bi_out specified')
   endif
   if( (nlst%RSTRT_SWC .lt. 0 ) .or. (nlst%RSTRT_SWC .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid RSTRT_SWC specified')
   endif   
   if( (nlst%GW_RESTART .lt. 0 ) .or. (nlst%GW_RESTART .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid GW_RESTART specified')
   endif
   if( (nlst%order_to_write .lt. 1 ) .or. (nlst%order_to_write .gt. 12) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid order_to_write specified')
   endif   
   if( (nlst%io_form_outputs .lt. 0 ) .or. (nlst%io_form_outputs .gt. 4) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid io_form_outputs specified')
   endif   
   if( (nlst%io_config_outputs .lt. 0 ) .or. (nlst%io_config_outputs .gt. 6) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid io_config_outputs specified')
   endif
   if( (nlst%t0OutputFlag .lt. 0 ) .or. (nlst%t0OutputFlag .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid t0OutputFlag specified')
   endif
   if( (nlst%output_channelBucket_influx .lt. 0 ) .or. (nlst%output_channelBucket_influx .gt. 3) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid output_channelBucket_influx specified')
   endif   
   if( (nlst%CHRTOUT_DOMAIN .lt. 0 ) .or. (nlst%CHRTOUT_DOMAIN .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid CHRTOUT_DOMAIN specified')
   endif   
   if( (nlst%CHANOBS_DOMAIN .lt. 0 ) .or. (nlst%CHANOBS_DOMAIN .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid CHANOBS_DOMAIN specified')
   endif
   if( (nlst%CHRTOUT_GRID .lt. 0 ) .or. (nlst%CHRTOUT_GRID .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid CHRTOUT_GRID specified')
   endif
   if( (nlst%LSMOUT_DOMAIN .lt. 0 ) .or. (nlst%LSMOUT_DOMAIN .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid LSMOUT_DOMAIN specified')
   endif
   if( (nlst%RTOUT_DOMAIN .lt. 0 ) .or. (nlst%RTOUT_DOMAIN .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid RTOUT_DOMAIN specified')
   endif
   if( (nlst%output_gw .lt. 0 ) .or. (nlst%output_gw .gt. 2) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid output_gw specified')
   endif   
   if( (nlst%outlake .lt. 0 ) .or. (nlst%outlake .gt. 2) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid outlake specified')
   endif
   if( (nlst%frxst_pts_out .lt. 0 ) .or. (nlst%frxst_pts_out .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid frxst_pts_out specified')
   endif
   if(nlst%TERADJ_SOLAR .ne. 0) then
      call hydro_stop('hydro.namelist ERROR: Invalid TERADJ_SOLAR specified')
   endif

   ! The default value of nsoil == -999. When channel-only is used,
   ! nsoil ==  -999999. In the case of channel-only, skip following block of code.
   if(nlst%NSOIL .le. 0 .and. nlst%NSOIL .ne. -999999) then
      call hydro_stop('hydro.namelist ERROR: Invalid NSOIL specified.')
   endif
   do i = 1,nlst%NSOIL
      if(nlst%ZSOIL8(i) .gt. 0) then
          call hydro_stop('hydro.namelist ERROR: Invalid ZSOIL layer depth specified.')
      endif
      if(i .gt. 1) then
         if(nlst%ZSOIL8(i) .ge. nlst%ZSOIL8(i-1)) then
            call hydro_stop('hydro.namelist ERROR: Invalid ZSOIL layer depth specified.')
         endif
      endif
   end do
   
   if(nlst%dxrt0 .le. 0) then
      call hydro_stop('hydro.namelist ERROR: Invalid DXRT specified.')
   endif
   if(nlst%AGGFACTRT .le. 0) then
      call hydro_stop('hydro.namelist ERROR: Invalid AGGFACTRT specified.') 
   endif   
   if(nlst%DTRT_CH .le. 0) then
      call hydro_stop('hydro.namelist ERROR: Invalid DTRT_CH specified.') 
   endif
   if(nlst%DTRT_TER .le. 0) then
      call hydro_stop('hydro.namelist ERROR: Invalid DTRT_TER specified.') 
   endif
   if( (nlst%SUBRTSWCRT .lt. 0 ) .or. (nlst%SUBRTSWCRT .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid SUBRTSWCRT specified')
   endif
   if( (nlst%OVRTSWCRT .lt. 0 ) .or. (nlst%OVRTSWCRT .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid OVRTSWCRT specified')
   endif
   if( (nlst%OVRTSWCRT .eq. 1 ) .or. (nlst%SUBRTSWCRT .eq. 1) ) then
      if( (nlst%rt_option .lt. 1 ) .or. (nlst%rt_option .gt. 2) ) then
      !if(nlst%rt_option .ne. 1) then
         call hydro_stop('hydro.namelist ERROR: Invalid rt_option specified')
      endif
   endif
   if( (nlst%CHANRTSWCRT .lt. 0 ) .or. (nlst%CHANRTSWCRT .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid CHANRTSWCRT specified')
   endif
   if(nlst%CHANRTSWCRT .eq. 1) then
      if( (nlst%channel_option .lt. 1 ) .or. (nlst%channel_option .gt. 3) ) then
         call hydro_stop('hydro.namelist ERROR: Invalid channel_option specified')
      endif
   endif
   if( (nlst%CHANRTSWCRT .eq. 1) .and. (nlst%channel_option .lt. 3) ) then
      if(len(trim(nlst%route_link_f)) .eq. 0) then
         call hydro_stop("hydro.namelist ERROR: Please specify a route_link_f file.")
      else
         inquire(file=trim(nlst%route_link_f),exist=fileExists)
         if (.not. fileExists) call hydro_stop('hydro.namelist ERROR: route_link_f not found.')
      endif
   endif
   if( (nlst%GWBASESWCRT .lt. 0 ) .or. (nlst%GWBASESWCRT .gt. 2) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid GWBASESWCRT specified')
   endif
   if(nlst%GWBASESWCRT .eq. 1) then
      if(len(trim(nlst%GWBUCKPARM_file)) .eq. 0) then
         call hydro_stop("hydro.namelist ERROR: Please specify a GWBUCKPARM_file file.")
      else
         inquire(file=trim(nlst%GWBUCKPARM_file),exist=fileExists)
         if (.not. fileExists) call hydro_stop('hydro.namelist ERROR: GWBUCKPARM_file not found.')
      endif
   endif
   if( (nlst%GWBASESWCRT .gt. 0) .and. (nlst%UDMP_OPT .ne. 1) ) then
      if(len(trim(nlst%gwbasmskfil)) .eq. 0) then
         call hydro_stop("hydro.namelist ERROR: Please specify a gwbasmskfil file.")
      else
         inquire(file=trim(nlst%gwbasmskfil),exist=fileExists)
         if (.not. fileExists) call hydro_stop('hydro.namelist ERROR: gwbasmskfil not found.')
      endif
   endif
   if( (nlst%UDMP_OPT .lt. 0 ) .or. (nlst%UDMP_OPT .gt. 1) ) then
      call hydro_stop('hydro.namelist ERROR: Invalid UDMP_OPT specified')
   endif
   if(nlst%UDMP_OPT .gt. 0) then
      if(len(trim(nlst%udmap_file)) .eq. 0) then
         call hydro_stop("hydro.namelist ERROR: Please specify a udmap_file file.")
      else
         inquire(file=trim(nlst%udmap_file),exist=fileExists)
         if (.not. fileExists) call hydro_stop('hydro.namelist ERROR: udmap_file not found.')
      endif
   endif
   if( (nlst%UDMP_OPT .eq. 1) .and. (nlst%CHANRTSWCRT .eq. 0) ) then
         call hydro_stop('hydro.namelist ERROR: User-defined mapping requires channel routing on.')
   endif 
   if(nlst%outlake .ne. 0) then
      if(len(trim(nlst%route_lake_f)) .eq. 0) then
         call hydro_stop('hydro.namelist ERROR: You MUST specify a route_lake_f to ouptut and run lakes.')
      endif
   endif
   if(len(trim(nlst%route_lake_f)) .ne. 0) then
      inquire(file=trim(nlst%route_lake_f),exist=fileExists)
      if (.not. fileExists) call hydro_stop('hydro.namelist ERROR: route_lake_f not found.')
   endif
   ! Only allow lakes to be ran with gridded routing or NWM routing
!  if(len(trim(nlst%route_lake_f)) .ne. 0) then
!     if(nlst%channel_option .ne. 3) then
!        if(nlst%UDMP_OPT .ne. 1) then 
!           call hydro_stop('hydro.namelist ERROR: Currently lakes only work with gridded channel routing or UDMP=1. Please change your namelist settings.')
!        endif
!     endif
!  endif

   if((nlst%channel_option .eq. 3) .and. (nlst%compound_channel)) then
      call hydro_stop("Compound channel option not available for diffusive wave routing. ")
   end if

   
end subroutine rt_nlst_check

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!KGD!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!***********************************************************************
!
integer function incr ( nc )

!  Modules for needed subroutines ...

!  Global data module

implicit none

!  Procedure dummy argument declarations

integer, intent(inout) :: nc

nc = nc + 1
incr = nc

end function
!
!***********************************************************************
!
subroutine setup_struc ( pid, nproc )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: pid
integer, intent(in) :: nproc

! Local Declarations

integer :: ierr
integer ( kind = MPI_ADDRESS_KIND ) :: base_address
integer :: nc

! Local Arrays

integer, parameter :: nmaxd = 18
integer, dimension(nmaxd) :: dsize
integer ( kind = MPI_ADDRESS_KIND ), dimension(nmaxd) :: loc
integer, dimension(nmaxd) :: type

write (lulog,'(/a)') ' ENTERING subroutine setup_struc'
call flush ( lulog )

nc = 0
dsize(incr(nc)) = nrmax         		! ndates
dsize(incr(nc)) = nrmax*ndmax   		! nmo
dsize(incr(nc)) = nrmax*ndmax   		! ndy
dsize(incr(nc)) = nrmax*ndmax   		! elev
dsize(incr(nc)) = nrmax*nacmax       		! area_capacity_vol
dsize(incr(nc)) = nrmax*nacmax       		! area_capacity_elev
dsize(incr(nc)) = nrmax         		! celev
dsize(incr(nc)) = nrmax         		! cvol
dsize(incr(nc)) = nrmax         		! dvol
dsize(incr(nc)) = nrmax         		! area_capacity_npts
dsize(incr(nc)) = nrmax*ncmax       		! dname_int
dsize(incr(nc)) = nrmax*ncmax       		! rname_int
dsize(incr(nc)) = nrmax         		! dlat
dsize(incr(nc)) = nrmax         		! dlon
dsize(incr(nc)) = nrmax         		! simple_rule_curve
dsize(incr(nc)) = 1             		! base_elev
dsize(incr(nc)) = nrmax                         ! res_lake_index
dsize(incr(nc)) = nrmax                         ! lake_mpi_index

call setup_struc_calls ( pid, nmaxd, loc, type, base_address )

call MPI_TYPE_CREATE_STRUCT ( nmaxd, dsize, loc, type, mpi_rule_curve_data, ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_TYPE_STRUCT ???'
  write (lulog,'(a,i5)') ' pid=', pid
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

call MPI_TYPE_COMMIT ( mpi_rule_curve_data, ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_TYPE_COMMIT ???'
  write (lulog,'(a,i5)') ' pid=', pid
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

write (lulog,'(/a)') ' LEAVING subroutine setup_struc'
write (lulog,'(a,i5)') ' pid=', pid
write (lulog,'(a,i20)') ' mpi_rule_curve_data=', mpi_rule_curve_data
call flush ( lulog )

end subroutine
!
!***********************************************************************
!
subroutine setup_struc_calls ( pid, nmaxd, loc, type, base_address )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: pid
integer, intent(in) :: nmaxd
integer ( kind = MPI_ADDRESS_KIND ), intent(inout), dimension(nmaxd) :: loc
integer, intent(inout), dimension(nmaxd) :: type
integer ( kind = MPI_ADDRESS_KIND ), intent(inout) :: base_address

! Local Declarations

integer :: ierr
integer :: ncc
integer :: nc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

call MPI_GET_ADDRESS ( rinfo, base_address, ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for base_address ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

nc = 0
ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%ndates, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%ndates ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%nmo, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%nmo ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%ndy, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%ndy ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%elev, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%elev ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%area_capacity_vol, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%area_capacity_vol ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%area_capacity_elev, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%area_capacity_elev ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%celev, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%celev ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%cvol, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%cvol ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%dvol, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%dvol ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%area_capacity_npts, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%area_capacity_npts ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%dname_int, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%dname_int ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%rname_int, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%rname_int ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%dlat, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%dlat ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%dlon, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%dlon ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%simple_rule_curve, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%simple_rule_curve ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%base_elev, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%base_elev ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_REAL

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%res_lake_index, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%res_lake_index ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ncc = incr(nc)
call MPI_GET_ADDRESS ( rinfo%lake_mpi_index, loc(ncc), ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine setup_struc'
  write (lulog,'(a)') ' problem on MPI_GET_ADDRESS for rinfo%lake_mpi_index ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

loc(ncc) = loc(ncc) - base_address
type(ncc) = MPI_INTEGER

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end subroutine
!
!***********************************************************************
!
subroutine allocate_rinfo

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

!  Local declarations

integer :: istatus
integer :: kdum = 1
integer :: nbad

nbad = 0
if ( nrmax <= 0 ) nbad = nbad + 1
if ( ndmax <= 0 ) nbad = nbad + 1
if ( nacmax <= 0 ) nbad = nbad + 1
if ( ncmax <= 0 ) nbad = nbad + 1

if ( nbad > 0 ) then
  write (lulog,'(/a)') ' subroutine allocate_rinfo'
  write (lulog,'(a)') ' one or more dimensions NOT DEFINED ???'
  write (lulog,'(a,i10)') ' nrmax=', nrmax
  write (lulog,'(a,i10)') ' ndmax=', ndmax
  write (lulog,'(a,i10)') ' nacmax=', nacmax
  write (lulog,'(a,i10)') ' ncmax=', ncmax
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

allocate ( rinfo%ndates(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%ndates', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%nmo(nrmax,ndmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%nmo', istatus, &
  '1D', nrmax, ndmax, kdum, lulog )
end if

allocate ( rinfo%ndy(nrmax,ndmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%ndy', istatus, &
  '1D', nrmax, ndmax, kdum, lulog )
end if

allocate ( rinfo%elev(nrmax,ndmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%elev', istatus, &
  '1D', nrmax, ndmax, kdum, lulog )
end if

allocate ( rinfo%area_capacity_vol(nrmax,nacmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%area_capacity_vol', istatus, &
  '2D', nrmax, nacmax, kdum, lulog )
end if

allocate ( rinfo%area_capacity_elev(nrmax,nacmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%area_capacity_elev', istatus, &
  '2D', nrmax, nacmax, kdum, lulog )
end if

allocate ( rinfo%celev(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%celev', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%cvol(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%cvol', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%dvol(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%dvol', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%area_capacity_npts(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%area_capacity_npts', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%dname_int(nrmax,ncmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%dname_int', istatus, &
  '2D', nrmax, ncmax, kdum, lulog )
end if

allocate ( rinfo%rname_int(nrmax,ncmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%rname_int', istatus, &
  '2D', nrmax, ncmax, kdum, lulog )
end if

allocate ( rinfo%dlat(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%dlat', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%dlon(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%dlon', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%simple_rule_curve(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%simple_rule_curve', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%res_lake_index(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%res_lake_index', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

allocate ( rinfo%lake_mpi_index(nrmax), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_rinfo', &
  'rinfo%lake_mpi_index', istatus, &
  '1D', nrmax, kdum, kdum, lulog )
end if

rinfo%ndates = 0
rinfo%nmo = 0
rinfo%ndy = 0
rinfo%elev = 0.0
rinfo%dname_int = 0
rinfo%rname_int = 0
rinfo%area_capacity_vol = 0.0
rinfo%area_capacity_elev = 0.0
rinfo%area_capacity_npts = 0
rinfo%celev = 0.0
rinfo%cvol = 0.0
rinfo%dvol = 0.0
rinfo%simple_rule_curve = 0
rinfo%dlat = rmiss
rinfo%dlon = rmiss
rinfo%res_lake_index = 0
rinfo%lake_mpi_index = 0

end subroutine
!
!***********************************************************************
!
subroutine parse_reservoir_rec1 ( nrec, npass, nrsum, &
  ndtemp, nrtemp )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(in) :: nrec
integer, intent(in) :: npass
integer, intent(inout) :: nrsum
integer, intent(inout) :: ndtemp
integer, intent(inout) :: nrtemp

!  Local declarations

integer :: nstrt
integer :: nmax
integer :: id
character ( len = 100 ) :: dtemp
character ( len = 100 ) :: rtemp
integer :: nhuc
real :: rper
integer :: nsum
integer :: n
integer :: ngood
integer :: lnblnk
integer :: nc
integer :: nend

! Local Arrays

integer, parameter :: ndval = 20
real, dimension ( ndval ) :: rhold
integer, dimension ( ndval ) :: ihold
character ( len = 200 ), dimension ( ndval ) :: chold

nstrt = 1
nmax = ndval

call rdrec ( nstrt, nrec, nmax, chold, rhold, ihold, &
  rmiss, imiss, cmiss, lulog )

nsum = 0

do n = 1, nmax
  if ( nint(rhold(n)) /= nint(rmiss) ) then
    nsum = nsum + 1
  else
    exit
  end if
end do

ngood = 0
if ( nsum == 3 ) ngood = 1
if ( nsum == 4 ) ngood = 1

if ( ngood == 0 ) then
  write (lulog,'(/a)') ' subroutine parse_reservoir_rec1'
  write (lulog,'(a)') ' unexpected number of defined real values ???'
  write (lulog,'(a,a)') ' nrec = ', trim(nrec)
  write (lulog,'(a,i10)') ' nsum=', nsum
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

id = ihold(1)
dtemp = chold(1)
nhuc = ihold(2)
rtemp = chold(2)
rper = rhold(1)

if ( npass == 1 ) then
  ndtemp = lnblnk ( dtemp )
  nrtemp = lnblnk ( rtemp )
end if

if ( nsum == 4 ) then
  rinfo%base_elev = rhold(2)
end if

if ( npass == 1 ) then

  nrmax = nrmax + 1

else if ( npass == 2 ) then

  nrsum = nrsum + 1

! rinfo%nhuc(nrsum) = nhuc
! rinfo%nhid(nrsum) = id

  nend = lnblnk ( dtemp )
  do nc = 1, nend
    rinfo%dname_int(nrsum,nc) = iachar(dtemp(nc:nc))
  end do
  nend = lnblnk ( rtemp )
  do nc = 1, nend
    rinfo%rname_int(nrsum,nc) = iachar(rtemp(nc:nc))
  end do

! rinfo%bper(nrsum) = rper

  if ( nsum == 3 ) then
    rinfo%dlat(nrsum) = rhold(2)
    rinfo%dlon(nrsum) = rhold(3)
  else if ( nsum == 4 ) then
    rinfo%dlat(nrsum) = rhold(3)
    rinfo%dlon(nrsum) = rhold(4)
  end if

  rinfo%res_lake_index(nrsum) = ihold(3)
  
end if

end subroutine
!
!***********************************************************************
!
subroutine parse_reservoir_rec2 ( nr, nrec, npass, nrsum, ndate_beg, nac_beg )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: nr
character ( len = * ), intent(in) :: nrec
integer, intent(in) :: npass
integer, intent(in) :: nrsum
integer, intent(inout) :: ndate_beg
integer, intent(inout) :: nac_beg

!  Local declarations

integer :: nstrt
integer :: nmax
integer :: nend
integer :: nendc
integer :: lnblnk
integer :: nfind
integer :: nssum
integer :: ns

! Local Arrays

integer, parameter :: ndval = 20
integer, parameter :: ngrid_max = 100

real, dimension ( ndval ) :: rhold
integer, dimension ( ndval ) :: ihold
character ( len = 200 ), dimension ( ndval ) :: chold
integer, dimension(ngrid_max) :: src_store

nstrt = 1
nmax = ndval

call rdrec ( nstrt, nrec, nmax, chold, rhold, ihold, &
  rmiss, imiss, cmiss, lulog )

nend = lnblnk ( nrec )
if ( nend <= 0 ) then
  nend = 1
end if

nendc = lnblnk ( chold(1) )
if ( nendc <= 0 ) then
  nendc = 1
end if

nfind = index ( chold(1)(1:nendc), 'SOURCES' )

if ( nfind == 0 ) then
  write (lulog,'(/a)') ' subroutine parse_reservoir_rec2'
  write (lulog,'(a)') ' could not find SOURCES in record ???'
  write (lulog,'(a,i10)') ' nr=', nr
  write (lulog,'(a,a)') ' nrec= ', nrec(1:nend)
  write (lulog,'(a,a)') ' chold(1)= ', chold(1)(1:nendc)
  stop
end if

ndate_beg = 1
nac_beg = 0

call get_sources ( chold(2), ihold(1), ngrid_max, src_store, nssum )

if ( npass == 1 ) then
  if ( nssum > nsmax ) then
    nsmax = nssum
  end if
else if ( npass == 2 ) then
! rinfo%nsrc_per_dam(nrsum) = nssum
! do ns = 1, nssum
!   rinfo%nhuc_src(nrsum,ns) = src_store(ns)
! end do
end if

end subroutine
!
!***********************************************************************
!
subroutine get_sources ( cs, ihold, ngrid_maxx, src_store, nssum )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(in) :: cs
integer, intent(in) :: ihold
integer, intent(in) :: ngrid_maxx
integer, intent(inout), dimension(ngrid_maxx) :: src_store
integer, intent(inout) :: nssum

!  Local declarations

integer :: nend
integer :: lnblnk
integer :: nfind
integer :: nc
integer :: nca
integer :: ncb

nend = lnblnk ( cs )
nssum = 0

nfind = index ( cs(1:nend), ':' )

if ( nfind <= 0 ) then

  if ( cs(1:nend) == cmiss ) then
    if ( ihold == imiss ) then
      write (lulog,'(/a)') ' subroutine get_sources'
      write (lulog,'(a)') ' sources not defined ???'
      write (lulog,'(a,a)') ' cs= ', cs(1:nend)
      write (lulog,'(a,i10)') ' ihold=', ihold
      stop
    end if
    nssum = 1
    src_store(nssum) = ihold
  else if ( cs(1:nend) /= cmiss ) then
    nssum = 1
    read (cs(1:nend),*) src_store(nssum)
  end if

else

  nca = 1

  do nc = 1, nend
    nfind = index ( cs(nc:nc), ':' )
    if ( nfind > 0 .or. nc == nend ) then
      if ( nc == nend ) then
        if ( cs(nc:nc ) == ':' ) then
          ncb = nc - 1
        else
          ncb = nc
        end if
        nssum = nssum + 1
        if ( nssum > ngrid_maxx ) then
          write (lulog,'(/a)') ' subroutine get_sources'
          write (lulog,'(a)') ' nssum > ngrid_maxx ???'
          write (lulog,'(a,i10)') ' nssum=', nssum
          write (lulog,'(a,i10)') ' ngrid_maxx=', ngrid_maxx
          call flush ( lulog )
          call exit ( 9 )
          stop
        end if
        read (cs(nca:ncb),*) src_store(nssum)
        exit
      end if
      ncb = nc - 1
      nssum = nssum + 1
      if ( nssum > ngrid_maxx ) then
        write (lulog,'(/a)') ' subroutine get_sources'
        write (lulog,'(a)') ' nssum > ngrid_maxx ???'
        write (lulog,'(a,i10)') ' nssum=', nssum
        write (lulog,'(a,i10)') ' ngrid_maxx=', ngrid_maxx
        call flush ( lulog )
        call exit ( 9 )
        stop
      end if
      read (cs(nca:ncb),*) src_store(nssum)
      nca = nc + 1
      ncb = 0
    end if
  end do

end if

end subroutine
!
!***********************************************************************
!
subroutine parse_reservoir_rec3 ( nrec, npass, ndsum, nrsum )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(in) :: nrec
integer, intent(in) :: npass
integer, intent(inout) :: ndsum
integer, intent(inout) :: nrsum

!  Local declarations

integer :: nstrt
integer :: nmax
integer :: nend
integer :: nendc
integer :: lnblnk
integer :: nfind
character ( len = 3 ) :: cmon
integer :: nday
real :: etemp
real :: ekeep1
real :: ekeep2
integer :: nmo
real, parameter :: cfac2 = 0.3048	! Conversion from feet to meters

! Local Arrays

integer, parameter :: ndval = 20
real, dimension ( ndval ) :: rhold
integer, dimension ( ndval ) :: ihold
character ( len = 200 ), dimension ( ndval ) :: chold

nstrt = 1
nmax = ndval

ndsum = ndsum + 1

if ( npass == 1 ) then
  return
end if

call rdrec ( nstrt, nrec, nmax, chold, rhold, ihold, &
  rmiss, imiss, cmiss, lulog )

nend = lnblnk ( nrec )
if ( nend <= 0 ) then
  nend = 1
end if

nendc = lnblnk ( chold(1) )
if ( nendc <= 0 ) then
  nendc = 1
end if

nfind = index ( chold(1)(1:nendc), ':' )

if ( nfind == 0 ) then
  write (lulog,'(/a)') ' subroutine parse_reservoir_rec3'
  write (lulog,'(a)') ' could not find colon in date field ???'
  write (lulog,'(a,a)') ' nrec= ', nrec(1:nend)
  write (lulog,'(a,a)') ' chold(1)= ', chold(1)(1:nendc)
  stop
end if

read (chold(1)(1:nfind-1),*) nday
read (chold(1)(nfind+1:nfind+3),'(a)') cmon

call lcase_to_ucase ( cmon )
call get_month_number ( cmon, nmo )

etemp = rhold(1)
ekeep1 = etemp

if ( nint(rinfo%base_elev) /= nint(rmiss) ) then
  etemp = etemp + rinfo%base_elev
end if

ekeep2 = etemp

etemp = cfac2 * etemp

rinfo%ndates(nrsum)= ndsum
rinfo%nmo(nrsum,ndsum) = nmo
rinfo%ndy(nrsum,ndsum) = nday
rinfo%elev(nrsum,ndsum) = etemp

if ( trim(chold(2)) == trim(cmiss) ) then
  rinfo%simple_rule_curve(nrsum) = 0
else if ( trim(chold(2)) == 'MIN' .or. trim(chold(2)) == 'MAX' ) then
  rinfo%simple_rule_curve(nrsum) = 1
else
  write (lulog,'(/a)') ' subroutine parse_reservoir_rec3'
  write (lulog,'(a)') ' unexpected character substring in rule curve record ???'
  write (lulog,'(a,a)') ' nrec= ', nrec(1:nend)
  stop
end if

! write (lulog,'(/a)') ' ELEV DEBUG: subroutine parse_reservoir_rec3'
! write (lulog,'(a,a)') ' rinfo%dname(nrsum) = ', trim ( rinfo%dname(nrsum) )
! write (lulog,'(a,i10)') ' nrsum=', nrsum
! write (lulog,'(a,i10)') ' ndsum=', ndsum
! write (lulog,'(a,f10.3)') ' ekeep1=', ekeep1
! write (lulog,'(a,f10.3)') ' ekeep2=', ekeep2
! write (lulog,'(a,f10.3)') ' etemp=', etemp
! write (lulog,'(a,f10.3)') ' rinfo%base_elev=', rinfo%base_elev

end subroutine
!
!***********************************************************************
!
subroutine get_month_number ( cmon_in, nmo )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(in) :: cmon_in
integer, intent(inout) :: nmo

!  Local declarations

integer :: m
character ( len = 3 ) :: cmon

!  Local Arrays

character ( len = 3 ), save, dimension(12) :: nmonth

nmonth = (/ &
'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', &
'AUG', 'SEP', 'OCT', 'NOV', 'DEC' /)

cmon = cmon_in

call conv_to_caps ( cmon )

nmo = 0

do m = 1, 12
  if ( cmon == nmonth(m) ) then
    nmo = m
    exit
  end if
end do

if ( nmo == 0 ) then
  write (lulog,'(/a)') ' subroutine get_month_number'
  write (lulog,'(a)') ' could not find month abbrev match ???'
  write (lulog,'(a,a)') ' cmon= ', cmon
  stop
end if

end subroutine
!
!***********************************************************************
!
subroutine lcase_to_ucase ( cs )

!  Modules for needed subroutines ...

!  Global data module

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(inout) :: cs

!  Local declarations

integer :: nend
integer :: n
integer :: nn
integer :: lnblnk

! Local Arrays

character ( len = 1 ), save, dimension(26) :: uc
character ( len = 1 ), save, dimension(26) :: lc

uc = (/ &
     'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', &
     'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'  &
     /)

lc = (/ &
     'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', &
     'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'  &
     /)

nend = lnblnk ( cs )

if ( nend <= 0 ) then
  return
end if

do n = 1, nend
  do nn = 1, 26
    if ( cs(n:n) == lc(nn) ) then
      cs(n:n) = uc(nn)
    end if
  end do
end do

end subroutine
!
!***********************************************************************
!
subroutine conv_to_caps ( desc )

!  Modules for needed subroutines ...

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(inout) :: desc

!  Local declarations

integer :: nend
integer :: lnblnk
integer :: n
integer :: nn
integer :: nfind

! Local Arrays

integer, parameter :: nletmax = 26
character ( len = 1 ), save, dimension(nletmax) :: slet
character ( len = 1 ), save, dimension(nletmax) :: blet

slet = (/ &
 & 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', &
 & 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', &
 & 'u', 'v', 'w', 'x', 'y', 'z' &
 & /)

blet = (/ &
 & 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', &
 & 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', &
 & 'U', 'V', 'W', 'X', 'Y', 'Z' &
 & /)

nend = lnblnk( desc )

if ( nend <= 0 ) then
  return
end if

do n = 1, nend
  nfind = 0
  do nn = 1, nletmax
    if ( desc(n:n) == slet(nn) ) then
      nfind = nn
      exit
    end if
  end do
  if ( nfind > 0 ) then
    desc(n:n) = blet(nfind)
  end if
end do

end subroutine
!
!***********************************************************************
!
subroutine parse_reservoir_rec4 ( nrec, npass, ncsum, nrsum )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(in) :: nrec
integer, intent(in) :: npass
integer, intent(inout) :: ncsum
integer, intent(in) :: nrsum

!  Local declarations

integer :: nstrt
integer :: nmax
real, parameter :: cfac2 = 0.3048	! Conversion from feet to meters
real :: ekeep1
real :: ekeep2
real :: etemp

! Local Arrays

integer, parameter :: ndval = 20
real, dimension ( ndval ) :: rhold
integer, dimension ( ndval ) :: ihold
character ( len = 200 ), dimension ( ndval ) :: chold

nstrt = 1
nmax = ndval

ncsum = ncsum + 1
if ( npass == 1 .and. ncsum > nacmax ) then
  nacmax = ncsum
end if

if ( npass == 1 ) then
  return
end if

call rdrec ( nstrt, nrec, nmax, chold, rhold, ihold, &
  rmiss, imiss, cmiss, lulog )

! vol is intially cubic meters times 1.0e-03 or cubic decameters
! vol is needed in millions of cubic meters
! 1.0e+03 / 1.0e+06 = 1.0e-03

etemp = rhold(2) ! meters
ekeep1 = etemp

if ( nint(rinfo%base_elev) /= nint(rmiss) ) then
  etemp = etemp + ( cfac2 * rinfo%base_elev )
end if

ekeep2 = etemp

rinfo%area_capacity_vol(nrsum,ncsum) = rhold(1) * 1.0e-03
rinfo%area_capacity_elev(nrsum,ncsum) = etemp
rinfo%area_capacity_npts(nrsum) = ncsum

! write (lulog,'(/a)') ' ELEV DEBUG: subroutine parse_reservoir_rec4'
! write (lulog,'(a,a)') ' rinfo%dname(nrsum) = ', trim ( rinfo%dname(nrsum) )
! write (lulog,'(a,i10)') ' nrsum=', nrsum
! write (lulog,'(a,i10)') ' ncsum=', ncsum
! write (lulog,'(a,f10.3)') ' ekeep1=', ekeep1
! write (lulog,'(a,f10.3)') ' ekeep2=', ekeep2
! write (lulog,'(a,f10.3)') ' etemp=', etemp
! write (lulog,'(a,f10.3)') ' rinfo%base_elev=', rinfo%base_elev

if ( nint(rinfo%base_elev) /= nint(rmiss) ) then
  write (lulog,'(a,f10.3)') ' cfac2*rinfo%base_elev=', cfac2 * rinfo%base_elev
end if

end subroutine
!
!***********************************************************************
!
subroutine read_reservoir_info_driver ( pid, nproc, fname_rule_curve )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none
 
!  Procedure dummy argument declarations

integer, intent(in) :: pid
integer, intent(in) :: nproc
character ( len = * ), intent(in) :: fname_rule_curve

!  Local declarations

integer :: idim
integer :: nr
character ( len = 100 ) :: dname
character ( len = 1000 ) :: fnamep
integer :: nc
integer :: nend
integer :: lnblnk

!  Local Arrays

integer, parameter :: ndim5 = 5
integer, dimension(ndim5) :: nhold
integer :: ierr

fnamep = ''
write ( fnamep,'(a,i4.4,a)') 'wrf_hydro_reservoir.', pid, '.log'
nend = lnblnk( fnamep )
open (unit=lulog,status='unknown',form='formatted',file=fnamep(1:nend))

if ( pid == 0 ) then

  call read_reservoir_info ( fname_rule_curve )

  nhold(1) = nrmax
  nhold(2) = ndmax
  nhold(3) = nsmax
  nhold(4) = nacmax
  nhold(5) = ncmax

  call MPI_BCAST ( nhold, ndim5, MPI_INTEGER, 0, HYDRO_COMM_WORLD, ierr )

  if ( ierr /= MPI_SUCCESS ) then
    write (lulog,'(/a)') ' subroutine read_reservoir_info_driver'
    write (lulog,'(a)') ' problem on MPI_BCAST for nhold ???'
    call flush ( lulog )
    call exit ( 9 )
    stop
  end if

else

  call MPI_BCAST ( nhold, ndim5, MPI_INTEGER, 0, HYDRO_COMM_WORLD, ierr )

  if ( ierr /= MPI_SUCCESS ) then
    write (lulog,'(/a)') ' subroutine read_reservoir_info_driver'
    write (lulog,'(a)') ' problem on MPI_BCAST for nhold ???'
    call flush ( lulog )
    call exit ( 9 )
    stop
  end if

  nrmax = nhold(1)
  ndmax = nhold(2)
  nsmax = nhold(3)
  nacmax = nhold(4)
! ncmax = nhold(5)

  call allocate_rinfo

end if

call setup_struc ( pid, nproc )

  write (lulog,'(/a)') ' subroutine read_reservoir_info_driver'
  write (lulog,'(a)') ' BEFORE call MPI_BCAST for rinfo'
  call flush ( lulog )

idim = 1
call MPI_BCAST ( rinfo, idim, mpi_rule_curve_data, 0, HYDRO_COMM_WORLD, ierr )

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine read_reservoir_info_driver'
  write (lulog,'(a)') ' problem on MPI_BCAST for rinfo ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

  write (lulog,'(/a)') ' subroutine read_reservoir_info_driver'
  write (lulog,'(a)') ' AFTER call MPI_BCAST for rinfo'
  call flush ( lulog )

do nr = 1, nrmax
! nhuc = rinfo%nhuc(nr)
! id = rinfo%nhid(nr)
  dname = ''
  do nc = 1, ncmax
    if ( rinfo%dname_int(nr,nc) <= 0 ) then
      exit
    end if
    dname(nc:nc) = achar(rinfo%dname_int(nr,nc))
  end do
  write (lulog,'(/a)') ' DAM REVIEW: subroutine read_reservoir_info_driver'
  write (lulog,'(a,i10)') ' nr=', nr
  write (lulog,'(a,i10)') ' nrmax=', nrmax
  write (lulog,'(a,a)') ' dname = ', trim ( dname )
  write (lulog,'(a,f15.5)') ' rinfo%dlat(nr)=', rinfo%dlat(nr)
  write (lulog,'(a,f15.5)') ' rinfo%dlon(nr)=', rinfo%dlon(nr)
  write (lulog,'(a,i10)') ' rinfo%res_lake_index(nr)=', rinfo%res_lake_index(nr)
  call flush ( lulog )
end do

end subroutine
!
!***********************************************************************
!
subroutine read_reservoir_info ( fname_rule_curve )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(in) :: fname_rule_curve

!  Local declarations

character ( len = 1000 ) :: nrec
integer :: nend
integer :: lnblnk
integer :: nstrt
integer :: nmax
integer :: lutemp
integer :: npass
integer :: ios
integer :: ndate_beg
integer :: nac_beg
integer :: nr
integer :: nrsum
integer :: ncsum
integer :: ndsum
logical :: ldebug

integer :: nyr_in
integer :: nmo_in
integer :: ndy_in
real :: relev
real :: rvol
real :: vsump

integer :: nhuc
integer :: id
character ( len = 100 ) :: dname
integer :: ns
integer :: nssum
integer :: nsid
character ( len = 100 ) :: fnamep
integer :: ndtemp
integer :: nrtemp
integer :: ndtemp_max
integer :: nrtemp_max
integer :: nc

! Local Arrays

integer, dimension(2) :: ndim1
integer, dimension(2) :: ndim2

write (lulog,'(/a)') ' ENTERING subroutine read_reservoir_info'
call flush ( lulog )

call get_free_logical_unit ( lutemp )

nrmax = 0
ndmax = 0
nsmax = 0
nacmax = 0

!	============================================================
!	15	Bear_Creek	6030006		Bear 12.96           READ by call parse_reservoir_rec1
!	SOURCES:	14                                           READ by call parse_reservoir_rec2
!	01:Jan	566.6                                                READ by call parse_reservoir_rec3
!	15:Apr	576.0
!	01:Dec	576.0
!	15:Dec	566.6
!	CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
!              0.000             164.592                             READ by call parse_reservoir_rec4
!            555.067             167.640
!           2651.986             170.688
!           7240.540             173.736
!          15295.177             176.784
!          27950.701             179.832
!          46563.945             182.880
!          71258.250             185.928
!         102576.367             188.976
!	END
!	============================================================

fnamep = fname_rule_curve

ndtemp_max = 0
nrtemp_max = 0

do npass = 1, 2

  open (unit=lutemp,status='old',form='formatted',file=trim(fnamep),iostat=ios)

  if ( ios /= 0 ) then
    write (lulog,'(/a)') ' subroutine read_reservoir_info'
    write (lulog,'(a)') ' problems opening file rules_curves.txt ???'
    write (lulog,'(a,i10)') ' ios=', ios
    stop
  end if

  ndate_beg = 0
  nac_beg = 0
  nr = 0
  nrsum = 0

  do

    read (lutemp,'(a)',iostat=ios) nrec

    if ( ios /= 0 ) then
      close (unit=lutemp,status='keep')
      exit
    end if

    nr = nr + 1
    nend = lnblnk ( nrec )

    if ( nrec(1:4) == '====' ) then
      nr = 0
      ncsum = 0
      ndsum = 0
      ndate_beg = 0
      nac_beg = 0
      rinfo%base_elev = rmiss
      cycle
    end if

    if ( nr == 1 ) then
      call parse_reservoir_rec1 ( nrec, npass, nrsum, ndtemp, nrtemp )
      if ( npass == 1 ) then
        ndtemp_max = max ( ndtemp_max, ndtemp )
        nrtemp_max = max ( nrtemp_max, nrtemp )
      end if
      cycle
    end if

    if ( nr == 2 ) then
      call parse_reservoir_rec2 ( nr, nrec, npass, nrsum, ndate_beg, nac_beg )
      cycle
    end if

    if ( ndate_beg == 1 .and. nrec(1:4) == 'CCCC' ) then
      ndate_beg = 0
      nac_beg = 1
      if ( npass == 1 .and. ndsum > ndmax ) then
        ndmax = ndsum
      end if
      cycle
    end if

    if ( nac_beg == 1 .and. nrec(1:3) == 'END' ) then
      ndate_beg = 0
      nac_beg = 0
      cycle
    end if

    if ( ndate_beg == 1 .and. nr >= 3 ) then
      call parse_reservoir_rec3 ( nrec, npass, ndsum, nrsum )
      cycle
    end if

    if ( nac_beg == 1 ) then
      call parse_reservoir_rec4 ( nrec, npass, ncsum, nrsum )
    end if

  end do

  if ( npass == 1 ) then
    call allocate_rinfo
    ndim1 = ubound ( rinfo%dname_int )
    ndim2 = ubound ( rinfo%rname_int )
    if ( ( ndim1(2) < ndtemp_max ) .or. &
         ( ndim2(2) < nrtemp_max ) ) then
      write (lulog,'(/a)') ' subroutine read_reservoir_info'
      write (lulog,'(a)') ' character length issue ???'
      write (lulog,'(a,i10)') ' ndtemp_max=', ndtemp_max
      write (lulog,'(a,i10)') ' nrtemp_max=', nrtemp_max
      write (lulog,'(a,i10)') ' ndim1(2)=', ndim1(2)
      write (lulog,'(a,i10)') ' ndim2(2)=', ndim2(2)
      call flush ( lulog )
      call exit ( 9 )
      stop
    end if
  end if

end do

write (lulog,'(/a)') ' subroutine read_reservoir_info'
write (lulog,'(a,i10)') ' nrmax=', nrmax
write (lulog,'(a,i10)') ' nsmax=', nsmax
write (lulog,'(a,i10)') ' ndmax=', ndmax
write (lulog,'(a,i10)') ' nacmax=', nacmax
write (lulog,'(a,i10)') ' ndtemp_max=', ndtemp_max
write (lulog,'(a,i10)') ' nrtemp_max=', nrtemp_max
write (lulog,'(a,2i10)') ' ubound ( rinfo%dname_int )=', ubound ( rinfo%dname_int )
write (lulog,'(a,2i10)') ' ubound ( rinfo%rname_int )=', ubound ( rinfo%rname_int )

!KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK

! do nr = 1, nrmax
! nhuc = rinfo%nhuc(nr)
! id = rinfo%nhid(nr)
! dname = ''
! do nc = 1, ncmax
!   if ( rinfo%dname_int(nr,nc) <= 0 ) then
!     exit
!   end if
!   dname(nc:nc) = achar(rinfo%dname_int(nr,nc))
! end do
! nssum = rinfo%nsrc_per_dam(nr)
! write (lulog,'(/a)') ' DAM REVIEW: subroutine read_reservoir_info'
! write (lulog,'(a,i10)') ' nr=', nr
! write (lulog,'(a,i10)') ' nrmax=', nrmax
! write (lulog,'(a,i10)') ' nhuc=', nhuc
! write (lulog,'(a,i10)') ' id=', id
! write (lulog,'(a,a)') ' dname = ', trim ( dname )
! write (lulog,'(a,f15.5)') ' rinfo%dlat(nr)=', rinfo%dlat(nr)
! write (lulog,'(a,f15.5)') ' rinfo%dlon(nr)=', rinfo%dlon(nr)
! write (lulog,'(a,i10)') ' nssum=', nssum
! do ns = 1, nssum
!   nsid = rinfo%nhuc_src(nr,ns)
!   write (lulog,'(a,2i10)') ' ns, nsid=', ns, nsid
! end do
! end do

!       write (lulog,'(/a)') ' STOPPING IN subroutine read_reservoir_info'
!       call flush ( lulog )
!       stop

!KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK

write (lulog,'(/a)') ' LEAVING subroutine read_reservoir_info'
call flush ( lulog )

end subroutine
!
!***********************************************************************
!
subroutine rdrec ( nstrt, nrec, nmax, chold, rhold, ihold, &
  rmiss, imiss, cmiss, lulog )

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: nstrt
character ( len = * ), intent(in) :: nrec
integer, intent(in) :: nmax
character ( len = * ), intent(inout), dimension (nmax) :: chold
real, intent(inout), dimension (nmax) :: rhold
integer, intent(inout), dimension (nmax) :: ihold
real, intent(in) :: rmiss
integer, intent(in) :: imiss
character ( len = * ), intent(in) :: cmiss
integer, intent(in) :: lulog

!  Local declarations

integer, parameter :: nccmax = 58
character ( len = 1 ), dimension (nccmax), save :: alphabet
character ( len = 1 ) :: tab
character ( len = 20 ) :: fmt
integer :: ios
integer :: n
integer :: na
integer :: nb
integer :: nbb
integer :: nc
integer :: ncsum
integer :: nend
integer :: nfield
integer :: nfindc
integer :: nfindr
integer :: nflag
integer :: nisum
integer :: nn
integer :: nrsum
integer :: nsum
integer :: nval
real :: xval
integer :: lnblnk

logical :: ldebug

alphabet = (/ &
 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', &
 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', &
 'u', 'v', 'w', 'x', 'y', 'z', &
 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', &
 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', &
 'U', 'V', 'W', 'X', 'Y', 'Z', '_', '/', ':', '!', &
 ',', '"' &
 /)

tab = '	'

nsum = 0
nisum = 0
nrsum = 0
ncsum = 0
na = 0

nflag = 0
ldebug= .false.

nend = lnblnk( nrec )

do n = 1, nmax
  chold(n) = cmiss
  rhold(n) = rmiss
  ihold(n) = imiss
end do

outer: do n = nstrt, nend

  if ( nrec(n:n) /= ' ' .and. nflag == 0 .and. &
    nrec(n:n) /= tab ) then
    nflag = 1
    nsum = nsum + 1
    na = n
  end if

  if ( nsum > nmax ) then
    write (lulog,'(/a)') ' subroutine rdrec'
    write (lulog,'(a)') ' more than nmax data fields ...'
    write (lulog,'(a,i5)') ' nmax=',nmax
    write (lulog,'(a,a)') 'nrec=',nrec(nstrt:nend)
    stop
  end if

  if ( ldebug ) then
    write (lulog,'(/a)') ' subroutine rdrec'
    write (lulog,'(a)') ' NEAR TOP of n=nstrt,nend loop ...'
    write (lulog,'(a,a)') 'nrec=',nrec(nstrt:nend)
    write (lulog,'(a,a)') 'nrec(n:n)=',nrec(n:n)
    write (lulog,'(a,3i5)') ' n,nstrt,nend=',n,nstrt,nend
    write (lulog,'(a,i5)') ' nsum=',nsum
    write (lulog,'(a,i5)') ' na=',na
    write (lulog,'(a,i5)') ' nflag=',nflag
  end if

  if ( ( nrec(n:n) == ' '.and.nflag == 1 ) .or. &
    ( nflag == 1.and.n == nend) .or. &
    ( nflag == 1.and.nrec(n:n) == tab) ) then
    nflag = 0

    if ( n /= nend ) then
      nb = n - 1
    else if ( n == nend ) then
      nb = n
    end if

!	    check for a period for a possible real number ...

    nfindr=index( nrec(na:nb), '.' )

    if ( ldebug ) then
      write (lulog,'(/a)') ' subroutine rdrec'
      write (lulog,'(a)') ' AFTER nfindr=index statement ...'
      write (lulog,'(a,3i5)') ' n,nstrt,nend=',n,nstrt,nend
      write (lulog,'(a,2i5)') ' na,nb=',na,nb
      write (lulog,'(a,i5)') ' nflag=',nflag
      write (lulog,'(a,i5)') ' nfindr=',nfindr
    end if

    if ( nfindr /= 0 ) then

      nfield = nb - na + 1
      fmt=' '
      write (fmt,'(a,i2,a,a)') '(e',nfield,'.','4)'

      nbb = lnblnk( fmt )
      do nn = 1, nbb
        if ( fmt(nn:nn) == ' ' ) fmt(nn:nn)='0'
      end do

      read (nrec(na:nb),fmt(1:nbb),iostat=ios) xval

      if ( ios == 0 ) then
        nrsum = nrsum + 1
        if ( nrsum <= nmax ) then
          rhold(nrsum) = xval
        else
          write (lulog,'(/a)') ' more than nmax real fields ...'
          write (lulog,'(a,i5)') ' nmax=',nmax
          write (lulog,'(a,a)') 'nrec=',nrec(nstrt:nend)
          stop
        end if
        cycle outer
      end if

    end if

!	    check for a character string ...

    if ( ldebug ) then
      write (lulog,'(/a)') ' subroutine rdrec'
      write (lulog,'(a)') ' BEFORE character-string checks ...'
      write (lulog,'(a,3i5)') ' n,nstrt,nend=',n,nstrt,nend
      write (lulog,'(a,i5)') ' ncsum=',ncsum
      write (lulog,'(a,2i5)') ' na,nb=',na,nb
      call flush ( lulog )
    end if

    inner_a: do nc = 1, nccmax
      nfindc = index( nrec(na:nb), alphabet(nc) )
      if ( nfindc /= 0 ) then
        ncsum = ncsum + 1
        if ( ncsum <= nmax ) then
          chold(ncsum) = nrec(na:nb)
        else
          write (lulog,'(/a)') ' more than nmax character fields ...'
          write (lulog,'(a,i5)') ' nmax=',nmax
          write (lulog,'(a,a)') 'nrec=',nrec(nstrt:nend)
          stop
        end if
        cycle outer
      end if
    end do inner_a

    if ( ldebug ) then
      write (lulog,'(/a)') ' subroutine rdrec'
      write (lulog,'(a)') ' AFTER character-string checks ...'
      write (lulog,'(a,3i5)') ' n,nstrt,nend=',n,nstrt,nend
      write (lulog,'(a,i5)') ' ncsum=',ncsum
      write (lulog,'(a,2i5)') ' na,nb=',na,nb
      call flush ( lulog )
    end if

!	    remaining option is an integer ...

    nisum = nisum + 1
    read (nrec(na:nb),*,iostat=ios) nval
    if ( ios /= 0 ) then
      write (lulog,'(/a)') ' unknown data type in input file ???'
      write (lulog,'(a)') &
      ' error in trying to read field as an integer'
      write (lulog,'(a,2i5)') ' na,nb=',na,nb
      write (lulog,'(a,a)') ' nrec(na:nb)= ',nrec(na:nb)
      stop
    end if
    if ( nisum <= nmax ) then
      ihold(nisum) = nval
    else
      write (lulog,'(/a)') ' more than nmax integer fields ...'
      write (lulog,'(a,i5)') ' nmax=',nmax
      write (lulog,'(a,a)') 'nrec=',nrec(nstrt:nend)
      stop
    end if

    cycle outer

  end if

end do outer

end subroutine
!
!***********************************************************************
!
subroutine get_free_logical_unit ( lutemp )
 
!  Modules for needed subroutines ...
 
!  Global data module
 
implicit none
 
!  Procedure dummy argument declarations
 
integer, intent(inout) :: lutemp
 
!  Local declarations
 
logical :: check_for_open
integer :: nlu
integer :: ios
 
do nlu = 10 , 2000
  inquire (unit=nlu, opened=check_for_open )
  if ( .not.check_for_open ) then
    lutemp = nlu
    exit
  end if
end do
 
end subroutine
!
!***********************************************************************
!
subroutine write_alloc_status ( unit_name, vname, istatus, id_1d2d3d, &
  imax, jmax, kmax, lulog )

!  Global data module

!  Modules for needed subroutines ...

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(in) :: unit_name
character ( len = * ), intent(in) :: vname
integer, intent(in) :: istatus
character ( len = * ), intent(in) :: id_1d2d3d
integer, intent(in) :: imax
integer, intent(in) :: jmax
integer, intent(in) :: kmax
integer, intent(in) :: lulog

!  Local declarations

write (lulog,'(/a,a)') ' Program unit= ',unit_name
write (lulog,'(a)') ' unable to allocate array ???'
write (lulog,'(a,a)') ' array name= ',vname
write (lulog,'(a,a)') ' dimension id= ',id_1d2d3d
write (lulog,'(a,i10)') ' istatus=',istatus
write (lulog,'(a,i10)') ' imax=',imax
write (lulog,'(a,i10)') ' jmax=',jmax
write (lulog,'(a,i10)') ' kmax=',kmax
call flush ( lulog )
call exit ( 9 )
stop

end subroutine
!
!***********************************************************************
!
end module module_namelist
