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

MODULE module_channel_routing
#ifdef MPP_LAND
use module_mpp_land
use MODULE_mpp_ReachLS, only : updatelinkv,                   & 
                               ReachLS_write_io, gbcastvalue, &
                               gbcastreal2,      linkls_s
#endif
implicit none

contains

! ------------------------------------------------
!   FUNCTION MUSKING
! ------------------------------------------------
real function MUSKING(idx,qup,quc,qdp,dt,Km,X)

implicit none

!--local variables
real    :: C1, C2, C3
real    :: Km         !K travel time in hrs in reach
real    :: X          !weighting factors 0<=X<=0.5 
real    :: dt         !routing period in hrs
real    :: avgbf      !average base flow for initial condition
real    :: qup        !inflow from previous timestep
real    :: quc        !inflow  of current timestep
real    :: qdp        !outflow of previous timestep
real    :: dth        !timestep in hours
integer :: idx        ! index

dth = dt/3600.    !hours in timestep
C1 = (dth - 2.0 *Km*X)/(2.0*Km*(1.0-X)+dth)
C2 = (dth+2.0*Km*X)/(2.0*Km*(1.0-X)+dth)
C3 = (2.0*Km*(1.0-X)-dth)/(2.0*Km*(1.0-X)+dth)
MUSKING = (C1*quc)+(C2*qup)+(C3*qdp)

! ----------------------------------------------------------------
end function MUSKING
! ----------------------------------------------------------------

! ------------------------------------------------
!   SUBROUTINE LEVELPOOL
! ------------------------------------------------

subroutine LEVELPOOL(ln,qi0,qi1,qo1,ql,dt,H,ar,we,maxh,wc,wl,oe,oc,oa)

!! ----------------------------  argument variables
!! All elevations should be relative to a common base (often belev(k))

real, intent(INOUT) :: H       ! water elevation height (m)
real, intent(IN)    :: dt      ! routing period [s]
real, intent(IN)    :: qi0     ! inflow at previous timestep (cms)
real, intent(IN)    :: qi1     ! inflow at current timestep (cms)
real, intent(OUT)   :: qo1     ! outflow at current timestep
real, intent(IN)    :: ql      ! lateral inflow
real, intent(IN)    :: ar      ! area of reservoir (km^2)
real, intent(IN)    :: we      ! bottom of weir elevation
real, intent(IN)    :: wc      ! weir coeff.
real, intent(IN)    :: wl      ! weir length (m)
real, intent(IN)    :: oe      ! orifice elevation
real, intent(IN)    :: oc      ! orifice coeff.
real, intent(IN)    :: oa      ! orifice area (m^2)
real, intent(IN)    :: maxh    ! max depth of reservoir before overtop (m)                     
integer, intent(IN) :: ln      ! lake number

!!DJG Add lake option switch here...move up to namelist in future versions...
integer :: LAKE_OPT            ! Lake model option (move to namelist later)
real    :: Htmp                ! Temporary assign of incoming lake el. (m)

!! ----------------------------  local variables
real :: sap                    ! local surface area values
real :: discharge              ! storage discharge m^3/s
real :: tmp1, tmp2
real :: dh, dh1, dh2, dh3      ! Depth in weir, and height function for 3 order RK 
real :: It, Itdt_3, Itdt_2_3   ! inflow hydrographs 
real :: maxWeirDepth           !maximum capacity of weir
!real :: hdiff_vol, qdiff_vol   ! water balance check variables
!! ----------------------------  subroutine body: from chow, mad mays. pg. 252
!! -- determine from inflow hydrograph


!!DJG Set hardwire for LAKE_OPT...move specification of this to namelist in
!future versions...
LAKE_OPT = 2
Htmp = H   !temporary set of incoming lake water elevation...
!hdiff_vol = 0.0
!qdiff_vol = 0.0

!!DJG IF-block for lake model option  1 - outflow=inflow, 2 - Chow et al level
!pool, .....
if (LAKE_OPT.eq.1) then     ! If-block for simple pass through scheme....
   
   qo1 = qi1                 ! Set outflow equal to inflow at current time      
   H = Htmp                  ! Set new lake water elevation to incoming lake el.
   
else if (LAKE_OPT.eq.2) then   ! If-block for Chow et al level pool scheme

   It = qi0
   Itdt_3   = qi0 + ((qi1 + ql - qi0) * 0.33)
   Itdt_2_3 = qi0 + ((qi1 + ql - qi0) * 0.67)
   maxWeirDepth =  maxh - we

   !assume vertically walled reservoir
   !remove this when moving to a variable head area volume
   sap = ar * 1.0E6 

   !-- determine Q(dh) from elevation-discharge relationship
   !-- and dh1
   dh = H - we
   if (dh .gt. maxWeirDepth) then 
      dh = maxWeirDepth 
   endif
   
   if (dh .gt. 0.0 ) then              !! orifice and overtop discharge
      tmp1 = oc * oa * sqrt(2. * 9.81 * ( H - oe ) )
      tmp2 = wc * wl * (dh ** (3./2.))
      discharge = tmp1 + tmp2
   else if ( H .gt. oe ) then     !! only orifice flow,not full
      discharge = oc * oa * sqrt(2. * 9.81 * ( H - oe ) )
   else
      discharge = 0.0
   endif
   
   if (sap .gt. 0) then 
      dh1 = ((It - discharge)/sap)*dt
   else
      dh1 = 0.0
   endif

   !-- determine Q(H + dh1/3) from elevation-discharge relationship
   !-- dh2
   dh = (H+dh1/3) - we
   if (dh .gt. maxWeirDepth) then 
      dh = maxWeirDepth 
   endif
   
   if (dh .gt. 0.0 ) then              !! orifice and overtop discharge
      tmp1 = oc * oa * sqrt(2. * 9.81 * ( (H+dh1/3.) - oe ) )
      tmp2 = wc * wl * (dh ** (3./2.)) 
      discharge = tmp1 + tmp2
   else if ( (H+dh1/3) .gt. oe ) then     !! only orifice flow,not full
      discharge = oc * oa * sqrt(2. * 9.81 * ( (H+dh1/3.) - oe ) )
   else
      discharge = 0.0
   endif
   
   if (sap .gt. 0.0) then 
      dh2 = ((Itdt_3 - discharge)/sap)*dt
   else
      dh2 = 0.0
   endif

   !-- determine Q(H + 2/3 dh2) from elevation-discharge relationship
   !-- dh3
   dh = (H + (0.667*dh2)) - we
   if (dh .gt. maxWeirDepth) then 
      dh = maxWeirDepth 
   endif
   
   if (dh .gt. 0.0 ) then              !! orifice and overtop discharge
      tmp1 = oc * oa * sqrt(2. * 9.81 * ( (H+dh2*0.667) - oe ) )
      tmp2 = wc * wl * (dh ** (3./2.)) 
      discharge = tmp1 + tmp2
   else if ( (H+dh2*0.667) .gt. oe ) then     !! only orifice flow,not full
      discharge = oc * oa * sqrt(2. * 9.81 * ( (H+dh2*0.667) - oe ) )
   else
      discharge = 0.0
   endif
   
   if (sap .gt. 0.0) then 
      dh3 = ((Itdt_2_3 - discharge)/sap)*dt
   else
      dh3 = 0.0
   endif
    
   !-- determine dh and H
   dh = (dh1/4.) + (0.75*dh3)
   H = H + dh
   
   !-- compute final discharge
   dh = H - we
   if (dh .gt. maxWeirDepth) then 
      dh = maxWeirDepth 
   endif
   if (dh .gt. 0.0 ) then              !! orifice and overtop discharge
      tmp1 = oc * oa * sqrt(2. * 9.81 * ( H - oe ) )
      tmp2 = wc * wl * (dh ** (3./2.))
      discharge = tmp1 + tmp2
   else if ( H .gt. oe ) then     !! only orifice flow,not full
      discharge = oc * oa * sqrt(2. * 9.81 * ( H - oe ) )
   else
      discharge = 0.0
   endif
   
   if(H .ge. maxh) then  ! overtop condition
      discharge = qi1
      H = maxh
   endif
   
   qo1  = discharge  ! return the flow rate from reservoir
   
!#ifdef HYDRO_D
!#ifndef NCEP_WCOSS
!   ! Water balance check
!   qdiff_vol = (qi1+ql-qo1)*dt !m3
!   hdiff_vol = (H-Htmp)*sap    !m3
!22 format(f8.4,2x,f8.4,2x,f8.4,2x,f8.4,2x,f8.4,2x,f6.0,2x,f20.1,2x,f20.1)
!   open (unit=67, &
!     file='lake_massbalance_out.txt', status='unknown',position='append')
!   write(67,22) Htmp, H, qi1, ql, qo1, dt, qdiff_vol, hdiff_vol
!   close(67) 
!#endif
!#endif

23 format('botof H dh orf wr Q',f8.4,2x,f8.4,2x,f8.3,2x,f8.3,2x,f8.2)
24 format('ofonl H dh sap Q ',f8.4,2x,f8.4,2x,f8.0,2x,f8.2)
   
   
else   ! ELSE for LAKE_OPT....
endif  ! ENDIF for LAKE_OPT....

return
 
! ----------------------------------------------------------------
end subroutine LEVELPOOL
! ----------------------------------------------------------------

 
! ------------------------------------------------
!   FUNCTION Diffusive wave
! ------------------------------------------------
real function DIFFUSION(nod,z1,z20,h1,h2,dx,n, &
     Bw, Cs)
implicit none
!-- channel geometry and characteristics
real    :: Bw         !-bottom width (meters)
real    :: Cs         !-Channel side slope slope
real    :: dx         !-channel lngth (m)
real,intent(in)    :: n          !-mannings coefficient
real    :: R          !-Hydraulic radius
real    :: AREA       !- wetted area
real    :: h1,h2      !-tmp height variables
real    :: z1,z2      !-z1 is 'from', z2 is 'to' elevations
real    :: z          !-channel side distance
real    :: w          !-upstream weight
real    :: Ku,Kd      !-upstream and downstream conveyance
real    :: Kf         !-final face conveyance
real    :: Sf         !-friction slope
real    :: sgn        !-0 or 1 
integer :: nod         !- node
real ::  z20, dzx

! added by Wei Yu for bad data.

dzx = (z1 - z20)/dx
if(dzx .lt. 0.002) then
   z2 = z1 - dx*0.002  
else
   z2 = z20
endif
!end 

if (n.le.0.0.or.Cs.le.0.or.Bw.le.0) then
   print *, "Error in Diffusion function ->channel coefficients"
   print *, "nod, n, Cs, Bw", nod, n, Cs, Bw 
   call hydro_stop("In DIFFUSION() - Error channel coefficients.")
endif

!        Sf = ((z1+h1)-(z2+h2))/dx  !-- compute the friction slope
!if(z1 .eq. z2) then
! Sf = ((z1-(z2-0.01))+(h1-h2))/dx  !-- compute the friction slope
!else
!         Sf = ((z1-z2)+(h1-h2))/dx  !-- compute the friction slope
!endif

!modifieed by Wei Yu for false geography data
if(abs(z1-z2) .gt. 1.0E5) then
#ifdef HYDRO_D
   print*, "WARNING: huge slope rest to 0 for channel grid.", z1,z2
#endif
   Sf = ((h1-h2))/dx  !-- compute the friction slope
else
   Sf = ((z1-z2)+(h1-h2))/dx  !-- compute the friction slope
endif
!end  modfication

sgn = SGNf(Sf)             !-- establish sign

w = 0.5*(sgn + 1.)         !-- compute upstream or downstream weighting

z = 1.0/Cs                   !--channel side distance (m)
R = ((Bw + z*h1)*h1) / (Bw+ 2.0*h1*sqrt(1.0 + z*z)) !-- Hyd Radius
AREA = (Bw + z*h1)*h1        !-- Flow area
Ku = (1.0/n)*(R**(2./3.))*AREA     !-- convenyance

R = ((Bw + z*h2)*h2)/(Bw + 2.0*h2*sqrt(1.0 + z*z)) !-- Hyd Radius
AREA = (Bw + z*h2)*h2        !-- Flow area
Kd = (1.0/n)*(R**(2.0/3.0))*AREA     !-- convenyance

Kf =  (1.0-w)*Kd + w*Ku      !-- conveyance 
DIFFUSION = Kf * sqrt(abs(Sf))*sgn


100 format('z1,z2,h1,h2,kf,Dif, Sf, sgn  ',f8.3,2x,f8.3,2x,f8.4,2x,f8.4,2x,f8.3,2x,f8.3,2x,f8.3,2x,f8.0)

end function DIFFUSION
! ----------------------------------------------------------------
 
subroutine SUBMUSKINGCUNGE(    &
     qdc, vel, idx, qup,  quc, &
     qdp, ql,   dt,  So,   dx, &
     n,   Cs,   Bw,  Tw, TwCC, &
     nCC, depth                 )

#ifdef HYDRO_D
use module_RT_data, only: rt_domain  !! JLM: this is only used in a c3 paramter diagnostic print
#endif

        IMPLICIT NONE

        REAL, intent(IN)       :: dt         ! routing period in  seconds
        REAL, intent(IN)       :: qup        ! flow upstream previous timestep
        REAL, intent(IN)       :: quc        ! flow upstream current timestep
        REAL, intent(IN)       :: qdp        ! flow downstream previous timestep
        REAL, intent(INOUT)    :: qdc        ! flow downstream current timestep
        REAL, intent(IN)       :: ql         ! lateral inflow through reach (m^3/sec)
        REAL, intent(IN)       :: Bw         ! bottom width (meters)
        REAL, intent(IN)       :: Tw         ! top width before bankfull (meters)
        REAL, intent(IN)       :: TwCC       ! top width of Compund (meters)
        REAL, intent(IN)       :: nCC        ! mannings of compund
        REAL, intent(IN)       :: Cs         ! Channel side slope slope
        REAL, intent(IN)       :: So         ! Channel bottom slope %
        REAL, intent(IN)       :: dx         ! channel lngth (m)
        REAL, intent(IN)       :: n          ! mannings coefficient
        REAL, intent(INOUT)    :: vel        ! mannings coefficient
        INTEGER, intent(IN)    :: idx        ! channel id
        REAL, intent(INOUT)    :: depth      ! depth of flow in channel

!--local variables
        REAL    :: C1, C2, C3, C4
        REAL    :: Km             !K travel time in hrs in reach
        REAL    :: X              !weighting factors 0<=X<=0.5
        REAL    :: Ck             ! wave celerity (m/s)

!-- channel geometry and characteristics, local variables
        REAL    :: Twl            ! top width at simulated flow (m)
        REAL    :: AREA,AREAC     ! Cross sectional area channel and compound m^2
        REAL    :: Z              ! trapezoid distance (m)
        REAL    :: R,RC           ! Hydraulic radius of channel and compound
        REAL    :: WP,WPC         ! wetted perimmeter of channel and compound
        REAL    :: h              ! depth of flow in channel
        REAL    :: h_0,h_1        ! secant method estimates
        REAL    :: bfd            ! bankfull depth (m)
        REAL    :: Qj_0           ! secant method estimates
        REAL    :: Qj             ! intermediate flow estimate
        REAL    :: D,D1           ! diffusion coeff
        REAL    :: dtr            ! required timestep, minutes
        REAL    :: aerror,rerror  ! absolute and relative error
        REAL    :: hp             ! courant, previous height
        INTEGER :: iter, maxiter  ! maximum number of iterations

!-- local variables.. needed if channel is sub-divded
        REAL    :: a,b,c,F
        REAL    :: mindepth   !  minimum depth in channel
        INTEGER :: i,tries    !-- channel segment counter

        c = 0.52           !-- coefficients for finding dx/Ckdt
        b = 1.15
        a = 0.0
        maxiter  = 100
        mindepth = 0.01
        aerror = 0.01
        rerror = 1.0
        tries = 0

!-------------  locals
        if(Cs .eq. 0.00000000) then 
         z = 1.0 
        else 
         z = 1.0/Cs          !channel side distance (m)
        endif

        if(Bw .gt. Tw) then   !effectively infinite deep bankful
           bfd = Bw/0.00001
        elseif (Bw .eq. Tw) then 
          bfd =  Bw/(2.0*z)  !bankfull depth is effectively 
        else
          bfd =  (Tw - Bw)/(2.0*z)  !bankfull depth (m)
        endif
        !qC = quc + ql !current upstream in reach

        if (n .le. 0.0 .or. So .le. 0.0 .or. z .le. 0.0 .or. Bw .le. 0.0) then
          print*, "Error in channel coefficients -> Muskingum cunge", n, So, z, Bw
          call hydro_stop("In MUSKINGCUNGE() - Error in channel coefficients")
        end if

!-------------  Secant Method
        depth = max(depth, 0.0)
        h     = (depth * 1.33) + mindepth !1.50 of  depth
        h_0   = (depth * 0.67)            !0.50 of depth
       
        if(ql .gt. 0.0 .or. qup .gt. 0.0 .or. qdp .gt. 0.0) then  !only solve if there's water to flux

110     continue

        Qj_0  = 0.0                       !- initial flow of lower interval
        WPC    = 0.0
        AREAC  = 0.0
        iter   = 0

        do while (rerror .gt. 0.01 .and. aerror .ge. mindepth .and. iter .le. maxiter) 

          !----- lower interval  --------------------
           Twl = Bw + 2.0*z*h_0      !--top surface water width of the channel inflow

            if(h_0 .gt. bfd) then !water outside of defined channel
             AREA =  (Bw + bfd * z) * bfd
             AREAC = (TwCC * (h_0 -bfd)) !assume compound component is rect. chan, that's 3 times the Tw
             WP = (Bw + 2.0 * bfd * sqrt(1.0 + z*z)) 
             WPC = TwCC + (2.0 * (h_0-bfd)) !WPC is 2 times the Tw
             R   = (AREA + AREAC)/(WP +WPC)  ! hydraulic radius
            else
              AREA = (Bw + h_0 * z ) * h_0
              WP = (Bw + 2.0 * h_0 * sqrt(1.0 + z*z))

              if(WP .gt. 0.0) then 
               R = AREA/ WP
              else
               R = 0.0
              endif

            endif

          if(h_0 .gt. bfd) then !water outside of defined channel
            !weight the celerity by the contributing area, and assume that the mannings
            !of the spills is 2x the manning of the channel
                Ck = max(0.0,((sqrt(So)/n)*((5./3.)*R**(2./3.) - &
                ((2./3.)*R**(5./3.)*(2.0*sqrt(1.0 + z*z)/(Bw+2.0*bfd*z))))*AREA &
                + ((sqrt(So)/(nCC))*(5./3.)*(h_0-bfd)**(2./3.))*AREAC)/(AREA+AREAC))
          else
               if(h_0 .gt. 0.0) then
                 Ck = max(0.0,(sqrt(So)/n)*((5./3.)*R**(2./3.) - &
                 ((2./3.)*R**(5./3.)*(2.0*sqrt(1.0 + z*z)/(Bw+2.0*h_0*z)))))
                else
                 Ck = 0.0
                endif
          endif

          if(Ck .gt. 0.000000) then
            Km = max(dt,dx/Ck)
          else
            Km = dt
          endif
 
          if(h_0 .gt. bfd) then !water outside of defined channel
             X = min(0.5,max(0.0,0.5*(1-(Qj_0/(2.0*TwCC*So*Ck*dx)))))
          else
            if(Ck .gt. 0.0) then
              X = min(0.5,max(0.0,0.5*(1-(Qj_0/(2.0*Twl*So*Ck*dx)))))
            else
              X = 0.5
            endif
          endif
  
           D = (Km*(1.000 - X) + dt/2.0000)              !--seconds
            if(D .eq. 0.0) then 
              print *, "FATAL ERROR: D is 0 in MUSKINGCUNGE", Km, X, dt,D
              call hydro_stop("In MUSKINGCUNGE() - D is 0.")
           endif 

           C1 =  (Km*X + dt/2.000000)/D
           C2 =  (dt/2.0000 - Km*X)/D
           C3 =  (Km*(1.00000000-X)-dt/2.000000)/D
!          C1 =  max(0.0,min(1.0,1.0-C3))
           C4 =  (ql*dt)/D
!          C4 =  (ql*dt)/D - (ChannK * (WP + WPC) * dx)  !-- DY & LKR lat inflow + channel loss

           if((WP+WPC) .gt. 0.0) then  !avoid divide by zero
             Qj_0 =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4) - ((1/(((WP*n)+(WPC*nCC))/(WP+WPC))) * &
                    (AREA+AREAC) * (R**(2./3.)) * sqrt(So)) !f0(x)
           endif

           !--upper interval -----------
           Twl = Bw + 2.0*z*h                    !--top width of the channel inflow

           if(h .gt. bfd) then !water outside of defined channel
             AREA =  (Bw + bfd * z) * bfd
             AREAC = (TwCC * (h-bfd)) !assume compound component is rect. chan, that's 3 times the Tw
             WP = (Bw + 2.0 * bfd * sqrt(1.0 + z*z)) 
             WPC = TwCC + (2.0*(h-bfd)) !the additional wetted perimeter
             R   = (AREA + AREAC)/(WP +WPC)
            ! RC  = AREAC/WPC
           else
              AREA = (Bw + h * z ) * h
              WP = (Bw + 2.0 * h * sqrt(1.000000 + z*z))
              if(WP .gt. 0.0) then
               R = AREA/WP
              else
               R = 0.0
              endif
           endif

          if(h .gt. bfd) then !water outside of defined channel, assumed rectangular, 3x TW and n = 3x
                Ck = max(0.0,((sqrt(So)/n)*((5./3.)*R**(2./3.) - &
                ((2./3.)*R**(5./3.)*(2.0*sqrt(1.0 + z*z)/(Bw + 2.0*bfd*z))))*AREA &
                + ((sqrt(So)/(nCC))*(5./3.)*(h-bfd)**(2./3.))*AREAC)/(AREA+AREAC))
          else
               if(h .gt. 0.0) then !avoid divide by zero
                 Ck = max(0.0,(sqrt(So)/n)*((5./3.)*R**(2./3.) - &
                 ((2./3.)*R**(5./3.)*(2.0 * sqrt(1.0 + z*z)/(Bw + 2.0*h*z)))))
               else
                 Ck = 0.0
               endif
          endif
           if(Ck .gt. 0.0) then
            Km = max(dt,dx/Ck)
           else
            Km = dt
           endif
          if(h .gt. bfd) then !water outside of defined channel
            X = min(0.5,max(0.25,0.5*(1-(((C1*qup)+(C2*quc)+(C3*qdp) + C4)/(2.0*TwCC*So*Ck*dx)))))

          else

            if(Ck .gt. 0.0) then
             X = min(0.5,max(0.25,0.5*(1-(((C1*qup)+(C2*quc)+(C3*qdp) + C4)/(2.0*Twl*So*Ck*dx)))))
            else
             X = 0.5
            endif

          endif

           D = (Km*(1 - X) + dt/2)              !--seconds
            if(D .eq. 0.0) then 
              print *, "FATAL ERROR: D is 0 in MUSKINGCUNGE", Km, X, dt,D
              call hydro_stop("In MUSKINGCUNGE() - D is 0.")
           endif 
  
           C1 =  (Km*X + dt/2.000000)/D
           C2 =  (dt/2.000000 - Km*X)/D
           C3 =  (Km*(1.000000-X)-dt/2.000000)/D
!          C1 =  max(0.0,min(1.0,1.0-C3)) !! eliminate influence of upstream current
           C4 =  (ql*dt)/D
!          C4 =  (ql*dt)/D  - (ChannK * dx * (WP+WPC))  !-- (loss units: m/s * m * m) 
        
           if( (C4 .lt. 0.0) .and. (abs(C4) .gt. (C1*qup)+(C2*quc)+(C3*qdp)))  then
            C4 = -((C1*qup)+(C2*quc)+(C3*qdp))
           endif

           if((WP+WPC) .gt. 0.0) then
            Qj =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4) - ((1.0000000/(((WP*n)+(WPC*nCC))/(WP+WPC))) * &
                    (AREA+AREAC) * (R**(2./3.)) * sqrt(So)) !f(x)
           endif

           if(Qj_0-Qj .ne. 0.0) then
             h_1 = h - ((Qj * (h_0 - h))/(Qj_0 - Qj)) !update h, 3rd estimate
              if(h_1 .lt. 0.0) then
                h_1 = h
              endif
           else
             h_1 = h
           endif

           if(h .gt. 0.0) then
             rerror = abs((h_1 - h)/h) !relative error is new estatimate and 2nd estimate
             aerror = abs(h_1 -h)      !absolute error 
           else
             rerror = 0.0 
             aerror = 0.9
           endif

!          if(idx .eq. 6276407) then
!            print*, "err,itr,hs", rerror, iter, depth, h_0, h, h_1
!          endif

           h_0  = max(0.0,h)
           h    = max(0.0,h_1)
           iter = iter + 1

           if( h .lt. mindepth) then  ! exit loop if depth is very small
             goto 111
           endif 

         end do

!          if(idx .eq.  6276407) then
!            print*, "id,itr,err,h", idx, iter, rerror, h
!          endif

111      continue

         if(iter .ge. maxiter) then  

           tries = tries + 1
           if(tries .le. 4) then  ! expand the search space
             h     =  h * 1.33
             h_0   =  h_0 * 0.67
             maxiter = maxiter + 25 !and increase the number of allowable iterations
            goto 110
           endif 

           print*, "Musk Cunge WARNING: Failure to converge"
           print*, 'RouteLink index:', idx + linkls_s(my_id+1) - 1
           print*, "id,err,iters,tries", idx, rerror, iter, tries
           print*, "Ck,X,dt,Km",Ck,X,dt,Km
           print*, "So,dx,h",So,dx,h
           print*, "qup,quc,qdp,ql", qup,quc,qdp,ql
           print*, "bfd,Bw,Tw,Twl", bfd,Bw,Tw,Twl
           print*, "Qmc,Qmn", (C1*qup)+(C2*quc)+(C3*qdp) + C4,((1/(((WP*n)+(WPC*nCC))/(WP+WPC))) * &
                    (AREA+AREAC) * (R**(2./3.)) * sqrt(So)) 
         endif

#ifdef HYDRO_D
      !! Getting information on c3.
      !if(rt_domain(1)%gages(idx + linkls_s(my_id+1) - 1) .ne. rt_domain(1)%gageMiss) then
      !   print*, rt_domain(1)%gages(idx+linkls_s(my_id+1)-1)
!     if(rt_domain(1)%gages(idx) .ne. rt_domain(1)%gageMiss) then
!        print*, rt_domain(1)%gages(idx)
!        print*,'JLM submuskcunge idx, C3, C, D:', idx + linkls_s(my_id+1) - 1, C3, dt/(2*Km), X
!     end if
#endif
      
!yw added for test
      !DY and LKR Added to update for channel loss
        if(((C1*qup)+(C2*quc)+(C3*qdp) + C4) .lt. 0.0) then
!       MUSKINGCUNGE =  MAX( ( (C1*qup)+(C2*quc) + C4),((C1*qup)+(C3*qdp) + C4) )
           if( (C4 .lt. 0.0) .and. (abs(C4) .gt. (C1*qup)+(C2*quc)+(C3*qdp)) )  then ! channel loss greater than water in chan
             qdc = 0.0
           else
             qdc = MAX( ( (C1*qup)+(C2*quc) + C4),((C1*qup)+(C3*qdp) + C4) )
           endif
        else
!       MUSKINGCUNGE =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4) !-- pg 295 Bedient huber
          qdc =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4) !-- pg 295 Bedient huber
  
        endif

        Twl = Bw + (2.0*z*h)
        R = (h*(Bw + Twl) / 2.0) / (Bw + 2.0*(((Twl - Bw) / 2.0)**2.0 + h**2)**0.5)    
        vel =  (1./n) * (R **(2.0/3.0)) * sqrt(So)  ! average velocity in m/s
        depth = h
 
      else   ! no flow to route
       qdc = 0.0
       depth = 0.0
     endif 

! ----------------------------------------------------------------
END SUBROUTINE SUBMUSKINGCUNGE
! ----------------------------------------------------------------

! ------------------------------------------------
!   FUNCTION KINEMATIC
! ------------------------------------------------
	REAL FUNCTION KINEMATIC()

	IMPLICIT NONE

! -------- DECLARATIONS -----------------------
 
!	REAL, INTENT(OUT), DIMENSION(IXRT,JXRT)	:: OVRGH

        KINEMATIC = 1       
!----------------------------------------------------------------
  END FUNCTION KINEMATIC
!----------------------------------------------------------------


! ------------------------------------------------
!   SUBROUTINE drive_CHANNEL
! ------------------------------------------------
! ------------------------------------------------
     Subroutine drive_CHANNEL(latval,lonval,KT, IXRT,JXRT, SUBRTSWCRT, &
       QSUBRT, LAKEINFLORT, QSTRMVOLRT, TO_NODE, FROM_NODE, &
       TYPEL, ORDER, MAXORDER, NLINKS, CH_NETLNK, CH_NETRT, CH_LNKRT, &
       LAKE_MSKRT, DT, DTCT, DTRT_CH,MUSK, MUSX, QLINK, &
       QLateral, &
       HLINK, ELRT, CHANLEN, MannN, So, ChSSlp, Bw, Tw, Tw_CC, n_CC,  &
       RESHT, HRZAREA, LAKEMAXH, WEIRH, WEIRC, WEIRL, ORIFICEC, ORIFICEA, &
       ORIFICEE, ZELEV, CVOL, NLAKES, QLAKEI, QLAKEO, LAKENODE, &
       dist, QINFLOWBASE, CHANXI, CHANYJ, channel_option, RETDEP_CHAN, &
       NLINKSL, LINKID, node_area, lake_lookup  &
#ifdef MPP_LAND 
       , lake_index,link_location,mpp_nlinks,nlinks_index,yw_mpp_nlinks  &
       , LNLINKSL, LLINKID  &
       , gtoNode,toNodeInd,nToNodeInd &
#endif
       , CH_LNKRT_SL &
       ,gwBaseSwCRT, gwHead, qgw_chanrt, gwChanCondSw, gwChanCondConstIn, &
       gwChanCondConstOut, velocity, &
       olddate, do_res_calc, debug_dname, &
       use_with_data, fname_with_data, &
       nyr_base, nmo_base, ndy_base, nhr_base )

USE module_global_rinfo

       IMPLICIT NONE

! -------- DECLARATIONS ------------------------

        INTEGER, INTENT(IN) :: IXRT,JXRT,channel_option
        INTEGER, INTENT(IN) :: NLINKS,NLAKES, NLINKSL
        integer, INTENT(INOUT) :: KT   ! flag of cold start (1) or continue run.
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: QSUBRT
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: QSTRMVOLRT
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: LAKEINFLORT
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: ELRT
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: QINFLOWBASE
        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: CH_NETLNK

        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: CH_NETRT
        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: CH_LNKRT
        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: CH_LNKRT_SL

       real , dimension(ixrt,jxrt):: latval,lonval

        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: LAKE_MSKRT
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: ORDER, TYPEL !--link
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: TO_NODE, FROM_NODE
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: CHANXI, CHANYJ
        REAL,    INTENT(IN), DIMENSION(NLINKS)    :: ZELEV  !--elevation of nodes
        REAL, INTENT(INOUT), DIMENSION(NLINKS)    :: CVOL
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: MUSK, MUSX
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: CHANLEN
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: So, MannN
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: ChSSlp,Bw,Tw  !--properties of nodes or links
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: Tw_CC, n_CC  !properties of compund channel

        REAL                                      :: Km, X
        REAL , INTENT(INOUT), DIMENSION(:,:) :: QLINK
        REAL ,  DIMENSION(NLINKS,2) :: tmpQLINK
        REAL , INTENT(INOUT), DIMENSION(NLINKS)   :: HLINK
        REAL, dimension(NLINKS), intent(inout)    :: QLateral !--lateral flow
        REAL, INTENT(IN)                          :: DT    !-- model timestep
        REAL, INTENT(IN)                          :: DTRT_CH  !-- routing timestep
        REAL, INTENT(INOUT)                       :: DTCT
        real                                      :: minDTCT !BF minimum routing timestep
        REAL                                      :: dist(ixrt,jxrt,9)
        REAL                                      :: RETDEP_CHAN
        INTEGER, INTENT(IN)                       :: MAXORDER, SUBRTSWCRT, &
                                                     gwBaseSwCRT, gwChanCondSw
        real, intent(in)                          :: gwChanCondConstIn, gwChanCondConstOut ! aquifer-channel conductivity constant from namelist                                             
        REAL , INTENT(IN), DIMENSION(NLINKS)      :: node_area
        real, dimension(:), INTENT(inout)         :: velocity

        character ( len = * ), intent(in) :: olddate
        logical, intent(in) :: do_res_calc
        character ( len = * ), intent(in) :: debug_dname
        logical, intent(in) :: use_with_data
        character ( len = * ), intent(in) :: fname_with_data
        integer, intent(in) :: nyr_base
        integer, intent(in) :: nmo_base
        integer, intent(in) :: ndy_base
        integer, intent(in) :: nhr_base

!DJG GW-chan coupling variables...
        REAL, DIMENSION(NLINKS)                   :: dzGwChanHead
        REAL, DIMENSION(NLINKS)                   :: Q_GW_CHAN_FLUX     !DJG !!! Change 'INTENT' to 'OUT' when ready to update groundwater state...
        REAL, DIMENSION(IXRT,JXRT)                :: ZWATTBLRT          !DJG !!! Match with subsfce/gw routing & Change 'INTENT' to 'INOUT' when ready to update groundwater state...
        REAL, INTENT(INOUT), DIMENSION(IXRT,JXRT) :: gwHead            !DJG !!! groundwater head from Fersch-2d gw implementation...units (m ASL)
        REAL, INTENT(INOUT), DIMENSION(IXRT,JXRT) :: qgw_chanrt         !DJG !!! Channel-gw flux as used in Fersch 2d gw implementation...units (m^3/s)...Change 'INTENT' to 'OUT' when ready to update groundwater state...
         


        !-- lake params
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: HRZAREA  !-- horizontal area (km^2)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: LAKEMAXH !-- maximum lake depth  (m^2)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: WEIRH    !-- lake depth  (m^2)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: WEIRC    !-- weir coefficient
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: WEIRL    !-- weir length (m)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: ORIFICEC !-- orrifice coefficient
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: ORIFICEA !-- orrifice area (m^2)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: ORIFICEE !-- orrifce elevation (m)

        REAL, INTENT(INOUT), DIMENSION(NLAKES)    :: RESHT    !-- reservoir height (m)
        REAL*8,  DIMENSION(NLAKES)    :: QLAKEI8   !-- lake inflow (cms)
        REAL, INTENT(INOUT), DIMENSION(NLAKES)    :: QLAKEI   !-- lake inflow (cms)
        REAL,                DIMENSION(NLAKES)    :: QLAKEIP  !-- lake inflow previous timestep (cms)
        REAL, INTENT(INOUT), DIMENSION(NLAKES)    :: QLAKEO   !-- outflow from lake used in diffusion scheme
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: LAKENODE !-- outflow from lake used in diffusion scheme
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: LINKID   !--  id of channel elements for linked scheme
        !REAL, DIMENSION(NLINKS)                   :: QLateral !--lateral flow
        REAL, DIMENSION(NLINKS)                   :: QSUM     !--mass bal of node
        REAL*8, DIMENSION(NLINKS)                   :: QSUM8     !--mass bal of node
        REAL, DIMENSION(NLAKES)                   :: QLLAKE   !-- lateral inflow to lake in diffusion scheme
        REAL*8, DIMENSION(NLAKES)                   :: QLLAKE8   !-- lateral inflow to lake in diffusion scheme

        integer, intent(in), dimension(:)     :: lake_lookup  !-- inverse lake index for k->lake mapping

!-- Local Variables
        INTEGER                     :: i,j,k,t,m,jj,kk,KRT,node,l_idx
        INTEGER                     :: DT_STEPS               !-- number of timestep in routing
        REAL                        :: Qup,Quc                !--Q upstream Previous, Q Upstream Current, downstream Previous
        REAL                        :: bo                     !--critical depth, bnd outflow just for testing
        REAL                        :: AREA,WP                !--wetted area and perimiter for MuskingC. routing

        REAL ,DIMENSION(NLINKS)     :: HLINKTMP,CVOLTMP       !-- temporarily store head values and volume values
        REAL ,DIMENSION(NLINKS)     :: CD                     !-- critical depth
        real, DIMENSION(IXRT,JXRT)  :: tmp
        real, dimension(nlinks)     :: tmp2

#ifdef MPP_LAND
        integer lake_index(nlakes)
        integer nlinks_index(nlinks)
        integer mpp_nlinks, iyw, yw_mpp_nlinks
        integer link_location(ixrt,jxrt)
        real     ywtmp(ixrt,jxrt)
        integer LNLINKSL
        integer, dimension(LNLINKSL) :: LLINKID
        real(kind=8),  dimension(LNLINKSL) :: LQLateral
        integer, dimension(:) ::  toNodeInd
        integer, dimension(:,:) ::  gtoNode
        integer  :: nToNodeInd
        real, dimension(nToNodeInd,2) :: gQLINK
        real, allocatable,dimension(:) :: tmpQLAKEO, tmpQLAKEI, tmpRESHT
#else
        real(kind=8), dimension(NLINKS) :: LQLateral !--lateral flow
#endif
        integer flag

        integer :: n, kk2, nt, nsteps  ! tmp

integer, save :: counts = 0
integer :: nrloc
integer :: istatus
integer :: kkp
logical :: ldebug
logical :: do_swap

! Local Arrays

       counts = counts + 1

#ifdef MPP_LAND
       if(my_id == io_id) then
#endif
           allocate(tmpQLAKEO(NLAKES))
           allocate(tmpQLAKEI(NLAKES))
           allocate(tmpRESHT(NLAKES))
#ifdef MPP_LAND
        endif
#endif
        QLAKEIP = 0
        QLAKEI8 = 0
        HLINKTMP = 0
        CVOLTMP = 0
        CD = 0  
        node = 1
        QLateral = 0
        QSUM     = 0
        QLLAKE   = 0
         
      dzGwChanHead = 0.

   IF(channel_option .ne. 3) then   !--muskingum methods ROUTE ON DT timestep, not DTRT!!

         nsteps = (DT+0.5)/DTRT_CH

#ifdef MPP_LAND
         LQLateral = 0          !-- initial lateral flow to 0 for this reach
         DO iyw = 1,yw_MPP_NLINKS
         jj = nlinks_index(iyw)
          !--------river grid points, convert depth in mm to rate across reach in m^3/sec
              if( .not. (  (CHANXI(jj) .eq. 1 .and. left_id .ge. 0) .or. &
                           (CHANXI(jj) .eq. ixrt .and. right_id .ge. 0) .or. &
                           (CHANYJ(jj) .eq. 1 .and. down_id .ge. 0) .or. &
                           (CHANYJ(jj) .eq. jxrt .and. up_id .ge. 0)      &
                   ) ) then
                  if (CH_LNKRT_SL(CHANXI(jj),CHANYJ(jj)) .gt. 0) then
                     k = CH_LNKRT_SL(CHANXI(jj),CHANYJ(jj))
                     LQLateral(k) = LQLateral(k)+((QSTRMVOLRT(CHANXI(jj),CHANYJ(jj))+QINFLOWBASE(CHANXI(jj),CHANYJ(jj)))/1000 & 
                            *node_area(jj)/DT)
                  elseif ( (LAKE_MSKRT(CHANXI(jj),CHANYJ(jj)) .gt. 0)) then !-lake grid
                      k = LAKE_MSKRT(CHANXI(jj),CHANYJ(jj))
                      LQLateral(k) = LQLateral(k) +((LAKEINFLORT(CHANXI(jj),CHANYJ(jj))+QINFLOWBASE(CHANXI(jj),CHANYJ(jj)))/1000 &
                               *node_area(jj)/DT)
                  endif
              endif
         end do  ! jj


!   assign LQLATERAL to QLATERAL
       call updateLinkV(LQLateral, QLateral(1:NLINKSL))

#else

         LQLateral = 0          !-- initial lateral flow to 0 for this reach
         do jj = 1, NLINKS
          !--------river grid points, convert depth in mm to rate across reach in m^3/sec

                  if (CH_LNKRT_SL(CHANXI(jj),CHANYJ(jj)) .gt. 0 ) then
                     k = CH_LNKRT_SL(CHANXI(jj),CHANYJ(jj))
                     LQLateral(k) = LQLateral(k)+((QSTRMVOLRT(CHANXI(jj),CHANYJ(jj))+QINFLOWBASE(CHANXI(jj),CHANYJ(jj)))/1000 & 
                            *node_area(jj)/DT)
                  elseif ( (LAKE_MSKRT(CHANXI(jj),CHANYJ(jj)) .gt. 0)) then !-lake grid
                      k = LAKE_MSKRT(CHANXI(jj),CHANYJ(jj))
                      LQLateral(k) = LQLateral(k) +((LAKEINFLORT(CHANXI(jj),CHANYJ(jj))+QINFLOWBASE(CHANXI(jj),CHANYJ(jj)))/1000 &
                               *node_area(jj)/DT)
                  endif   

          end do  ! jj
          QLateral = LQLateral

#endif

!       QLateral = QLateral / nsteps

   if ( do_res_calc ) then
     rinfo%lake_mpi_index = 0
   end if

   do nt = 1, nsteps

#ifdef MPP_LAND
       gQLINK = 0.000
       call gbcastReal2(toNodeInd,nToNodeInd,QLINK(1:NLINKSL,2), NLINKSL, gQLINK(:,2))
       call gbcastReal2(toNodeInd,nToNodeInd,QLINK(1:NLINKSL,1), NLINKSL, gQLINK(:,1))
#endif

      !---------- route other reaches, with upstream inflow
       tmpQlink = 0.0
#ifdef MPP_LAND
       if(my_id .eq. io_id) then
#endif
            tmpQLAKEO = QLAKEO
            tmpQLAKEI = QLAKEI
            tmpRESHT = RESHT
#ifdef MPP_LAND
       endif
#endif
       do k = 1,NLINKSL
!          if (ORDER(k) .gt. 1 ) then  !-- exclude first order stream 
             Quc  = 0.0
             Qup  = 0.0
             nrloc = -9999

#ifdef MPP_LAND
!using mapping index
               do n = 1, gtoNODE(k,1)
                  m = gtoNODE(k,n+1)
                    Quc = Quc + gQLINK(m,2)  !--accum of upstream inflow of current timestep (2)
                    Qup = Qup + gQLINK(m,1)  !--accum of upstream inflow of previous timestep (1)
					if ( k == 171 ) then
						write (lulog,'(/a)') ' QUC and QUP calc: Subroutine drive_CHANNEL'
						write (lulog,'(a,i10)') ' k=', k
						write (lulog,'(a,i10)') ' n=', n
						write (lulog,'(a,i10)') ' gtonode(k,1)=', gtonode(k,1)
						write (lulog,'(a,i10)') ' gtonode(k,n+1)=', gtonode(k,n+1)
						write (lulog,'(a,i10)') ' m=', m
						write (lulog,'(a,5x,e12.5)') ' gqlink(m,2)=', gqlink(m,2)
						write (lulog,'(a,5x,e12.5)') ' gqlink(m,1)=', gqlink(m,1)
						write (lulog,'(a,5x,e12.5)') ' quc=', quc
						write (lulog,'(a,5x,e12.5)') ' qup=', qup
					end if
                end do ! do i

#else
               do m = 1, NLINKSL
                  if (LINKID(k) .eq. TO_NODE(m)) then
                    Quc = Quc + QLINK(m,2)  !--accum of upstream inflow of current timestep (2)
                    Qup = Qup + QLINK(m,1)  !--accum of upstream inflow of previous timestep (1)
                  endif
               end do ! do m
#endif
                   

                if ( nt == 1 .and. use_with_data .and. counts == 1 ) then
                  call read_with_info_driver ( my_id, numprocs, fname_with_data, &
                    linkid, nlinks, rmiss, imiss, cmiss, &
                    nyr_base, nmo_base, ndy_base, nhr_base )
                end if

                if(TYPEL(k) == 1) then   !--link is a reservoir
                    l_idx = lake_lookup(k)

                    if (l_idx >= 0 ) then !-- -999 if not a reservoir in the lookup table
!                                         (belt-and-suspenders check)
                        nrloc = -9999

                        if ( do_res_calc ) then
                          call check_lake_index ( l_idx, nrloc )
                          if ( nt == 1 .and. nrloc > 0 .and. counts == 1 ) then
                            call initialize_reservoir ( olddate, nrloc, debug_dname )
                          end if
                        end if

                        if ( nrloc > 0 ) then

                          call update_reservoir ( qlink(k,2), nt, dtrt_ch, olddate, nrloc, &
                            quc, qup, qlateral(k), debug_dname, ldebug )

                          QLAKEO(l_idx)  = QLINK(k,2)     !save outflow to lake
                          QLAKEI(l_idx)  = Quc            !save inflow to lake
                          rinfo%lake_mpi_index(nrloc) = 1

                        else if ( nrloc <= 0 ) then

                          CALL LEVELPOOL(l_idx,Quc, Qup, QLINK(k,2), QLateral(k), DT, &
                            RESHT(l_idx), HRZAREA(l_idx), WEIRH(l_idx), LAKEMAXH(l_idx), &
                            WEIRC(l_idx), WEIRL(l_idx), ORIFICEE(l_idx), &
                            ORIFICEC(l_idx), ORIFICEA(l_idx))

                          QLAKEO(l_idx)  = QLINK(k,2)     !save outflow to lake
                          QLAKEI(l_idx)  = Quc            !save inflow to lake

                        end if

                    end if

                elseif (channel_option .eq. 1) then  !muskingum routing
                       Km = MUSK(k)
                       X = MUSX(k)
                       tmpQLINK(k,2) = MUSKING(k,Qup,(Quc+QLateral(k)),QLINK(k,1),DTRT_CH,Km,X) !upstream plust lateral inflow 
                elseif (channel_option .eq. 2) then ! muskingum cunge

                   call SUBMUSKINGCUNGE(tmpQLINK(k,2), velocity(k), LINKID(k),  &
                    Qup,Quc, QLINK(k,1), QLateral(k),   DTRT_CH, So(k), &
                    CHANLEN(k), MannN(k), ChSSlp(k), Bw(k), Tw(k),Tw_CC(k), n_CC(k), HLINK(k) )

                else
                    print *, "FATAL ERROR: no channel option selected"
                    call hydro_stop("In drive_CHANNEL() - no channel option selected") 
                endif

                !write (lulog,'(/a)') ' OUTPUT REVIEW: Subroutine drive_CHANNEL'
                !write (lulog,'(a,3i5)') ' k, typel(k), lake_lookup(k)=', &
                !k, typel(k), lake_lookup(k)
                !write (lulog,'(a,5x,e12.5)') ' qlink(k,2)=', qlink(k,2)
                !write (lulog,'(a,5x,e12.5)') ' tmpQLINK(k,2)=', tmpQLINK(k,2)

!            endif !!! order(1) .ne. 1
         end do       !--k links

#ifdef MPP_LAND
         call updateLake_seq(RESHT,nlakes,tmpRESHT)
         call updateLake_seq(QLAKEO,nlakes,tmpQLAKEO)
         call updateLake_seq(QLAKEI,nlakes,tmpQLAKEI)
#endif

!yw check
!        gQLINK = 0.0
!        call ReachLS_write_io(tmpQLINK(:,2), gQLINK(:,2))
!        call ReachLS_write_io(tmpQLINK(:,1), gQLINK(:,1))
!        write(6,*) " io_id = ", io_id
!        if(my_id .eq. io_id) then
!            write(71,*) gQLINK(:,1)
!            call flush(71)
!            call flush(72)
!        endif

          do k = 1, NLINKSL

            !write (lulog,'(/a)') ' BEFORE FINAL CHECK: Subroutine drive_CHANNEL'
            !write (lulog,'(a,2i5)') ' k, typel(k)=', k, typel(k)
            !write (lulog,'(a,5x,e12.5)') ' qlink(k,2)=', qlink(k,2)
            !write (lulog,'(a,5x,e12.5)') ' tmpQLINK(k,2)=', tmpQLINK(k,2)

            do_swap = .true.
            if ( typel(k) == 1 ) do_swap = .false.
            if ( typel(k) == 2 ) do_swap = .false.

!           if(TYPEL(k) .ne. 2) then

            if( do_swap ) then
               QLINK(k,2) = tmpQLINK(k,2)
            endif

            !write (lulog,'(/a)') ' AFTER FINAL CHECK: Subroutine drive_CHANNEL'
            !write (lulog,'(a,2i5)') ' k, typel(k)=', k, typel(k)
            !write (lulog,'(a,5x,e12.5)') ' qlink(k,2)=', qlink(k,2)
            !write (lulog,'(a,5x,e12.5)') ' tmpQLINK(k,2)=', tmpQLINK(k,2)

            QLINK(k,1) = QLINK(k,2)    !assing link flow of current to be previous for next time step
         end do

     call do_mpi_reservoir ( my_id, io_id, do_res_calc, ldebug )

   end do ! nsteps

#ifdef HYDRO_D
          print *, "END OF ALL REACHES...",KRT,DT_STEPS
#endif

!    END DO !-- krt timestep for muksingumcunge routing

   elseif(channel_option .eq. 3) then   !--- route using the diffusion scheme on nodes not links

#ifdef MPP_LAND
         call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,HLINK,NLINKS,99)
         call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,CVOL,NLINKS,99)
#endif

         KRT = 0                  !-- initialize the time counter
         minDTCT = 0.01           ! define minimum routing sub-timestep (s), simulation will end with smaller timestep
         DTCT = min(max(DTCT*2.0, minDTCT),DTRT_CH)
       
         HLINKTMP = HLINK         !-- temporary storage of the water elevations (m)
         CVOLTMP = CVOL           !-- temporary storage of the volume of water in channel (m^3)
         QLAKEIP = QLAKEI         !-- temporary lake inflow from previous timestep  (cms)

!        call check_channel(77,HLINKTMP,1,nlinks)
!        call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,ZELEV,NLINKS,99)
 crnt:   DO                      !-- loop on the courant condition
          QSUM     = 0.              !-- initialize the total flow out of each cell to zero
          QSUM8     = 0.              !-- initialize the total flow out of each cell to zero
          QLAKEI8  = 0.              !-- set the lake inflow as zero
          QLAKEI   = 0.              !-- set the lake inflow as zero
          QLLAKE   = 0.              !-- initialize each lake's lateral inflow to zero  
          QLLAKE8   = 0.              !-- initialize each lake's lateral inflow to zero  
          DT_STEPS = INT(DT/DTCT)   !-- fix the timestep
          QLateral = 0. 
!DJG GW-chan coupling variables...
          if(gwBaseSwCRT == 3) then
	  Q_GW_CHAN_FLUX = 0.
	  qgw_chanrt     = 0.
          end if
         
!         ZWATTBLRT=1.0   !--HARDWIRE, remove this and pass in from subsfc/gw routing routines...


!-- vectorize
!--------------------- 
#ifdef MPP_LAND
         DO iyw = 1,yw_MPP_NLINKS
         i = nlinks_index(iyw)
#else
         DO i = 1,NLINKS
#endif
          
           if(node_area(i) .eq. 0) then
               write(6,*) "FATAL ERROR: node_area(i) is zero. i=", i
               call hydro_stop("In drive_CHANNEL() - Error node_area") 
           endif

           

nodeType:if((CH_NETRT(CHANXI(i), CHANYJ(i) ) .eq. 0) .and. &
              (LAKE_MSKRT(CHANXI(i),CHANYJ(i)) .lt.0) ) then !--a reg. node
              
gwOption:   if(gwBaseSwCRT == 3) then

             ! determine potential gradient between groundwater head and channel stage
             ! units in (m)
             dzGwChanHead(i) = gwHead(CHANXI(i),CHANYJ(i)) - (HLINK(i)+ZELEV(i)) 

             if(gwChanCondSw .eq. 0) then
	       
                qgw_chanrt(CHANXI(i),CHANYJ(i)) = 0.
	        
             else if(gwChanCondSw .eq. 1 .and. dzGwChanHead(i) > 0) then
	       
	       ! channel bed interface, units in (m^3/s), flux into channel...
	       ! BF todo: consider channel width
                qgw_chanrt(CHANXI(i),CHANYJ(i)) = gwChanCondConstIn * dzGwChanHead(i) &
                                                * CHANLEN(i) * 2. 

             else if(gwChanCondSw .eq. 1 .and. dzGwChanHead(i) < 0) then
	       
	       ! channel bed interface, units in (m^3/s), flux out of channel...
	       ! BF todo: consider channel width
                qgw_chanrt(CHANXI(i),CHANYJ(i)) = max(-0.005, gwChanCondConstOut * dzGwChanHead(i) &
                                                * CHANLEN(i) * 2.)
!              else if(gwChanCondSw .eq. 2 .and. dzGwChanHead(i) > 0) then  TBD: exponential dependency
!              else if(gwChanCondSw .eq. 2 .and. dzGwChanHead(i) > 0) then
	       
             else
	       
	        qgw_chanrt(CHANXI(i),CHANYJ(i)) = 0.
	        
             end if
             
             Q_GW_CHAN_FLUX(i) = qgw_chanrt(CHANXI(i),CHANYJ(i))
!             if ( i .eq. 1001 ) then
!                print *, Q_GW_CHAN_FLUX(i), dzGwChanHead(i), ELRT(CHANXI(i),CHANYJ(i)), HLINK(i), ZELEV(i)
!             end if
!              if ( Q_GW_CHAN_FLUX(i) .lt. 0. ) then   !-- temporary hardwire for only allowing flux into channel...REMOVE later...
!                 Q_GW_CHAN_FLUX(i) = 0.
! 	        qgw_chanrt(CHANXI(i),CHANYJ(i)) = 0.
!              end if
            
            else
	      Q_GW_CHAN_FLUX(i) = 0.
	    end if gwOption


              QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))) =  &
!DJG  awaiting gw-channel exchg...  Q_GW_CHAN_FLUX(i)+& ...obsolete-> ((QSUBRT(CHANXI(i),CHANYJ(i))+&
                Q_GW_CHAN_FLUX(i)+&
                ((QSTRMVOLRT(CHANXI(i),CHANYJ(i))+&
                 QINFLOWBASE(CHANXI(i),CHANYJ(i))) &
                   /DT_STEPS*node_area(i)/1000/DTCT)
	       if((QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))).lt.0.) .and. (gwChanCondSw == 0)) then
#ifdef HYDRO_D
               print*, "i, CHANXI(i),CHANYJ(i) = ", i, CHANXI(i),CHANYJ(i)
               print *, "NEGATIVE Lat inflow...",QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))), &
                         QSUBRT(CHANXI(i),CHANYJ(i)),QSTRMVOLRT(CHANXI(i),CHANYJ(i)), &
                         QINFLOWBASE(CHANXI(i),CHANYJ(i))
#endif
               elseif (QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))) .gt. 1.0) then
!#ifdef HYDRO_D
!               print *, "LatIn(Ql,Qsub,Qstrmvol)..",i,QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))), &
!                          QSUBRT(CHANXI(i),CHANYJ(i)),QSTRMVOLRT(CHANXI(i),CHANYJ(i))
!#endif
               end if

         elseif(LAKE_MSKRT(CHANXI(i),CHANYJ(i)) .gt. 0 .and. &
!               (LAKE_MSKRT(CHANXI(i),CHANYJ(i)) .ne. -9999)) then !--a lake node
                (CH_NETRT(CHANXI(i),CHANYJ(i)) .le. 0)) then !--a lake node
              QLLAKE8(LAKE_MSKRT(CHANXI(i),CHANYJ(i))) = &
                 QLLAKE8(LAKE_MSKRT(CHANXI(i),CHANYJ(i))) + &
                 (LAKEINFLORT(CHANXI(i),CHANYJ(i))+ &
                 QINFLOWBASE(CHANXI(i),CHANYJ(i))) &
                 /DT_STEPS*node_area(i)/1000/DTCT
         elseif(CH_NETRT(CHANXI(i),CHANYJ(i)) .gt. 0) then  !pour out of lake
                 QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))) =  &
                   QLAKEO(CH_NETRT(CHANXI(i),CHANYJ(i)))  !-- previous timestep
         endif nodeType

        ENDDO


#ifdef MPP_LAND
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,QLateral,NLINKS,99)
    if(NLAKES .gt. 0) then
       !yw call MPP_CHANNEL_COM_REAL(LAKE_MSKRT   ,ixrt,jxrt,QLLAKE,NLAKES,99)
       call sum_real8(QLLAKE8,NLAKES)
       QLLAKE = QLLAKE8
    endif
#endif

          !-- compute conveyances, with known depths (just assign to QLINK(,1)
          !--QLINK(,2) will not be used), QLINK is the flow across the node face
          !-- units should be m3/second.. consistent with QL (lateral flow)

#ifdef MPP_LAND
         DO iyw = 1,yw_MPP_NLINKS
         i = nlinks_index(iyw)
#else
           DO i = 1,NLINKS
#endif
           if (TYPEL(i) .eq. 0 .AND. HLINKTMP(FROM_NODE(i)) .gt. RETDEP_CHAN) then 
               if(from_node(i) .ne. to_node(i) .and. (to_node(i) .gt. 0) .and.(from_node(i) .gt. 0) ) &  ! added by Wei Yu
                   QLINK(i,1)=DIFFUSION(i,ZELEV(FROM_NODE(i)),ZELEV(TO_NODE(i)), &
                     HLINKTMP(FROM_NODE(i)),HLINKTMP(TO_NODE(i)), &
                     CHANLEN(i), MannN(i), Bw(i), ChSSlp(i))
            else !--  we are just computing critical depth for outflow points
               QLINK(i,1) =0.
            endif
          ENDDO

#ifdef MPP_LAND
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,QLINK(:,1),NLINKS,99)
#endif
 

          !-- compute total flow across face, into node
#ifdef MPP_LAND
         DO iyw = 1,yw_mpp_nlinks
         i = nlinks_index(iyw)
#else
          DO i = 1,NLINKS                                                 !-- inflow to node across each face
#endif
           if(TYPEL(i) .eq. 0) then                                       !-- only regular nodes have to attribute
              QSUM8(TO_NODE(i)) = QSUM8(TO_NODE(i)) + QLINK(i,1)
           endif
          END DO

#ifdef MPP_LAND
    call MPP_CHANNEL_COM_REAL8(Link_location,ixrt,jxrt,qsum8,NLINKS,0)
#endif
    qsum = qsum8



#ifdef MPP_LAND
         do iyw = 1,yw_mpp_nlinks
         i = nlinks_index(iyw)
#else
         do i = 1,NLINKS                                                 !-- outflow from node across each face
#endif
            QSUM(FROM_NODE(i)) = QSUM(FROM_NODE(i)) - QLINK(i,1)
         end do
#ifdef MPP_LAND
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,qsum,NLINKS,99)
#endif


         flag = 99


#ifdef MPP_LAND
         do iyw = 1,yw_MPP_NLINKS
             i = nlinks_index(iyw)
#else
         do i = 1, NLINKS                                                !--- compute volume and depth at each node
#endif
 
           if( TYPEL(i).eq.0 .and. CVOLTMP(i) .ge. 0.001 .and.(CVOLTMP(i)-QSUM(i)*DTCT)/CVOLTMP(i) .le. -0.01 ) then  
            flag = -99
#ifdef HYDRO_D
            write(6,*) "******* start diag ***************"
            write(6,*) "Unstable at node ",i, "i=",CHANXI(i),"j=",CHANYJ(i)
            write(6,*) "Unstatble at node ",i, "lat=",latval(CHANXI(i),CHANYJ(i)), "lon=",lonval(CHANXI(i),CHANYJ(i))
            write(6,*) "TYPEL, CVOLTMP, QSUM, QSUM*DTCT",TYPEL(i), CVOLTMP(i), QSUM(i), QSUM(i)*DTCT
            write(6,*) "qsubrt, qstrmvolrt,qlink",QSUBRT(CHANXI(i),CHANYJ(i)),QSTRMVOLRT(CHANXI(i),CHANYJ(i)),qlink(i,1),qlink(i,2)
!              write(6,*) "current nodes, z, h", ZELEV(FROM_NODE(i)),HLINKTMP(FROM_NODE(i))
!           if(TO_NODE(i) .gt. 0) then
!              write(6,*) "to nodes, z, h", ZELEV(TO_NODE(i)), HLINKTMP(TO_NODE(i))
!           else
!              write(6,*) "no to nodes   "
!           endif
               write(6,*) "CHANLEN(i), MannN(i), Bw(i), ChSSlp(i) ", CHANLEN(i), MannN(i), Bw(i), ChSSlp(i)
            write(6,*) "*******end of  diag ***************"
#endif
            
            goto 999  
            endif 
          enddo 

999 continue
#ifdef MPP_LAND
        call mpp_same_int1(flag)
#endif


        if(flag < 0  .and. DTCT >0.1)   then   
             
             ! call smoth121(HLINK,nlinks,maxv_p,pnode,to_node)

             if(DTCT .gt. minDTCT) then                !-- timestep in seconds
              DTCT = max(DTCT/2 , minDTCT)             !-- 1/2 timestep
              KRT = 0                                  !-- restart counter
              HLINKTMP = HLINK                         !-- set head and vol to start value of timestep
              CVOLTMP = CVOL
              CYCLE crnt                               !-- start cycle over with smaller timestep
             else
              write(6,*) "Courant error with smallest routing timestep DTCT: ",DTCT
!              call hydro_stop("drive_CHANNEL")
              DTCT = 0.1
              HLINKTMP = HLINK                          !-- set head and volume to start values of timestep
              CVOLTMP  = CVOL
              goto 998  
             end if
        endif 

998 continue


#ifdef MPP_LAND
        do iyw = 1,yw_MPP_NLINKS
            i = nlinks_index(iyw)
#else
        do i = 1, NLINKS                                                !--- compute volume and depth at each node
#endif
 
           if(TYPEL(i) .eq. 0) then                   !--  regular channel grid point, compute volume
              CVOLTMP(i) = CVOLTMP(i) + (QSUM(i) + QLateral(i) )* DTCT
              if((CVOLTMP(i) .lt. 0) .and. (gwChanCondSw == 0)) then 
#ifdef HYDRO_D
                print *, "WARNING! channel volume less than 0:i,CVOL,QSUM,QLat", &
                               i, CVOLTMP(i),QSUM(i),QLateral(i),HLINK(i)
#endif
                CVOLTMP(i) =0 
              endif

           elseif(TYPEL(i) .eq. 1) then               !-- pour point, critical depth downstream 

              if (QSUM(i)+QLateral(i) .lt. 0) then
              else

!DJG remove to have const. flux b.c....   CD(i) =CRITICALDEPTH(i,abs(QSUM(i)+QLateral(i)), Bw(i), 1./ChSSlp(i))
                  CD(i) = HLINKTMP(i)  !This is a temp hardwire for flow depth for the pour point...
              endif

               ! change in volume is inflow, lateral flow, and outflow 
               !yw DIFFUSION(i,ZELEV(i),ZELEV(i)-(So(i)*DXRT),HLINKTMP(i), &
                   CVOLTMP(i) = CVOLTMP(i) + (QSUM(i) + QLateral(i) - &
                       DIFFUSION(i,ZELEV(i),ZELEV(i)-(So(i)*CHANLEN(i)),HLINKTMP(i), &
                       CD(i),CHANLEN(i), MannN(i), Bw(i), ChSSlp(i)) ) * DTCT
          elseif (TYPEL(i) .eq. 2) then              !--- into a reservoir, assume critical depth
              if ((QSUM(i)+QLateral(i) .lt. 0) .and. (gwChanCondSw == 0)) then
#ifdef HYDRO_D
               print *, i, 'CrtDpth Qsum+QLat into lake< 0',QSUM(i), QLateral(i)
#endif
             else
!DJG remove to have const. flux b.c....    CD(i) =CRITICALDEPTH(i,abs(QSUM(i)+QLateral(i)), Bw(i), 1./ChSSlp(i))
               CD(i) = HLINKTMP(i)  !This is a temp hardwire for flow depth for the pour point...
             endif
 
              !-- compute volume in reach (m^3)
                   CVOLTMP(i) = CVOLTMP(i) + (QSUM(i) + QLateral(i) - &
                          DIFFUSION(i,ZELEV(i),ZELEV(i)-(So(i)*CHANLEN(i)),HLINKTMP(i), &
                             CD(i) ,CHANLEN(i), MannN(i), Bw(i), ChSSlp(i)) ) * DTCT
          else
              print *, "FATAL ERROR: This node does not have a type.. error TYPEL =", TYPEL(i)
              call hydro_stop("In drive_CHANNEL() - error TYPEL") 
          endif
           
          if(TYPEL(i) == 0) then !-- regular channel node, finalize head and flow
              HLINKTMP(i) = HEAD(i, CVOLTMP(i)/CHANLEN(i),Bw(i),1/ChSSlp(i))  !--updated depth 
          else
              HLINKTMP(i) = CD(i)  !!!   CRITICALDEPTH(i,QSUM(i)+QLateral(i), Bw(i), 1./ChSSlp(i)) !--critical depth is head
          endif 

          if(TO_NODE(i) .gt. 0) then
             if(LAKENODE(TO_NODE(i)) .gt. 0) then
                  QLAKEI8(LAKENODE(TO_NODE(i))) = QLAKEI8(LAKENODE(TO_NODE(i))) + QLINK(i,1)
             endif
          endif

        END DO  !--- done processing all the links

#ifdef MPP_LAND
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,CVOLTMP,NLINKS,99)
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,CD,NLINKS,99)
    if(NLAKES .gt. 0) then
!       call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLAKEI,NLAKES,99)
        call sum_real8(QLAKEI8,NLAKES)
        QLAKEI = QLAKEI8
    endif
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,HLINKTMP,NLINKS,99)
#endif 
!   call check_channel(83,CVOLTMP,1,nlinks)
!   call check_channel(84,CD,1,nlinks)
!   call check_channel(85,HLINKTMP,1,nlinks)
!   call check_lake(86,QLAKEI,lake_index,nlakes)

           do i = 1, NLAKES !-- mass balances of lakes
#ifdef MPP_LAND
            if(lake_index(i) .gt. 0)  then
#endif
              CALL LEVELPOOL(i,QLAKEIP(i), QLAKEI(i), QLAKEO(i), QLLAKE(i), &
                DTCT, RESHT(i), HRZAREA(i), WEIRH(i), LAKEMAXH(i), WEIRC(i), &
                WEIRL(i), ORIFICEE(i), ORIFICEC(i), ORIFICEA(i))
                QLAKEIP(i) = QLAKEI(i)  !-- store total lake inflow for this timestep

#ifdef MPP_LAND
            endif
#endif
           enddo
#ifdef MPP_LAND
    if(NLAKES .gt. 0) then
!yw       call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLLAKE,NLAKES,99)
!yw       call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,RESHT,NLAKES,99)
!yw      call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLAKEO,NLAKES,99)
!yw      call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLAKEI,NLAKES,99)
!yw      call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLAKEIP,NLAKES,99)
         call updateLake_grid(QLLAKE, nlakes,lake_index)
         call updateLake_grid(RESHT,  nlakes,lake_index)
         call updateLake_grid(QLAKEO, nlakes,lake_index)
         call updateLake_grid(QLAKEI, nlakes,lake_index)
         call updateLake_grid(QLAKEIP,nlakes,lake_index)
    endif
#endif


#ifdef MPP_LAND
         do iyw = 1,yw_MPP_NLINKS
            i = nlinks_index(iyw)
#else
         do i = 1, NLINKS                                                !--- compute volume and depth at each node
#endif
            if(TYPEL(i) == 0) then !-- regular channel node, finalize head and flow
                   QLINK(i,1)=DIFFUSION(i,ZELEV(FROM_NODE(i)),ZELEV(TO_NODE(i)), &
                      HLINKTMP(FROM_NODE(i)),HLINKTMP(TO_NODE(i)), &
                      CHANLEN(i), MannN(i), Bw(i), ChSSlp(i))
            endif
         enddo

#ifdef MPP_LAND
          call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,QLINK(:,1),NLINKS,99)
#endif

           KRT = KRT + 1                     !-- iterate on the timestep
           if(KRT .eq. DT_STEPS) exit crnt   !-- up to the maximum time in interval

          end do crnt   !--- DTCT timestep of DT_STEPS
 
           HLINK = HLINKTMP                 !-- update head based on final solution in timestep
           CVOL  = CVOLTMP                  !-- update volume
        else                                !-- no channel option apparently selected
         print *, "FATAL ERROR: no channel option selected"
         call hydro_stop("In drive_CHANNEL() - no channel option selected") 
        endif

#ifdef HYDRO_D
         write(6,*) "finished call drive_CHANNEL"
#endif

        if (KT .eq. 1) KT = KT + 1

#ifdef MPP_LAND
       if (my_id == io_id) then
           if(allocated(tmpRESHT))  deallocate(tmpRESHT)
           if(allocated(tmpQLAKEO))  deallocate(tmpQLAKEO)
           if(allocated(tmpQLAKEI))  deallocate(tmpQLAKEI)
       endif
#endif

end subroutine drive_CHANNEL
! ----------------------------------------------------------------

!-=======================================
     REAL FUNCTION AREAf(AREA,Bw,h,z)
     REAL :: AREA, Bw, z, h
       AREAf = (Bw+z*h)*h-AREA       !-- Flow area
     END FUNCTION AREAf

!-====critical depth function  ==========
     REAL FUNCTION CDf(Q,Bw,h,z)
     REAL :: Q, Bw, z, h
       if(h .le. 0) then
         print *, "FATAL ERROR: head is zero, will get division by zero error"
         call hydro_stop("In CDf() - head is zero") 
       else
       CDf = (Q/((Bw+z*h)*h))/(sqrt(9.81*(((Bw+z*h)*h)/(Bw + 2.0*z*h)))) - 1.0  !--critical depth function
       endif
     END FUNCTION CDf

!=======find flow depth in channel with bisection Chapra pg. 131
    REAL FUNCTION HEAD(idx,AREA,Bw,z)  !-- find the water elevation given wetted area, 
                                         !--bottom widith and side channel.. index was for debuggin
     REAL :: Bw,z,AREA,test           
     REAL :: hl, hu, hr, hrold
     REAL :: fl, fr,error                !-- function evaluation
     INTEGER :: maxiter, idx

     error = 1.0
     maxiter = 0
     hl = 0.00001   !-- minimum depth is small
     hu = 30.  !-- assume maximum depth is 30 meters

    if (AREA .lt. 0.00001) then 
     hr = 0.
    else
       ! JLM: .gt. "0" is somewhat alarming. We really should have a constant like zero_r4
      do while ((AREAf(AREA,BW,hl,z)*AREAf(AREA,BW,hu,z)) .gt. 0.0 .and. maxiter .lt. 100) 
       !-- allows for larger , smaller heads 
       if(AREA .lt. 1.) then
        hl=hl/2
       else
        hu = hu * 2
       endif
       maxiter = maxiter + 1
        
      end do

      maxiter =0
      hr = 0
      fl = AREAf(AREA,Bw,hl,z)
      do while (error .gt. 0.0001 .and. maxiter < 1000)
        hrold = hr
        hr = (hl+hu)/2
        fr =  AREAf(AREA,Bw,hr,z)
        maxiter = maxiter + 1
         if (hr .ne. 0) then
          error = abs((hr - hrold)/hr)
         endif
        test = fl * fr
         if (test.lt.0) then
           hu = hr
         elseif (test.gt.0) then
           hl=hr
           fl = fr
         else
           error = 0.0
         endif
      end do
     endif
     HEAD = hr

22   format("i,hl,hu,Area",i5,2x,f12.8,2x,f6.3,2x,f6.3,2x,f6.3,2x,f9.1,2x,i5)

    END FUNCTION HEAD
!=================================
     REAL FUNCTION MANNING(h1,n,Bw,Cs)

     REAL :: Bw,h1,Cs,n
     REAL :: z, AREA,R,Kd

     z = 1.0/Cs
     R = ((Bw + z*h1)*h1)/(Bw + 2.0*h1*sqrt(1.0 + z*z)) !-- Hyd Radius
     AREA = (Bw + z*h1)*h1        !-- Flow area
     Kd = (1.0/n) * (R**(2.0/3.0))*AREA     !-- convenyance
#ifdef HYDRO_D
     print *,"head, kd",  h1,Kd
#endif
     MANNING = Kd
     
     END FUNCTION MANNING

!=======find flow depth in channel with bisection Chapra pg. 131
     REAL FUNCTION CRITICALDEPTH(lnk, Q, Bw, z)  !-- find the critical depth
     REAL :: Bw, z, Q, test
     REAL :: hl, hu, hr, hrold
     REAL :: fl, fr, error   !-- function evaluation
     INTEGER :: maxiter
     INTEGER :: lnk

     error = 1.0
     maxiter = 0
     hl = 1.0e-5   !-- minimum depth is 0.00001 meters
!    hu = 35.       !-- assume maximum  critical depth 25 m
     hu = 100.       !-- assume maximum  critical depth 25 m

     if(CDf(Q, BW, hl, z) * CDf(Q, BW, hu, z) .gt. 0.0) then
      if(Q .gt. 0.001) then
#ifdef HYDRO_D
        print *, "interval won't work to find CD of lnk ", lnk
        print *, "Q, hl, hu", Q, hl, hu
        print *, "cd lwr, upr", CDf(Q, BW, hl, z), CDf(Q, BW, hu, z)
        ! call hydro_stop("In CRITICALDEPTH()") 
        CRITICALDEPTH = -9999
        return
#endif
      else
        Q = 0.0
      endif
     endif

     hr = 0.
     fl = CDf(Q, Bw, hl, z)

     if (Q .eq. 0.0) then
       hr = 0.
     else
      do while (error .gt. 0.0001 .and. maxiter < 1000)
        hrold = hr
        hr = (hl+hu)/2.0
        fr =  CDf(Q, Bw, hr, z)
        maxiter = maxiter + 1
         if (hr .ne. 0.0) then
          error = abs((hr - hrold)/hr)
         endif
        test = fl * fr
         if (test .lt. 0) then
           hu = hr
         elseif (test .gt. 0) then
           hl=hr
           fl = fr
         else
           error = 0.0
         endif

       end do
      endif

     CRITICALDEPTH = hr
     END FUNCTION CRITICALDEPTH

     
     REAL FUNCTION SGNf(val)  !-- function to return the sign of a number
     REAL:: val

     if (val .lt. 0) then
       SGNf= -1.
     elseif (val.gt.0) then
       SGNf= 1.
     else
       SGNf= 0.
     endif

     END FUNCTION SGNf
!================================================

     REAL FUNCTION fnDX(qp,Tw,So,Ck,dx,dt) !-- find channel sub-length for MK method
     REAL    :: qp,Tw,So,Ck,dx, dt,test
     REAL    :: dxl, dxu, dxr, dxrold
     REAL    :: fl, fr, error
     REAL    :: X
     INTEGER :: maxiter

     error = 1.0
     maxiter =0
     dxl = dx*0.9  !-- how to choose dxl???
     dxu = dx
     dxr=0

     do while (fnDXCDT(qp,Tw,So,Ck,dxl,dt)*fnDXCDT(qp,Tw,So,Ck,dxu,dt) .gt. 0 &
               .and. dxl .gt. 10)  !-- don't let dxl get too small
      dxl = dxl/1.1
     end do
     
      
     fl = fnDXCDT(qp,Tw,So,Ck,dxl,dt)
     do while (error .gt. 0.0001 .and. maxiter < 1000)
        dxrold = dxr
        dxr = (dxl+dxu)/2
        fr =  fnDXCDT(qp,Tw,So,Ck,dxr,dt)
        maxiter = maxiter + 1
         if (dxr .ne. 0) then
          error = abs((dxr - dxrold)/dxr)
         endif
        test = fl * fr
         if (test.lt.0) then
           dxu = dxr
         elseif (test.gt.0) then
           dxl=dxr
           fl = fr
         else
           error = 0.0
         endif
      end do
     FnDX = dxr

    END FUNCTION fnDX
!================================================
     REAL FUNCTION fnDXCDT(qp,Tw,So,Ck,dx,dt) !-- function to help find sub-length for MK method
     REAL    :: qp,Tw,So,Ck,dx,dt,X
     REAL    :: c,b  !-- coefficients on dx/cdt log approximation function
     
     c = 0.2407
     b = 1.16065
     X = 0.5-(qp/(2.0*Tw*So*Ck*dx))
     if (X .le. 0.0) then 
      fnDXCDT = -1.0 !0.115
     else
      fnDXCDT = (dx/(Ck*dt)) - (c*LOG(X)+b)  !-- this function needs to converge to 0
     endif
     END FUNCTION fnDXCDT
! ----------------------------------------------------------------------

    subroutine check_lake(unit,cd,lake_index,nlakes)
         use module_RT_data, only: rt_domain
         implicit none 
         integer :: unit,nlakes,i,lake_index(nlakes)
         real cd(nlakes)
#ifdef MPP_LAND
         call write_lake_real(cd,lake_index,nlakes)
#endif
         write(unit,*) cd
          call flush(unit)
         return
    end subroutine check_lake

    subroutine check_channel(unit,cd,did,nlinks)
         use module_RT_data, only: rt_domain
#ifdef MPP_LAND
  USE module_mpp_land
#endif
         implicit none 
         integer :: unit,nlinks,i, did
         real cd(nlinks)
#ifdef MPP_LAND
         real g_cd(rt_domain(did)%gnlinks)
         call write_chanel_real(cd,rt_domain(did)%map_l2g,rt_domain(did)%gnlinks,nlinks,g_cd)
         if(my_id .eq. IO_id) then
            write(unit,*) "rt_domain(did)%gnlinks = ",rt_domain(did)%gnlinks
           write(unit,*) g_cd
         endif
#else
           write(unit,*) cd
#endif
          call flush(unit)
          close(unit)
         return
    end subroutine check_channel
    subroutine smoth121(var,nlinks,maxv_p,from_node,to_node)
        implicit none
        integer,intent(in) ::  nlinks, maxv_p
        integer, intent(in), dimension(nlinks):: to_node
        integer, intent(in), dimension(nlinks):: from_node(nlinks,maxv_p)
        real, intent(inout), dimension(nlinks) :: var
        real, dimension(nlinks) :: vartmp
        integer :: i,j  , k, from,to
        integer :: plen
              vartmp = 0
              do i = 1, nlinks
                 to = to_node(i)
                 plen = from_node(i,1)
                 if(plen .gt. 1) then 
                     do k = 1, plen-1 
                         from = from_node(i,k+1)
                         if(to .gt. 0) then
                            vartmp(i) = vartmp(i)+0.25*(var(from)+2.*var(i)+var(to))
                         else
                            vartmp(i) = vartmp(i)+(2.*var(i)+var(from))/3.0
                         endif
                     end do
                     vartmp(i) = vartmp(i) /(plen-1)
                 else
                         if(to .gt. 0) then
                            vartmp(i) = vartmp(i)+(2.*var(i)+var(to)/3.0)
                         else
                            vartmp(i) = var(i)
                         endif
                 endif
              end do
              var = vartmp 
        return
    end subroutine smoth121

!   SUBROUTINE drive_CHANNEL for NHDPLUS
! ------------------------------------------------

     subroutine drive_CHANNEL_RSL(UDMP_OPT,KT, IXRT,JXRT,  &
        LAKEINFLORT, QSTRMVOLRT, TO_NODE, FROM_NODE, &
        TYPEL, ORDER, MAXORDER,   CH_LNKRT, &
        LAKE_MSKRT, DT, DTCT, DTRT_CH,MUSK, MUSX, QLINK, &
        CHANLEN, MannN, So, ChSSlp, Bw, Tw, Tw_CC, n_CC, &
        RESHT, HRZAREA, LAKEMAXH, WEIRH, WEIRC, WEIRL, ORIFICEC, ORIFICEA, &
        ORIFICEE,  CVOL, QLAKEI, QLAKEO, LAKENODE, &
        QINFLOWBASE, CHANXI, CHANYJ, channel_option,  &
        nlinks,NLINKSL, LINKID, node_area, qout_gwsubbas, &
        LAKEIDA, LAKEIDM, NLAKES, LAKEIDX, &
#ifdef MPP_LAND 
        nlinks_index,mpp_nlinks,yw_mpp_nlinks, &
        LNLINKSL, &
        gtoNode,toNodeInd,nToNodeInd,   &
#endif
         CH_LNKRT_SL, landRunOff  & 
#ifdef WRF_HYDRO_NUDGING
       , nudge &
#endif
       , accSfcLatRunoff, accBucket                  &
       , qSfcLatRunoff,     qBucket                  &
       , QLateral, velocity                          &
       , HLINK                                       &
       , nsize , OVRTSWCRT, SUBRTSWCRT, channel_only, channelBucket_only)

       use module_UDMAP, only: LNUMRSL, LUDRSL
       use module_namelist, only:  nlst_rt 

#ifdef WRF_HYDRO_NUDGING
       use module_RT_data, only: rt_domain
       use module_stream_nudging,  only: setup_stream_nudging,               & 
                                         nudge_term_all,                     &
                                         nudgeWAdvance,                      &
                                         nudge_apply_upstream_muskingumCunge
#endif 


       implicit none

! -------- DECLARATIONS ------------------------

       integer, intent(IN) :: IXRT,JXRT,channel_option, OVRTSWCRT, SUBRTSWCRT
       integer, intent(IN) :: NLAKES, NLINKSL, nlinks
       integer, intent(INOUT) :: KT   ! flag of cold start (1) or continue run.
       real, intent(IN), dimension(IXRT,JXRT)    :: QSTRMVOLRT
       real, intent(IN), dimension(IXRT,JXRT)    :: LAKEINFLORT
       real, intent(IN), dimension(IXRT,JXRT)    :: QINFLOWBASE
       real, dimension(ixrt,jxrt) :: landRunOff
       
       integer, intent(IN), dimension(IXRT,JXRT) :: CH_LNKRT
       integer, intent(IN), dimension(IXRT,JXRT) :: CH_LNKRT_SL
       
       integer, intent(IN), dimension(IXRT,JXRT) :: LAKE_MSKRT
       integer, intent(IN), dimension(:)         :: ORDER, TYPEL !--link
       integer, intent(IN), dimension(:)     :: TO_NODE, FROM_NODE
       integer, intent(IN), dimension(:)     :: CHANXI, CHANYJ
       real, intent(IN), dimension(:)        :: MUSK, MUSX
       real, intent(IN), dimension(:)        :: CHANLEN
       real, intent(IN), dimension(:)        :: So, MannN
       real, intent(IN), dimension(:)        :: ChSSlp,Bw,Tw  !--properties of nodes or links
       real, intent(IN), dimension(:)        :: Tw_CC, n_CC   ! properties of compound channel
       real                                      :: Km, X
       real , intent(INOUT), dimension(:,:)  :: QLINK 
       real , intent(INOUT), dimension(:)    :: HLINK

#ifdef WRF_HYDRO_NUDGING
       !! inout for applying previous nudge to upstream components of flow at gages
       real, intent(inout),    dimension(:)    :: nudge
#endif

       real, dimension(:), intent(inout)     :: QLateral !--lateral flow
       real, dimension(:), intent(out)       :: velocity
       real*8, dimension(:), intent(inout)     :: accSfcLatRunoff, accBucket 
       real  , dimension(:), intent(out)     :: qSfcLatRunoff  ,   qBucket
              
       real ,  dimension(NLINKSL,2) :: tmpQLINK
       real, intent(IN)                          :: DT    !-- model timestep
       real, intent(IN)                          :: DTRT_CH  !-- routing timestep
       real, intent(INOUT)                       :: DTCT
       real                                      :: minDTCT !BF minimum routing timestep
       integer, intent(IN)                       :: MAXORDER
       real , intent(IN), dimension(:)   :: node_area
       
       !DJG GW-chan coupling variables...
       real, dimension(NLINKS)                   :: dzGwChanHead
       real, dimension(NLINKS)                   :: Q_GW_CHAN_FLUX     !DJG !!! Change 'INTENT' to 'OUT' when ready to update groundwater state...
       real, dimension(IXRT,JXRT)                :: ZWATTBLRT          !DJG !!! Match with subsfce/gw routing & Change 'INTENT' to 'INOUT' when ready to update groundwater state...
       
       !-- lake params
       
       real, intent(IN), dimension(:)       :: HRZAREA  !-- horizontal area (km^2)
       real, intent(IN), dimension(:)       :: LAKEMAXH !-- maximum lake depth  (m^2)
       real, intent(IN), dimension(:)       :: WEIRH    !--  lake depth  (m^2)
       real, intent(IN), dimension(:)       :: WEIRC    !-- weir coefficient
       real, intent(IN), dimension(:)       :: WEIRL    !-- weir length (m)
       real, intent(IN), dimension(:)       :: ORIFICEC !-- orrifice coefficient
       real, intent(IN), dimension(:)       :: ORIFICEA !-- orrifice area (m^2)
       real, intent(IN), dimension(:)       :: ORIFICEE !-- orrifce elevation (m)
       integer, intent(IN), dimension(:)    :: LAKEIDM  !-- NHDPLUS lakeid for lakes to be modeled
       
       real, intent(INOUT), dimension(:)    :: RESHT    !-- reservoir height (m)
       real, intent(INOUT), dimension(:)    :: QLAKEI   !-- lake inflow (cms)
       real,                dimension(NLAKES)    :: QLAKEIP  !-- lake inflow previous timestep (cms)
       real, intent(INOUT), dimension(NLAKES)    :: QLAKEO   !-- outflow from lake used in diffusion scheme
       
       integer, intent(IN), dimension(:)    :: LAKENODE !-- outflow from lake used in diffusion scheme
       integer, intent(IN), dimension(:)   :: LINKID   !--  id of channel elements for linked scheme
       integer, intent(IN), dimension(:)   :: LAKEIDA  !--  (don't need) NHDPLUS lakeid for all lakes in domain
       integer, intent(IN), dimension(:)   :: LAKEIDX  !--  the sequential index of the lakes id by com id
       
       real, dimension(NLINKS)                   :: QSUM     !--mass bal of node
       real, dimension(NLAKES)                   :: QLLAKE   !-- lateral inflow to lake in diffusion scheme
       integer :: nsize
       
       !-- Local Variables
       integer                      :: i,j,k,t,m,jj,ii,lakeid, kk,KRT,node, UDMP_OPT
       integer                      :: DT_STEPS               !-- number of timestep in routing
       real                         :: Qup,Quc                !--Q upstream Previous, Q Upstream Current, downstream Previous
       real                         :: bo                     !--critical depth, bnd outflow just for testing
       
       real ,dimension(NLINKS)                          :: CD    !-- critical depth
       real, dimension(IXRT,JXRT)                       :: tmp
       real, dimension(nlinks)                          :: tmp2
       real, intent(INOUT), dimension(:)           :: CVOL
       
#ifdef MPP_LAND
       real*8,  dimension(LNLINKSL) :: LQLateral
       real*8,  dimension(LNLINKSL) :: tmpLQLateral
       real,  dimension(NLINKSL)    :: tmpQLateral

       integer nlinks_index(:)
       integer  iyw, yw_mpp_nlinks, mpp_nlinks
       real     ywtmp(ixrt,jxrt)
       integer LNLINKSL
       integer, dimension(:)         ::  toNodeInd
       integer, dimension(:,:)       ::  gtoNode
       integer  :: nToNodeInd
       real, dimension(nToNodeInd,2) :: gQLINK
#else
       real*8,  dimension(NLINKS) :: tmpLQLateral
       real,  dimension(NLINKSL) :: tmpQLateral
       real,  dimension(NLINKSL) :: LQLateral
#endif
       integer flag
       integer, intent(in) :: channel_only, channelBucket_only
       
       integer :: n, kk2, nt, nsteps  ! tmp 
       real, intent(in), dimension(:) :: qout_gwsubbas
       real, allocatable,dimension(:) :: tmpQLAKEO, tmpQLAKEI, tmpRESHT
       
#ifdef MPP_LAND
       if(my_id .eq. io_id) then
#endif
            allocate(tmpQLAKEO(NLAKES))
            allocate(tmpQLAKEI(NLAKES))
            allocate(tmpRESHT(NLAKES))
#ifdef MPP_LAND
        endif
#endif

        QLAKEIP = 0
        CD = 0  
        node = 1
        QSUM     = 0
        QLLAKE   = 0
        dzGwChanHead = 0.
        nsteps = (DT+0.5)/DTRT_CH

#ifdef WRF_HYDRO_NUDGING
         !! Initialize nudging for the current timestep.
         !! This establishes the data structure used to solve the nudges. 
         call setup_stream_nudging(0)  !! always zero b/c at beginning of hydro timestep
#endif /* WRF_HYDRO_NUDGING */


!---------------------------------------------
if(channel_only .eq. 1 .or. channelBucket_only .eq. 1) then
#ifdef HYDRO_D
   write(6,*), "channel_only or channelBucket_only is not zero. Special flux calculations."
   call flush(6)
#endif /* HYDRO_D */
   
!   if(nlst_rt(1)%output_channelBucket_influx .eq. 1 .or. &
!        nlst_rt(1)%output_channelBucket_influx .eq. 2       ) &
!        !! qScfLatRunoff = qLateral - qBucket
!        qSfcLatRunoff(1:NLINKSL) = qLateral(1:NLINKSL) - qout_gwsubbas(1:NLINKSL)

   if(nlst_rt(1)%output_channelBucket_influx .eq. 1 .or. &
      nlst_rt(1)%output_channelBucket_influx .eq. 2       ) then

      if(channel_only .eq. 1) &
        !! qScfLatRunoff = qLateral - qBucket
        qSfcLatRunoff(1:NLINKSL) = qLateral(1:NLINKSL) - qout_gwsubbas(1:NLINKSL)

      if(channelBucket_only .eq. 1) &
        !! qScfLatRunoff = qLateral - qBucket
        qSfcLatRunoff(1:NLINKSL) = qLateral(1:NLINKSL)

   end if
   
   if(nlst_rt(1)%output_channelBucket_influx .eq. 3) &
        accSfcLatRunoff(1:NLINKSL) = qSfcLatRunoff * DT

else

   QLateral = 0 !! the variable solved in this section. Channel only knows this already.
   LQLateral = 0          !-- initial lateral flow to 0 for this reach

   tmpQLateral = 0  !! WHY DOES THIS tmp variable EXIST?? Only for accumulations??
   tmpLQLateral = 0

   ! NHDPLUS maping
   if(OVRTSWCRT .eq. 0)      then
      do k = 1, LNUMRSL
         ! get from land grid runoff
         do m = 1, LUDRSL(k)%ncell  
            ii =  LUDRSL(k)%cell_i(m)
            jj =  LUDRSL(k)%cell_j(m)
            LQLateral(k) = LQLateral(k)+landRunOff(ii,jj)*LUDRSL(k)%cellweight(m)/1000 & 
                 *LUDRSL(k)%cellArea(m)/DT
            tmpLQLateral(k) = tmpLQLateral(k)+landRunOff(ii,jj)*LUDRSL(k)%cellweight(m)/1000 & 
                 *LUDRSL(k)%cellArea(m)/DT
         end do
      end do

#ifdef MPP_LAND
      call updateLinkV(tmpLQLateral, tmpQLateral)
#endif
      if(NLINKSL .gt. 0) then
         if (nlst_rt(1)%output_channelBucket_influx .eq. 1 .or. &
             nlst_rt(1)%output_channelBucket_influx .eq. 2      ) &
               qSfcLatRunoff(1:NLINKSL) = tmpQLateral(1:NLINKSL)
         if (nlst_rt(1)%output_channelBucket_influx .eq. 3) &
              accSfcLatRunoff(1:NLINKSL) = accSfcLatRunoff(1:NLINKSL) + tmpQLateral(1:NLINKSL) * DT
      endif
      tmpLQLateral = 0  !! JLM:: These lines imply that squeege runoff does not count towards 
      tmpQLateral = 0   !! JLM:: accumulated runoff to be output but it does for internal QLateral?
      !! JLM: But then the next accumulation is added to the amt before zeroing? result
      !! JLM: should be identical to LQLateral.... I'm totally mystified.
   endif

   !! JLM:: if ovrtswcrt=0 and subrtswcrt=1, then this accumulation is calculated twice for LQLateral???
   !! This impiles that if overland routing is off and subsurface routing is on, that
   !! qstrmvolrt represents only the subsurface contribution to the channel.
   if(OVRTSWCRT .ne. 0 .or. SUBRTSWCRT .ne. 0 ) then
      do k = 1, LNUMRSL
         ! get from channel grid
         do m = 1, LUDRSL(k)%ngrids
            ii =  LUDRSL(k)%grid_i(m)
            jj =  LUDRSL(k)%grid_j(m)
            LQLateral(k) = LQLateral(k) + QSTRMVOLRT(ii,jj)*LUDRSL(k)%weight(m)/1000 & 
                 *LUDRSL(k)%nodeArea(m)/DT
            tmpLQLateral(k) = tmpLQLateral(k) + QSTRMVOLRT(ii,jj)*LUDRSL(k)%weight(m)/1000 & 
                 *LUDRSL(k)%nodeArea(m)/DT
         end do
      end do

#ifdef MPP_LAND
      call updateLinkV(tmpLQLateral, tmpQLateral)
#endif

      !! JLM:: again why output in this conditional ?? why not just output QLateral
      !! after this section ????
      if(NLINKSL .gt. 0) then 
         if(nlst_rt(1)%output_channelBucket_influx .eq. 1 .OR. &
            nlst_rt(1)%output_channelBucket_influx .eq. 2       ) &
              qSfcLatRunoff(1:NLINKSL) = tmpQLateral(1:NLINKSL)
         if(nlst_rt(1)%output_channelBucket_influx .eq. 3) &
              accSfcLatRunoff(1:NLINKSL) = accSfcLatRunoff(1:NLINKSL) + tmpQLateral(1:NLINKSL) * DT
      end if

   endif

#ifdef MPP_LAND
   call updateLinkV(LQLateral, QLateral(1:NLINKSL))
#else
   call hydro_stop("fatal error: NHDPlus only works for parallel now.")
   QLateral = LQLateral
#endif
endif !! (channel_only .eq. 1 .or. channelBucket_only .eq. 1) then; else; endif


!---------------------------------------------
!! If not running channelOnly, here is where the bucket model is picked up
if(channel_only .eq. 1) then
#ifdef HYDRO_D
   write(6,*), "channel_only is not zero. No bucket."
   call flush(6)
#endif /* HYDRO_D */
else
   !! REQUIRE BUCKET MODEL ON HERE?
   if(NLINKSL .gt. 0) QLateral(1:NLINKSL) = QLateral(1:NLINKSL) + qout_gwsubbas(1:NLINKSL)
endif  !! if(channel_only .eq. 1) then; else; endif

if(nlst_rt(1)%output_channelBucket_influx .eq. 1 .or. &
   nlst_rt(1)%output_channelBucket_influx .eq. 2       ) &
      qBucket(1:NLINKSL) = qout_gwsubbas(1:NLINKSL)
   
if(nlst_rt(1)%output_channelBucket_influx .eq. 3) &
     accBucket(1:NLINKSL) = accBucket(1:NLINKSL) + qout_gwsubbas(1:NLINKSL) * DT


!---------------------------------------------
!       QLateral = QLateral / nsteps
do nt = 1, nsteps
   
#ifdef MPP_LAND
   gQLINK = 0
   call gbcastReal2(toNodeInd,nToNodeInd,QLINK(1:NLINKSL,2), NLINKSL, gQLINK(:,2))
   call gbcastReal2(toNodeInd,nToNodeInd,QLINK(1:NLINKSL,1), NLINKSL, gQLINK(:,1)) 
   !---------- route other reaches, with upstream inflow
#endif
   
   tmpQlink = 0
#ifdef MPP_LAND
   if(my_id .eq. io_id) then
#endif
      tmpQLAKEO = QLAKEO
      tmpQLAKEI = QLAKEI
      tmpRESHT = RESHT
#ifdef MPP_LAND
   endif
#endif
   
   
   do k = 1,NLINKSL
      
      Quc  = 0
      Qup  = 0
      
      !process as standard link or a lake inflow link, or lake outflow link
      ! link flowing out of lake, accumulate all the inflows with the revised TO_NODEs
      ! TYPEL = -999 stnd; TYPEL=1 outflow from lake; TYPEL = 3 inflow to a lake
      
      if(TYPEL(k) .ne. 2) then ! don't process internal lake links only
         
#ifdef MPP_LAND
         !using mapping index
         do n = 1, gtoNODE(k,1)
            m = gtoNODE(k,n+1)
            !! JLM - I think gQLINK(,2) is actually previous. Global array never sees current. Seeing
            !! current would require global communication at the end of each loop through k
            !! (=kth reach). Additionally, how do you synchronize to make sure the upstream are all
            !! done before doing the downstream?
            if(gQLINK(m,2) .gt. 0)   Quc = Quc + gQLINK(m,2)  !--accum of upstream inflow of current timestep (2)  
            if(gQLINK(m,1) .gt. 0)   Qup = Qup + gQLINK(m,1)  !--accum of upstream inflow of previous timestep (1)
         end do ! do i
#else
         do m = 1, NLINKSL                
            if (LINKID(k) .eq. TO_NODE(m)) then
               Quc = Quc + QLINK(m,2)  !--accum of upstream inflow of current timestep (2)
               Qup = Qup + QLINK(m,1)  !--accum of upstream inflow of previous timestep (1)
            endif
         end do ! do m
#endif
      endif !note that we won't process type 2 links, since they are internal to a lake
      
      
      !yw ### process each link k,
      !       There is a situation that different k point to the same LAKEIDX
      !        if(TYPEL(k) .eq. 1 .and. LAKEIDX(k) .gt. 0) then   !--link is a reservoir
      if(TYPEL(k) .eq. 1 ) then   !--link is a reservoir
         
         lakeid = LAKEIDX(k)
         if(lakeid .ge. 0) then
            call LEVELPOOL(lakeid,Qup, Quc, tmpQLINK(k,2), &
                 0.0, DTRT_CH, RESHT(lakeid), HRZAREA(lakeid), WEIRH(lakeid), LAKEMAXH(lakeid), &
                 WEIRC(lakeid), WEIRL(lakeid),ORIFICEE(lakeid), ORIFICEC(lakeid), ORIFICEA(lakeid))
            
            QLAKEO(lakeid)  = tmpQLINK(k,2) !save outflow to lake
            QLAKEI(lakeid)  = Quc           !save inflow to lake
         endif
105      continue
         
         
      elseif (channel_option .eq. 1) then  !muskingum routing
         Km = MUSK(k)
         X = MUSX(k)
         tmpQLINK(k,2) = MUSKING(k,Qup,(Quc+QLateral(k)),QLINK(k,1),DTRT_CH,Km,X) !upstream plust lateral inflow 
         
      elseif (channel_option .eq. 2) then ! muskingum cunge, don't process internal lake nodes TYP=2
         !              tmpQLINK(k,2) = MUSKINGCUNGE(k,Qup, Quc, QLINK(k,1), &
         !                  QLateral(k), DTRT_CH, So(k),  CHANLEN(k), &
         !                  MannN(k), ChSSlp(k), Bw(k), Tw(k) )
         
#ifdef WRF_HYDRO_NUDGING
         call nudge_apply_upstream_muskingumCunge( Qup,  Quc,  nudge(k),  k )
#endif
         
         call SUBMUSKINGCUNGE(&
              tmpQLINK(k,2), velocity(k), LINKID(k),     Qup,        Quc, QLINK(k,1), &
              QLateral(k),   DTRT_CH,     So(k), CHANLEN(k),                  &
              MannN(k),      ChSSlp(k),   Bw(k), Tw(k), Tw_CC(k), n_CC(k), HLINK(k) )
         
      else
#ifdef HYDRO_D
         print *, " no channel option selected"
#endif
         call hydro_stop("drive_CHANNEL") 
      endif
      
   end do  !--k links
   
   
#ifdef MPP_LAND
   call updateLake_seq(QLAKEO,nlakes,tmpQLAKEO)
   call updateLake_seq(QLAKEI,nlakes,tmpQLAKEI)
   call updateLake_seq(RESHT,nlakes,tmpRESHT)
#endif
   
   do k = 1, NLINKSL !tmpQLINK?
      if(TYPEL(k) .ne. 2) then   !only the internal lake nodes don't have info.. but need to save QLINK of lake out too
         QLINK(k,2) = tmpQLINK(k,2)
      endif
      QLINK(k,1) = QLINK(k,2)    !assigng link flow of current to be previous for next time step
   end do
   
   
#ifdef WRF_HYDRO_NUDGING
   if(.not. nudgeWAdvance) call nudge_term_all(qlink, nudge, int(nt*dtrt_ch))
#endif /* WRF_HYDRO_NUDGING */
  
   
!#ifdef HYDRO_D
!   print *, "END OF ALL REACHES...",KRT,DT_STEPS
!#endif
   
end do  ! nsteps

if (KT .eq. 1) KT = KT + 1

#ifdef MPP_LAND
if(my_id .eq. io_id)      then 
   if(allocated(tmpQLAKEO))  deallocate(tmpQLAKEO)
   if(allocated(tmpQLAKEI))  deallocate(tmpQLAKEI)
   if(allocated(tmpRESHT))  deallocate(tmpRESHT)
endif
#endif        

if (KT .eq. 1) KT = KT + 1  ! redundant?

end subroutine drive_CHANNEL_RSL

! ----------------------------------------------------------------
!
!***********************************************************************
!
subroutine do_mpi_reservoir ( my_id, io_id, do_res_calc, ldebug )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: my_id
integer, intent(in) :: io_id
logical, intent(in) :: do_res_calc
logical, intent(in) :: ldebug

!  Local declarations

integer :: nrloc
integer :: nsumr
integer :: nsumr_use
integer :: nsumrr
integer :: nsump
integer :: nr
integer :: np
integer :: id
integer :: istatus
integer :: dest
integer :: tag
integer :: src
integer :: nss
integer :: ierr
logical, parameter :: do_update = .true.
integer :: kkp

! Local Arrays

integer, dimension(MPI_STATUS_SIZE) :: status
integer, dimension(MPI_STATUS_SIZE,4) :: req_status

real, allocatable, dimension(:) :: cvolr
real, allocatable, dimension(:) :: celev
integer, allocatable, dimension(:) :: res_mpp_index

real, allocatable, dimension(:) :: recv_cvolr
real, allocatable, dimension(:) :: recv_celev
integer, allocatable, dimension(:) :: recv_res_mpp_index

integer, parameter :: ndim4 = 4
integer, dimension(ndim4) :: nreq_hold

! NOLA

if ( .not.do_update .or. .not.do_res_calc ) then
  return
end if

nsumr = 0

do nr = 1, nrmax
  if ( rinfo%lake_mpi_index(nr) > 0 ) then
    nsumr = nsumr + 1
  end if
end do

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir: do_res_calc section'
  write (lulog,'(a,i10)') ' my_id=', my_id
  write (lulog,'(a,i10)') ' nsumr=', nsumr
  call flush ( lulog )
end if

nreq_hold = -9999

if ( allocated(cvolr) ) then
  deallocate ( cvolr, stat = istatus )
  deallocate ( celev, stat = istatus )
  deallocate ( res_mpp_index, stat = istatus )
end if

if ( nsumr > 0 ) then
  nsumr_use = nsumr
else
  nsumr_use = 1
end if

allocate ( cvolr(nsumr_use), stat = istatus )

if ( istatus /= 0 ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
  write (lulog,'(a)') ' problems allocating cvolr'
  write (lulog,'(a,i10)') ' istatus=', istatus
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

allocate ( celev(nsumr_use), stat = istatus )

if ( istatus /= 0 ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
  write (lulog,'(a)') ' problems allocating celev'
  write (lulog,'(a,i10)') ' istatus=', istatus
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

allocate ( res_mpp_index(nsumr_use), stat = istatus )

if ( istatus /= 0 ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
  write (lulog,'(a)') ' problems allocating celev'
  write (lulog,'(a,i10)') ' istatus=', istatus
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

if ( nsumr > 0 ) then
  nsumr_use = nsumr
  nsumrr = 0
  do nr = 1, nrmax
    if ( rinfo%lake_mpi_index(nr) > 0 ) then
      nsumrr = nsumrr + 1
      celev(nsumrr) = rinfo%celev(nr)
      cvolr(nsumrr) = rinfo%cvol(nr)
      res_mpp_index(nsumrr) = nr
    end if
  end do
else
  nsumr_use = 1
  celev(1) = -9999.0
  cvolr(1) = -9999.0
  res_mpp_index(1) = -9999
end if

if ( my_id /= io_id ) then

  dest = io_id
  tag = 1
  nss = 1

  call MPI_ISEND ( nsumr_use, nss, MPI_INTEGER, dest, tag, &
    HYDRO_COMM_WORLD, nreq_hold(1), ierr )

  if ( ierr /= MPI_SUCCESS ) then
    write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
    write (lulog,'(a)') ' problem on MPI_ISEND for nsumr_use'
    write (lulog,'(a,i5)') ' my_id=', my_id
    stop
  end if

  tag = 2
  nss = nsumr_use
         
  call MPI_ISEND ( res_mpp_index, nss, MPI_INTEGER, dest, tag, &
    HYDRO_COMM_WORLD, nreq_hold(2), ierr )

  if ( ierr /= MPI_SUCCESS ) then
    write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
    write (lulog,'(a)') ' problem on MPI_ISEND for res_mpp_index'
    write (lulog,'(a,i5)') ' my_id=', my_id
    stop
  end if

  tag = 3

  call MPI_ISEND ( cvolr, nss, MPI_REAL, dest, tag, &
    HYDRO_COMM_WORLD, nreq_hold(3), ierr )

  if ( ierr /= MPI_SUCCESS ) then
    write (lulog,'(/a)') ' Subroutine drive_CHANNEL'
    write (lulog,'(a)') ' problem on MPI_ISEND for cvolr'
    write (lulog,'(a,i5)') ' my_id=', my_id
    stop
  end if

  tag = 4

  call MPI_ISEND ( celev, nss, MPI_REAL, dest, tag, &
    HYDRO_COMM_WORLD, nreq_hold(4), ierr )

  if ( ierr /= MPI_SUCCESS ) then
    write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
    write (lulog,'(a)') ' problem on MPI_ISEND for celev'
    write (lulog,'(a,i5)') ' my_id=', my_id
    stop
  end if

  if ( ldebug ) then
    write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
    write (lulog,'(a)') ' AFTER MPI_ISEND calls'
    write (lulog,'(a,i5)') ' my_id=', my_id
    write (lulog,'(a,i10)') ' nsumr=', nsumr
    write (lulog,'(a,i10)') ' nsumr_use=', nsumr_use
    write (lulog,'(a,i20)') ' nreq_hold(1)=', nreq_hold(1)
    write (lulog,'(a,i20)') ' nreq_hold(2)=', nreq_hold(2)
    write (lulog,'(a,i20)') ' nreq_hold(3)=', nreq_hold(3)
    write (lulog,'(a,i20)') ' nreq_hold(4)=', nreq_hold(4)
    call flush ( lulog )
  end if

end if ! if ( my_id /= io_id ) then

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
  write (lulog,'(a)') ' BEFORE MPI_RECV calls'
  call flush ( lulog )
end if

do np = 1, numprocs

  id = np - 1

  if ( ldebug ) then
    write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
    write (lulog,'(a)') ' TOP OF MPI_RECV loop'
    write (lulog,'(a,i10)') ' np=', np
    write (lulog,'(a,i10)') ' id=', id
    write (lulog,'(a,i10)') ' my_id=', my_id
    write (lulog,'(a,i10)') ' io_id=', io_id
    write (lulog,'(a,i20)') ' nreq_hold(1)=', nreq_hold(1)
    write (lulog,'(a,i20)') ' nreq_hold(2)=', nreq_hold(2)
    write (lulog,'(a,i20)') ' nreq_hold(3)=', nreq_hold(3)
    write (lulog,'(a,i20)') ' nreq_hold(4)=', nreq_hold(4)
    call flush ( lulog )
  end if

  if ( id == io_id ) then
    cycle
  end if

  if ( my_id == io_id ) then

    nsump = -9999

    tag = 1
    nss = 1
    src = id

    call MPI_RECV ( nsump, nss, MPI_INTEGER, src, tag, &
      HYDRO_COMM_WORLD, status, ierr )

    if ( ierr /= MPI_SUCCESS ) then
      write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
      write (lulog,'(a)') ' problem on MPI_RECV for nsump'
      write (lulog,'(a,i10)') ' tag=', tag
      write (lulog,'(a,i10)') ' src=', src
      stop
    end if

    if ( allocated(recv_cvolr) ) then
      deallocate ( recv_cvolr, stat = istatus )
      deallocate ( recv_celev, stat = istatus )
      deallocate ( recv_res_mpp_index, stat = istatus )
    end if

    allocate ( recv_cvolr(nsump), stat = istatus )

    if ( istatus /= 0 ) then
      write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
      write (lulog,'(a)') ' problems allocating recv_cvolr'
      write (lulog,'(a,i10)') ' istatus=', istatus
      write (lulog,'(a,i10)') ' np=', np
      call flush ( lulog )
      call exit ( 9 )
      stop
    end if

    allocate ( recv_celev(nsump), stat = istatus )

    if ( istatus /= 0 ) then
      write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
      write (lulog,'(a)') ' problems allocating recv_celev'
      write (lulog,'(a,i10)') ' istatus=', istatus
      write (lulog,'(a,i10)') ' np=', np
      call flush ( lulog )
      call exit ( 9 )
      stop
    end if

    allocate ( recv_res_mpp_index(nsump), stat = istatus )

    if ( istatus /= 0 ) then
      write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
      write (lulog,'(a)') ' problems allocating recv_celev'
      write (lulog,'(a,i10)') ' istatus=', istatus
      write (lulog,'(a,i10)') ' np=', np
      call flush ( lulog )
      call exit ( 9 )
      stop
    end if

    tag = 2
    nss = nsump

    call MPI_RECV ( recv_res_mpp_index, nss, MPI_INTEGER, src, tag, &
      HYDRO_COMM_WORLD, status, ierr )

    if ( ierr /= MPI_SUCCESS ) then
      write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
      write (lulog,'(a)') ' problem on MPI_RECV for recv_res_mpp_index'
      write (lulog,'(a,i10)') ' tag=', tag
      write (lulog,'(a,i10)') ' src=', src
      stop
    end if

    tag = 3

    call MPI_RECV ( recv_cvolr, nss, MPI_REAL, src, tag, &
      HYDRO_COMM_WORLD, status, ierr )

    if ( ierr /= MPI_SUCCESS ) then
      write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
      write (lulog,'(a)') ' problem on MPI_RECV for recv_cvolr'
      write (lulog,'(a,i10)') ' tag=', tag
      write (lulog,'(a,i10)') ' src=', src
      stop
    end if

    tag = 4

    call MPI_RECV ( recv_celev, nss, MPI_REAL, src, tag, &
      HYDRO_COMM_WORLD, status, ierr )

    if ( ierr /= MPI_SUCCESS ) then
      write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
      write (lulog,'(a)') ' problem on MPI_RECV for recv_celev'
      write (lulog,'(a,i10)') ' tag=', tag
      write (lulog,'(a,i10)') ' src=', src
      stop
    end if

    if ( ldebug ) then
      write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
      write (lulog,'(a)') ' BOTTOM OF MPI_RECV loop'
      write (lulog,'(a)') ' BEFORE MPI_WAIT calls'
      write (lulog,'(a,i10)') ' id=', id
      write (lulog,'(a,i10)') ' my_id=', my_id
      write (lulog,'(a,i10)') ' io_id=', io_id
      write (lulog,'(a,i10)') ' nsump=', nsump
      write (lulog,'(a,i20)') ' nreq_hold(1)=', nreq_hold(1)
      write (lulog,'(a,i20)') ' nreq_hold(2)=', nreq_hold(2)
      write (lulog,'(a,i20)') ' nreq_hold(3)=', nreq_hold(3)
      write (lulog,'(a,i20)') ' nreq_hold(4)=', nreq_hold(4)
      call flush ( lulog )
    end if

  end if

  if ( my_id == id ) then
    call MPI_WAITALL ( 4, nreq_hold, req_status, ierr )
  end if

  if ( my_id == io_id ) then
    do nr = 1, nsump
      nrloc = recv_res_mpp_index(nr)
      if ( nrloc < 0 ) then
        cycle
      end if
      rinfo%cvol(nrloc) = recv_cvolr(nr)
      rinfo%celev(nrloc) = recv_celev(nr)
    end do
  end if

  if ( ldebug ) then
    write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
    write (lulog,'(a)') ' BOTTOM OF MPI_RECV loop'
    write (lulog,'(a)') ' AFTER MPI_WAIT calls'
    write (lulog,'(a,i10)') ' id=', id
    write (lulog,'(a,i10)') ' my_id=', my_id
    write (lulog,'(a,i10)') ' io_id=', io_id
    call flush ( lulog )
  end if

end do

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
  write (lulog,'(a)') ' AFTER RECV calls'
  call flush ( lulog )
end if

if ( allocated(cvolr) ) then
  deallocate ( cvolr, stat = istatus )
  deallocate ( celev, stat = istatus )
  deallocate ( res_mpp_index, stat = istatus )
end if

if ( allocated(recv_cvolr) ) then
  deallocate ( recv_cvolr, stat = istatus )
  deallocate ( recv_celev, stat = istatus )
  deallocate ( recv_res_mpp_index, stat = istatus )
end if

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
  write (lulog,'(a)') ' BEFORE MPI_BCAST call'
  call flush ( lulog )
end if

nss = 1
call MPI_BCAST ( rinfo, nss, mpi_rule_curve_data, io_id, HYDRO_COMM_WORLD, ierr )

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
  write (lulog,'(a)') ' AFTER MPI_BCAST call'
  call flush ( lulog )
end if

if ( ierr /= MPI_SUCCESS ) then
  write (lulog,'(/a)') ' subroutine do_mpi_reservoir'
  write (lulog,'(a)') ' problem on MPI_BCAST for rinfo ???'
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

end subroutine
!
!***********************************************************************
!
subroutine findzlev ( zcol, nlev, ztemp, nbot, ntop, kbot, ktop, ngood, &
  nrev, nstop, lulog )

implicit none

!  Procedure dummy argument declarations

real, intent(in), dimension(nlev) :: zcol
integer, intent(in) :: nlev
real, intent(in) :: ztemp
integer, intent(inout) :: nbot
integer, intent(inout) :: ntop
integer, intent(in) :: kbot
integer, intent(in) :: ktop
integer, intent(inout) :: ngood
integer, intent(in) :: nrev
integer, intent(in) :: nstop
integer, intent(in) :: lulog

!  Local declarations

integer :: k
integer :: kl
integer :: km
integer :: ku
integer :: lupass1
real :: zbot
real :: ztop

if ( kbot == ktop ) then
  ngood = 0
  nbot = kbot
  ntop = kbot
  return
end if

kl = kbot
ku = ktop

do

  zbot = zcol(kl)
  ztop = zcol(ku)

  if (ku - kl == 1) then
    ngood = 0
    if ( nrev == + 1 ) then
      if ( ztemp >= zbot .and. ztemp <= ztop ) ngood = 1
    else if ( nrev == - 1 ) then
      if ( ztemp <= zbot .and. ztemp >= ztop ) ngood = 1
    end if
    exit
  end if

  km = (ku + kl) / 2
  zbot = zcol(km)

  if ( nrev == + 1 ) then
    if ( ztemp >= zbot ) then
      kl = km
    else
      ku = km
    end if
  else if ( nrev == - 1 ) then
    if ( ztemp <= zbot ) then
      kl = km
    else
      ku = km
    end if
  end if

end do

if ( ngood == 0 .and. nstop == 1 ) then
  write (lulog,'(/a)') ' subroutine findzlev:  could not find levels'
  write (lulog,'(a,f15.5)') ' ztemp=',ztemp
  write (lulog,'(a,2i5)') ' kl,ku=',kl,ku
  write (lulog,'(a,2f15.5)') ' zbot,ztop=',ztop,zbot
  write (lulog,'(a,2i5)') ' kbot,ktop=',kbot,ktop
  do k = 1, ktop
    write (lulog,'(a,i5,f15.3)') ' k,zcol(k)=',k,zcol(k)
  end do
  stop
end if

nbot = kl
ntop = ku

end subroutine
!
!***********************************************************************
!
subroutine get_elev_from_area_capacity ( nr, elev, avol )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: nr
real, intent(inout) :: elev
real, intent(in) :: avol

! Local Declarations

integer :: npmax
integer :: np
integer :: nb
integer :: ne
integer :: kbot
integer :: ktop
integer :: nstop
integer :: nrev
integer :: ngood
real :: top
real :: bot
real :: wgt_e
real :: wgt_b
logical :: ldebug

! Local Arrays

integer, parameter :: nmax = 1000
real, dimension(nmax) :: ehold
real, dimension(nmax) :: vhold

npmax = rinfo%area_capacity_npts(nr)

if ( npmax > nmax ) then
  write (lulog,'(/a)') ' subroutine get_elev_from_area_capacity'
  write (lulog,'(a)') ' npmax > nmax ???'
  write (lulog,'(a,i10)') ' npmax=', npmax
  write (lulog,'(a,i10)') ' nmax=', nmax
  write (lulog,'(a,i10)') ' nr=', nr
  stop
end if

do np = 1, npmax
  vhold(np) = rinfo%area_capacity_vol(nr,np)
  ehold(np) = rinfo%area_capacity_elev(nr,np)
end do

kbot = 1
ktop = npmax
nstop = 1
nrev = +1

! avol needs to be in units of millions of cubic meters to be
! consistent with units of rinfo%area_capacity_vol

call findzlev ( vhold, nmax, avol, nb, ne, kbot, ktop, ngood, &
  nrev, nstop, lulog )

top = avol - vhold(nb)
bot = vhold(ne) - vhold(nb)
wgt_e = top / bot

if ( wgt_e <= 0.0 ) then
  wgt_e = 0.0
end if

if ( wgt_e >= 1.0 ) then
  wgt_e = 1.0
end if

wgt_b = 1.0 - wgt_e

elev = ( wgt_b * ehold(nb) ) + ( wgt_e * ehold(ne) )

ldebug = .true.
ldebug = .false.

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine get_elev_from_area_capacity'
  write (lulog,'(a,2i10)') ' nb, ne=', nb, ne
  write (lulog,'(a,t15,f15.5)') ' ehold(nb)=', ehold(nb)
  write (lulog,'(a,t15,f15.5)') ' elev=', elev
  write (lulog,'(a,t15,f15.5)') ' ehold(ne)=', ehold(ne)
  write (lulog,'(a,t15,f15.3)') ' vhold(nb)=', vhold(nb)
  write (lulog,'(a,t15,f15.3)') ' avol=', avol
  write (lulog,'(a,t15,f15.3)') ' vhold(ne)=', vhold(ne)
end if

end subroutine
!
!***********************************************************************
!
subroutine get_vol_elev_rule_curve ( nyr_in, nmo_in, ndy_in, nhr_in, nmin_in, nsec_in, &
  nr, relev, rvol, vsum, dname, ldebug )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: nyr_in
integer, intent(in) :: nmo_in
integer, intent(in) :: ndy_in
integer, intent(in) :: nhr_in
integer, intent(in) :: nmin_in
integer, intent(in) :: nsec_in
integer, intent(in) :: nr
real, intent(inout) :: relev
real, intent(inout) :: rvol
real, intent(in) :: vsum
character ( len = * ), intent(in) :: dname
logical, intent(in) :: ldebug

!  Local declarations

integer :: ndsum
integer :: nsum
integer :: nd
integer :: ny
integer :: nyr
integer :: nmo
integer :: ndy
integer :: nhr
integer :: nmin
integer :: nsec
real ( kind = 8 ) :: jday

integer :: jmin
integer :: nbot
integer :: ntop
integer :: kbot
integer :: ktop
integer :: ngood
integer :: nrev
integer :: nstop

integer :: nyr3
integer :: nmo3
integer :: ndy3
integer :: nhr3
integer :: nmin3
integer :: nsec3

real :: top
real :: bot
real :: wgt_l
real :: wgt_e

real :: relev_min
real :: relev_max
real :: rvol_min
real :: rvol_max
real :: dtop
real :: dbot
real :: wgt_max
real :: wgt_min
real :: vcorr

integer :: nc

! Local Arrays

integer, parameter :: nttmax = 1000
real ( kind = 8 ), dimension(nttmax) :: jdayr
real, dimension(nttmax) :: ehold

ndsum = rinfo%ndates(nr)

if ( ndsum > nttmax ) then
  write (lulog,'(/a)') ' subroutine get_vol_elev_rule_curve'
  write (lulog,'(a)') ' ndsum > nttmax ???'
  write (lulog,'(a,i10)') ' ndsum=', ndsum
  write (lulog,'(a,i10)') ' nttmax=', nttmax
  write (lulog,'(a,i10)') ' nr=', nr
  stop
end if

if ( rinfo%simple_rule_curve(nr) == 1 ) then

  relev_min = rinfo%elev(nr,1)
  relev_max = rinfo%elev(nr,2)
  call get_vol_from_area_capacity ( nr, relev_min, rvol_min, 'GET_VOL', vcorr )
  call get_vol_from_area_capacity ( nr, relev_max, rvol_max, 'GET_VOL', vcorr )

  dtop = rmiss
  dbot = rmiss
  wgt_min = rmiss
  wgt_max = rmiss

  if ( vsum <= rvol_min ) then
    rvol = rvol_min
    relev = relev_min
  else if ( vsum >= rvol_max ) then
    rvol = rvol_max
    relev = relev_max
  else
    dtop = vsum - rvol_min
    dbot = rvol_max - rvol_min
    wgt_max = dtop / dbot
    if ( wgt_max <= 0.0 ) then
      wgt_max = 0.0
    end if
    if ( wgt_max >= 1.0 ) then
      wgt_max = 1.0
    end if
    wgt_min = 1.0 - wgt_max
    rvol = ( wgt_min * rvol_min ) + ( wgt_max * rvol_max )
    relev = ( wgt_min * relev_min ) + ( wgt_max * relev_max )
  end if

  if ( ldebug ) then
    write (lulog,'(/a)') ' subroutine get_vol_elev_rule_curve'
    write (lulog,'(a)') ' SIMPLE RULE CURVE SECTION'
    write (lulog,'(a,i10)') ' nr=', nr
    write (lulog,'(a,a)') ' dname = ', trim ( dname )
    write (lulog,'(a,f15.5)') ' rinfo%dlat(nr)=', rinfo%dlat(nr)
    write (lulog,'(a,f15.5)') ' rinfo%dlon(nr)=', rinfo%dlon(nr)
    write (lulog,'(a,i10)') ' rinfo%res_lake_index(nr)=', rinfo%res_lake_index(nr)
    write (lulog,'(a,i10)') ' nyr_in=', nyr_in
    write (lulog,'(a,i10)') ' nmo_in=', nmo_in
    write (lulog,'(a,i10)') ' ndy_in=', ndy_in
    write (lulog,'(a,5x,e12.5)') ' rvol_min=', rvol_min
    write (lulog,'(a,5x,e12.5)') ' vsum=', vsum
    write (lulog,'(a,5x,e12.5)') ' rvol_max=', rvol_max
    write (lulog,'(a,f15.5)') ' relev_min=', relev_min
    write (lulog,'(a,f15.5)') ' relev_max=', relev_max
    write (lulog,'(a,f15.4)') ' wgt_min=', wgt_min
    write (lulog,'(a,f15.4)') ' wgt_max=', wgt_max
    write (lulog,'(a,5x,e12.5)') ' rvol=', rvol
    write (lulog,'(a,f15.5)') ' relev=', relev
  end if

  return

end if

! If only one date then elevation and storage are constant - no
! time interpolation needed

if ( ndsum == 1 ) then
  relev = rinfo%elev(nr,1)
  call get_vol_from_area_capacity ( nr, relev, rvol, 'GET_VOL', vcorr )

  if ( ldebug ) then
    write (lulog,'(/a)') ' subroutine get_vol_elev_rule_curve'
    write (lulog,'(a)') ' ONE VALUE RULE CURVE SECTION'
    write (lulog,'(a,i10)') ' nr=', nr
    write (lulog,'(a,a)') ' dname = ', trim ( dname )
    write (lulog,'(a,f15.5)') ' rinfo%dlat(nr)=', rinfo%dlat(nr)
    write (lulog,'(a,f15.5)') ' rinfo%dlon(nr)=', rinfo%dlon(nr)
    write (lulog,'(a,i10)') ' rinfo%res_lake_index(nr)=', rinfo%res_lake_index(nr)
    write (lulog,'(a,i10)') ' nyr_in=', nyr_in
    write (lulog,'(a,i10)') ' nmo_in=', nmo_in
    write (lulog,'(a,i10)') ' ndy_in=', ndy_in
    write (lulog,'(a,5x,e12.5)') ' rvol=', rvol
    write (lulog,'(a,f15.5)') ' relev=', relev
  end if

  return
end if

nhr = 0
nmin = 0
nsec = 0

nyr = nyr_in - 2
nsum = 0

do ny = 1, 3

  nyr = nyr + 1

  do nd = 1, ndsum
    nmo = rinfo%nmo(nr,nd)
    ndy = rinfo%ndy(nr,nd)
    nsum = nsum + 1
    if ( nsum > nttmax ) then
      write (lulog,'(a)') ' nsum > nttmax ???'
      write (lulog,'(a,i10)') ' nsum=', nsum
      write (lulog,'(a,i10)') ' nttmax=', nttmax
      write (lulog,'(a,i10)') ' nr=', nr
      stop
    end if
    call calc_date ( nyr, nmo, ndy, &
      nhr, nmin, nsec, &
      jdayr(nsum), lulog )
    ehold(nsum) = rinfo%elev(nr,nd)
  end do

end do

call calc_date ( nyr_in, nmo_in, ndy_in, &
  nhr_in, nmin_in, nsec_in, &
  jday, lulog )

kbot = 1
ktop = nsum
nstop = 1
nrev = +1

call findzlev8 ( jdayr, nttmax, jday, nbot, ntop, kbot, ktop, ngood, &
  nrev, nstop, lulog )

top = real( jday - jdayr(nbot) )
bot = real( jdayr(ntop) - jdayr(nbot) )
wgt_l = top / bot

if ( wgt_l <= 0.0 ) then
  wgt_l = 0.0
end if

if ( wgt_l >= 1.0 ) then
  wgt_l = 1.0
end if

wgt_e = 1.0 - wgt_l

relev = ( wgt_e * ehold(nbot) ) + ( wgt_l * ehold(ntop) )

call get_vol_from_area_capacity ( nr, relev, rvol, 'GET_VOL', vcorr )

if ( ldebug ) then

  write (lulog,'(/a)') ' subroutine get_vol_elev_rule_curve'
  write (lulog,'(a,i10)') ' nr=', nr
  write (lulog,'(a,a)') ' dname = ', trim ( dname )
  write (lulog,'(a,f15.5)') ' rinfo%dlat(nr)=', rinfo%dlat(nr)
  write (lulog,'(a,f15.5)') ' rinfo%dlon(nr)=', rinfo%dlon(nr)
  write (lulog,'(a,i10)') ' rinfo%res_lake_index(nr)=', rinfo%res_lake_index(nr)
  write (lulog,'(a,i10)') ' nyr_in=', nyr_in
  write (lulog,'(a,i10)') ' nmo_in=', nmo_in
  write (lulog,'(a,i10)') ' ndy_in=', ndy_in
  write (lulog,'(a,i10)') ' nhr=', nhr
  write (lulog,'(a,i10)') ' nmin=', nmin
  write (lulog,'(a,2i10)') ' nbot, ntop=', nbot, ntop

  write (lulog,'(/a,f10.2)') ' early time: jdayr(nbot)=', jdayr(nbot)

  call inv_calc_date ( nyr3, nmo3, ndy3, nhr3, nmin3, nsec3, &
    jdayr(nbot), lulog )

  write (lulog,'(a,i10)') ' nyr=', nyr3
  write (lulog,'(a,i10)') ' nmo=', nmo3
  write (lulog,'(a,i10)') ' ndy=', ndy3
  write (lulog,'(a,i10)') ' nhr=', nhr3
  write (lulog,'(a,i10)') ' nmin=', nmin3

  write (lulog,'(/a,f10.2)') ' late time: jdayr(ntop)=', jdayr(ntop)

  call inv_calc_date ( nyr3, nmo3, ndy3, nhr3, nmin3, nsec3, &
    jdayr(ntop), lulog )

  write (lulog,'(a,i10)') ' nyr=', nyr3
  write (lulog,'(a,i10)') ' nmo=', nmo3
  write (lulog,'(a,i10)') ' ndy=', ndy3
  write (lulog,'(a,i10)') ' nhr=', nhr3
  write (lulog,'(a,i10)') ' nmin=', nmin3

  write (lulog,'(/a)') ' time weights ...'
  write (lulog,'(a,f10.5)') ' wgt_e=', wgt_e
  write (lulog,'(a,f10.5)') ' wgt_l=', wgt_l

  write (lulog,'(a,t15,f15.5)') ' ehold(nbot)=', ehold(nbot)
  write (lulog,'(a,t15,f15.5)') ' relev=', relev
  write (lulog,'(a,t15,f15.5)') ' ehold(ntop)=', ehold(ntop)

  write (lulog,'(a,t15,f15.3)') ' rvol=', rvol

end if

end subroutine
!
!***********************************************************************
!
subroutine get_vol_from_area_capacity ( nr, elev, avol, mode, vcorr )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: nr
real, intent(inout) :: elev
real, intent(inout) :: avol
character ( len = * ), intent(in) :: mode
real, intent(inout) :: vcorr

! Local Declarations

integer :: npmax
integer :: np
integer :: nb
integer :: ne
integer :: kbot
integer :: ktop
integer :: nstop
integer :: nrev
integer :: ngood
real :: top
real :: bot
real :: wgt_e
real :: wgt_b
logical :: ldebug

! Local Arrays

integer, parameter :: nmax = 1000
real, dimension(nmax) :: ehold
real, dimension(nmax) :: vhold

npmax = rinfo%area_capacity_npts(nr)

if ( npmax > nmax ) then
  write (lulog,'(/a)') ' subroutine get_vol_from_area_capacity'
  write (lulog,'(a)') ' npmax > nmax ???'
  write (lulog,'(a,i10)') ' npmax=', npmax
  write (lulog,'(a,i10)') ' nmax=', nmax
  write (lulog,'(a,i10)') ' nr=', nr
  stop
end if

do np = 1, npmax
  vhold(np) = rinfo%area_capacity_vol(nr,np)
  ehold(np) = rinfo%area_capacity_elev(nr,np)
end do

kbot = 1
ktop = npmax
nstop = 1
nrev = +1

vcorr = 0.0

if ( trim(mode) == 'GET_VOL' ) then

  call findzlev ( ehold, nmax, elev, nb, ne, kbot, ktop, ngood, &
    nrev, nstop, lulog )

  top = elev - ehold(nb)
  bot = ehold(ne) - ehold(nb)
  wgt_e = top / bot

  if ( wgt_e <= 0.0 ) then
    wgt_e = 0.0
  end if

  if ( wgt_e >= 1.0 ) then
    wgt_e = 1.0
  end if

  wgt_b = 1.0 - wgt_e

  avol = ( wgt_b * vhold(nb) ) + ( wgt_e * vhold(ne) )

else if ( trim(mode) == 'GET_ELEV' ) then

  if ( avol < vhold(1) ) then
    vcorr = vhold(1) - avol
    avol = vhold(1)
  end if

  if ( avol > vhold(npmax) ) then
    vcorr = vhold(npmax) - avol
    avol = vhold(npmax)
  end if

  call findzlev ( vhold, nmax, avol, nb, ne, kbot, ktop, ngood, &
    nrev, nstop, lulog )

  top = avol - vhold(nb)
  bot = vhold(ne) - vhold(nb)
  wgt_e = top / bot

  if ( wgt_e <= 0.0 ) then
    wgt_e = 0.0
  end if

  if ( wgt_e >= 1.0 ) then
    wgt_e = 1.0
  end if

  wgt_b = 1.0 - wgt_e

  elev = ( wgt_b * ehold(nb) ) + ( wgt_e * ehold(ne) )

else

  write (lulog,'(/a)') ' subroutine get_vol_from_area_capacity'
  write (lulog,'(a)') ' unexpected mode ???'
  write (lulog,'(a,a)') ' mode = ', trim(mode)
  call flush ( lulog )
  call exit ( 9 )
  stop

end if


!       ldebug = .true.
ldebug = .false.

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine get_vol_from_area_capacity'
  write (lulog,'(a,a)') ' mode = ', trim(mode)
  write (lulog,'(a,2i10)') ' nb, ne=', nb, ne
  write (lulog,'(a,t15,f15.5)') ' ehold(nb)=', ehold(nb)
  write (lulog,'(a,t15,f15.5)') ' elev=', elev
  write (lulog,'(a,t15,f15.5)') ' ehold(ne)=', ehold(ne)
  write (lulog,'(a,t15,f15.3)') ' vhold(nb)=', vhold(nb)
  write (lulog,'(a,t15,f15.3)') ' avol=', avol
  write (lulog,'(a,t15,f15.3)') ' vhold(ne)=', vhold(ne)
end if

end subroutine
!
!***********************************************************************
!
subroutine check_lake_index ( l_idx, nrloc )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: l_idx
integer, intent(inout) :: nrloc

! Local Declarations

integer :: nr

nrloc = imiss

do nr = 1, nrmax
  if ( rinfo%res_lake_index(nr) == l_idx ) then
    nrloc = nr
    exit
  end if
end do

end subroutine
!
!***********************************************************************
!
subroutine update_reservoir ( qout, nt, dtr, olddate, nrloc, &
  quc, qup, qlateral, debug_dname, ldebug )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

real, intent(inout) :: qout
integer, intent(in) :: nt
real, intent(in) :: dtr
character ( len = * ), intent(in) :: olddate
integer, intent(in) :: nrloc
real, intent(in) :: quc
real, intent(in) :: qup
real, intent(in) :: qlateral
character ( len = * ), intent(in) :: debug_dname
logical, intent(inout) :: ldebug

! Local Declarations

integer :: nyr
integer :: nmo
integer :: ndy
integer :: nhr
integer :: nmin
integer :: nsec
integer :: nseck
real :: relev_old
real :: rvol_old
real :: relev_new
real :: rvol_new
real :: vadd
real :: cvol
real :: cvolf
real :: celev
real :: celevf
real :: dvol
real :: dvolf
real :: dvdt
real, parameter :: dtn = 86400.0 ! 24-h
real, parameter :: msec = 30.0 * 24.0 * 3600.0 ! seconds in month
integer :: nc
integer :: nr
integer, save :: ndone = 0
integer, save :: nrloc_debug = 0
character ( len = 256 ) :: dname
real :: dlim
real :: vcorr
 
! Local Arrays

if ( ndone == 0 ) then
  do nr = 1, nrmax
    dname = ''
    do nc = 1, ncmax
      if ( rinfo%dname_int(nr,nc) <= 0 ) then
        exit
      end if
      dname(nc:nc) = achar(rinfo%dname_int(nr,nc))
    end do
    if ( trim(dname) == trim(debug_dname) ) then
      nrloc_debug = nr
      exit
    end if
  end do
  ndone = 1
end if

ldebug = .false.

if ( nrloc == nrloc_debug ) then
  ldebug = .true.
end if

read (olddate,'(i4,1x,i2,1x,i2,1x,i2,1x,i2,1x,i2)') &
  nyr, nmo, ndy, nhr, nmin, nsec

nseck = nsec
nsec = nsec + ( nt * nint(dtr) )
relev_old = rinfo%celev(nrloc)
rvol_old = rinfo%cvol(nrloc)

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine update_reservoir'
  write (lulog,'(a)') ' BEFORE call get_vol_elev_rule_curve'
  write (lulog,'(a,a)') ' debug_dname = ', trim ( debug_dname )
  write (lulog,'(a,a)') ' dname = ', trim ( dname )
  write (lulog,'(a,a)') ' olddate = ', trim(olddate)
  write (lulog,'(a,i10)') ' nt=', nt
  write (lulog,'(a,f10.3)') ' dtr=', dtr
  write (lulog,'(a,i10)') ' nseck=', nseck
  write (lulog,'(a,i10)') ' nsec=', nsec
  write (lulog,'(a,5x,e12.5)') ' relev_old=', relev_old
  write (lulog,'(a,5x,e12.5)') ' rvol_old=', rvol_old
end if

call get_vol_elev_rule_curve ( nyr, nmo, ndy, nhr, nmin, nsec, &
  nrloc, relev_new, rvol_new, rvol_old, debug_dname, ldebug )

! vadd will be in units of millions of cubic meters
! all volumes from rule-curves are also in the same units

vadd = 1.0e-06 * dtr * ( 0.50 * ( quc + qup ) + qlateral )
cvol = rvol_old + vadd
dvol = cvol - rvol_new
vcorr = 0.0

if ( dvol > 0.0 ) then

  dvdt = dvol / dtn
  cvolf = rvol_old + ( dvdt * dtr )
  call get_vol_from_area_capacity ( nrloc, celevf, cvolf, 'GET_ELEV', vcorr )

  dvolf = cvolf - rvol_old - vcorr
  dlim = 0.0

  if ( dvolf > 0.0 ) then
    qout = ( 1.0e+06 * dvolf ) / dtr
  else if ( dvolf <= 0.0 ) then
    dlim = ( 0.05 * dtr ) / msec
    qout = ( dlim * 1.0e+06 * cvol ) / dtr
    cvolf = ( 1.0 - dlim ) * cvol
    call get_vol_from_area_capacity ( nrloc, celevf, cvolf, 'GET_ELEV', vcorr )
  end if

else if ( dvol <= 0.0 ) then

  dlim = ( 0.05 * dtr ) / msec
  qout = ( dlim * 1.0e+06 * cvol ) / dtr
  cvolf = ( 1.0 - dlim ) * cvol
  call get_vol_from_area_capacity ( nrloc, celevf, cvolf, 'GET_ELEV', vcorr )

end if

rinfo%celev(nrloc) = celevf
rinfo%cvol(nrloc) = cvolf

if ( ldebug ) then
  write (lulog,'(/a)') ' subroutine update_reservoir'
  write (lulog,'(a)') ' AFTER call get_vol_elev_rule_curve'
  write (lulog,'(a,a)') ' debug_dname = ', trim ( debug_dname )
  write (lulog,'(a,a)') ' olddate = ', trim(olddate)
  write (lulog,'(a,5x,e12.5)') ' relev_old=', relev_old
  write (lulog,'(a,5x,e12.5)') ' rvol_old=', rvol_old
  write (lulog,'(a,5x,e12.5)') ' relev_new=', relev_new
  write (lulog,'(a,5x,e12.5)') ' rvol_new=', rvol_new
  write (lulog,'(a,5x,e12.5)') ' quc=', quc
  write (lulog,'(a,5x,e12.5)') ' qup=', qup
  write (lulog,'(a,5x,e12.5)') ' qlateral=', qlateral
  write (lulog,'(a,5x,e12.5)') ' vadd=', vadd
  write (lulog,'(a,5x,e12.5)') ' initial cvol=', cvol
  write (lulog,'(a,5x,e12.5)') ' initial dvol=', dvol
  write (lulog,'(a,5x,e12.5)') ' dvdt=', dvdt
  write (lulog,'(a,5x,e12.5)') ' final cvolf=', cvolf
  write (lulog,'(a,5x,e12.5)') ' final celevf=', celevf
  write (lulog,'(a,5x,e12.5)') ' final dvolf=', dvolf
  write (lulog,'(a,5x,e12.5)') ' vcorr=', vcorr
  write (lulog,'(a,5x,e12.5)') ' qout=', qout
  write (lulog,'(a,5x,e12.5)') ' dlim=', dlim
  write (lulog,'(a,5x,e12.5)') ' dtn=', dtn
end if

end subroutine
!
!***********************************************************************
!
subroutine initialize_reservoir ( olddate, nrloc, debug_dname )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_rinfo

implicit none

!  Procedure dummy argument declarations

character ( len = * ), intent(in) :: olddate
integer, intent(in) :: nrloc
character ( len = * ), intent(in) :: debug_dname

! Local Declarations

real :: relev
real :: rvol
integer :: nr
integer :: nc
real :: vsump

integer :: nyr
integer :: nmo
integer :: ndy
integer :: nhr
integer :: nmin
integer :: nsec

logical :: ldebug
integer, save :: ndone = 0
integer, save :: nrloc_debug = 0
character ( len = 256 ) :: dname

if ( ndone == 0 ) then
  do nr = 1, nrmax
    dname = ''
    do nc = 1, ncmax
      if ( rinfo%dname_int(nr,nc) <= 0 ) then
        exit
      end if
      dname(nc:nc) = achar(rinfo%dname_int(nr,nc))
    end do
    if ( trim(dname) == trim(debug_dname) ) then
      nrloc_debug = nr
      exit
    end if
  end do
  ndone = 1
end if

ldebug = .false.

if ( nrloc == nrloc_debug ) then
  ldebug = .true.
end if

read (olddate,'(i4,1x,i2,1x,i2,1x,i2,1x,i2,1x,i2)') &
  nyr, nmo, ndy, nhr, nmin, nsec

! rvol is in units of millions of cubic meters

vsump = rmiss

do nr = nrloc, nrloc
  call get_vol_elev_rule_curve ( nyr, nmo, ndy, nhr, nmin, nsec, &
    nr, relev, rvol, vsump, debug_dname, ldebug )
  rinfo%celev(nr) = relev
  rinfo%cvol(nr) = rvol
end do

end subroutine
!
!***********************************************************************
!
subroutine findzlev8 ( zcol, nlev, ztemp, nbot, ntop, kbot, ktop, ngood, &
  nrev, nstop, lulog )
 
!  Global data module

!  Modules for needed subroutines ...
 
implicit none
 
!  Procedure dummy argument declarations
 
real ( kind = 8 ), intent(in), dimension(nlev) :: zcol
integer, intent(in) :: nlev
real ( kind = 8 ), intent(in) :: ztemp
integer, intent(inout) :: nbot
integer, intent(inout) :: ntop
integer, intent(in) :: kbot
integer, intent(in) :: ktop
integer, intent(inout) :: ngood
integer, intent(in) :: nrev
integer, intent(in) :: nstop
integer, intent(in) :: lulog
 
!  Local declarations
 
integer :: k
integer :: kl
integer :: km
integer :: ku
real ( kind = 8 ) :: zbot
real ( kind = 8 ) :: ztop
 
if ( kbot == ktop ) then
  ngood = 0
  nbot = kbot
  ntop = kbot
  return
end if
 
kl = kbot
ku = ktop
 
do
 
  zbot = zcol(kl)
  ztop = zcol(ku)
 
  if (ku - kl == 1) then
    ngood = 0
    if ( nrev == + 1 ) then
      if ( ztemp >= zbot .and. ztemp <= ztop ) ngood = 1
    else if ( nrev == - 1 ) then
      if ( ztemp <= zbot .and. ztemp >= ztop ) ngood = 1
    end if
    exit
  end if
 
  km = (ku + kl) / 2
  zbot = zcol(km)
 
  if ( nrev == + 1 ) then
    if ( ztemp >= zbot ) then
      kl = km
    else
      ku = km
    end if
  else if ( nrev == - 1 ) then
    if ( ztemp <= zbot ) then
      kl = km
    else
      ku = km
    end if
  end if
 
end do
 
if ( ngood == 0 .and. nstop == 1 ) then
  write (lulog,'(/a)') ' subroutine findzlev8:  could not find levels'
  write (lulog,'(a,f10.3)') ' ztemp=',ztemp
  write (lulog,'(a,2i5)') ' kl,ku=',kl,ku
  write (lulog,'(a,2f10.3)') ' zbot,ztop=',ztop,zbot
  write (lulog,'(a,2i5)') ' kbot,ktop=',kbot,ktop
  do k = 1, ktop
    write (lulog,'(a,i5,f15.3)') ' k,zcol(k)=',k,zcol(k)
  end do
  call flush ( lulog )
  call exit ( 9 )
  stop
end if
 
nbot = kl
ntop = ku
 
end subroutine
!
!***********************************************************************
!
subroutine calc_date ( nyr, nmo, ndy, &
  nhr, nmin, nsec, &
  jday, lulog )

!  Modules for needed subroutines ...

!  Global data module

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: nyr
integer, intent(in) :: nmo
integer, intent(in) :: ndy
integer, intent(in) :: nhr
integer, intent(in) :: nmin
integer, intent(in) :: nsec
real ( kind = 8 ), intent(out) :: jday
integer, intent(in) :: lulog

!  Local declarations

real ( kind = 8 ) :: dfrac
integer :: nmo_use
integer :: nyr_use
integer :: a
integer :: b

dfrac = ( dble(nhr) / 24.0d+00 ) + ( dble(nmin) / ( 24.00d+00 * 60.0d+00 ) ) + &
  ( dble(nsec) / ( 24.00d+00 * 3600.0d+00 ) )

if ( nmo > 2 ) then
  nmo_use = nmo
  nyr_use = nyr
else if ( nmo <= 2 ) then
  nmo_use = nmo + 12
  nyr_use = nyr - 1
end if

a = int ( dble(nyr_use) / 100.0d+00 )
b = 2 - a + int( dble(a) * 0.25d+00 )

jday = dble ( int ( 365.25d+000 * ( dble(nyr_use) + 4716.0d+00 ) ) ) + &
  dble ( int ( 30.6001d+00 * ( dble(nmo_use) + 1.0d+00) ) ) + &
  dble(ndy) + dfrac + dble(b) - 1524.5d+00

end subroutine
!
!***********************************************************************
!
subroutine inv_calc_date ( nyr, nmo, ndy, nhr, nmin, nsec, &
  jday, lulog )

!  Modules for needed subroutines ...

!  Global data module

implicit none

!  Procedure dummy argument declarations

integer, intent(out) :: nyr
integer, intent(out) :: nmo
integer, intent(out) :: ndy
integer, intent(out) :: nhr
integer, intent(out) :: nmin
integer, intent(out) :: nsec
real ( kind = 8 ), intent(in) :: jday
integer, intent(in) :: lulog

!  Local declarations

real ( kind = 8 ) :: jday_use
integer ( kind = 8 ) :: z
real ( kind = 8 ) :: f
integer ( kind = 8 ) :: alpha
integer ( kind = 8 ) :: a
integer ( kind = 8 ) :: b
integer ( kind = 8 ) :: c
integer ( kind = 8 ) :: d
integer ( kind = 8 ) :: e
real ( kind = 8 ) :: dfrac
integer :: ndmax
integer :: nleap
integer :: nltest
integer :: n100
integer :: n400
integer :: nbad

! Local Arrays

integer, parameter :: nmonth = 12
integer, dimension (nmonth), save :: mday

mday = (/ &
 31, 28, 31, 30, 31, 30, &
 31, 31, 30, 31, 30, 31 &
 /)

jday_use = jday + 0.50d+00
z = int ( jday_use )
f = jday_use - z

if ( z < 2299161 ) then
  a = z
else if ( z >= 2299161 ) then
  alpha = int ( ( z - 1867216.25d+00 ) / 36524.25d+00 )
  a = z + 1 + alpha - int ( dble(alpha) / 4.0d+00 )
end if

b = a + 1524
c = int ( ( dble(b) - 122.1d+00 ) / 365.25d+00 )
d = int ( 365.25d+00 * dble(c) )
e = int ( dble (b-d) / 30.6001d+00 )

dfrac = dble(b) - dble(d) - int( 30.6001d+00 * dble(e) ) + f

ndy = int ( dfrac )
dfrac = 24.0d+00 * ( dfrac - dble(ndy) )
if ( dfrac <= 0.0d+00 ) then
  dfrac = 0.0d+00
end if

nhr = int ( dfrac )
dfrac = 60.0d+00 * ( dfrac - dble (nhr) )
if ( dfrac <= 0.0d+00 ) then
  dfrac = 0.0d+00
end if

nmin = int ( dfrac )
dfrac = 60.0d+00 * ( dfrac - dble (nmin) )
if ( dfrac <= 0.0d+00 ) then
  dfrac = 0.0d+00
end if

nsec = nint ( dfrac )

if ( e < 14 ) then
  nmo = e - 1
else if ( e >= 14 ) then
  nmo = e - 13
end if

if ( nmo > 2 ) then
  nyr = c - 4716
else if ( nmo <= 2 ) then
  nyr = c - 4715
end if

if ( nsec >= 60 ) then
  nsec = nsec - 60
  nmin = nmin + 1
end if

if ( nmin >= 60 ) then
  nmin = nmin - 60
  nhr = nhr + 1
end if

if ( nhr >= 24 ) then
  nhr = nhr - 24
  ndy = ndy + 1
end if

ndmax = mday(nmo)

nleap = 0
nltest = mod( nyr,4 )

if ( nltest == 0 ) then
  nleap = 1
  n100 = mod( nyr,100 )
  if ( n100 == 0 ) then
    n400 = mod( nyr,400 )
    if ( n400 /= 0 ) nleap = 0
  end if
end if

if ( nleap == 1 .and. nmo == 2 ) then
  ndmax = ndmax + 1
end if

if ( ndy > ndmax ) then
  nmo = nmo + 1
  if ( nmo <= 12 ) then
    ndy = 1
  else
    nmo = 1
    ndy = 1
    nyr = nyr + 1
  end if
end if

nbad = 0
if ( nmo <= 0 .or. nmo > 12 ) nbad = nbad + 1
if ( nmo >= 1 .and. nmo <= 12 ) then
if ( ndy <= 0 .or. ndy > ndmax ) nbad = nbad + 1
end if
if ( nhr < 0 .or. nhr >= 24 ) nbad = nbad + 1
if ( nmin < 0 .or. nmin >= 60 ) nbad = nbad + 1
if ( nsec < 0 .or. nsec >= 60 ) nbad = nbad + 1

if ( nbad > 0 ) then
  write (lulog,'(/a)') ' BAD DATE: subroutine inv_calc_date'
  write (lulog,'(a,i10)') ' nyr=', nyr
  write (lulog,'(a,i10)') ' nmo=', nmo
  write (lulog,'(a,i10)') ' ndy=', ndy
  write (lulog,'(a,i10)') ' nhr=', nhr
  write (lulog,'(a,i10)') ' nmin=', nmin
  write (lulog,'(a,i10)') ' nsec=', nsec
  stop
end if

end subroutine
!
!***********************************************************************
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! CODE-1
!
!***********************************************************************
!
subroutine read_with_info_driver ( pid, nproc, fname_with_data, linkid, nlinks, &
  rmiss, imiss, cmiss, nyr_base, nmo_base, ndy_base, nhr_base )

!  Modules for needed subroutines ...

!  Global data module

USE module_global_winfo

implicit none
 
!  Procedure dummy argument declarations

integer, intent(in) :: pid
integer, intent(in) :: nproc
character ( len = * ), intent(in) :: fname_with_data
integer, intent(in), dimension(nlinks) :: linkid
integer, intent(in) :: nlinks
real, intent(in) :: rmiss
integer, intent(in) :: imiss
character ( len = * ), intent(in) :: cmiss
integer, intent(in) :: nyr_base
integer, intent(in) :: nmo_base
integer, intent(in) :: ndy_base
integer, intent(in) :: nhr_base

!  Local declarations

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
integer :: lutemp
character ( len = 1000 ) :: fnamep
integer :: nend
integer :: lnblnk
integer :: ios
character ( len = 1000 ) :: nrec
integer :: nstrt
integer :: nmax
integer :: nmo
integer :: ndy
integer :: nyr
integer :: nhr
integer :: nmin
integer :: jmin
integer :: jmin_old
integer :: jdiff
integer, parameter :: jmin_day = 24 * 60

integer :: linkid_rd
integer :: npass
integer :: ierr
real :: demand

integer :: nfind
integer :: nc
integer :: ntloc
integer :: linkid_loc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!  Local Arrays

integer, parameter :: ndval = 20
real, dimension ( ndval ) :: rhold
integer, dimension ( ndval ) :: ihold
character ( len = 200 ), dimension ( ndval ) :: chold

fnamep = ''
write ( fnamep,'(a,i4.4,a)') 'wrf_hydro_WITHDRAWAL.', pid, '.log'
nend = lnblnk( fnamep )
open (unit=lulog,status='unknown',form='formatted',file=fnamep(1:nend))

!       NOLA

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

call get_free_logical_unit ( lutemp )

jmin_min = 2**30
jmin_max = -( 2**30 )
jmin_old = imiss
linkid_min = jmin_min
linkid_max = jmin_max

PASS: do npass = 1, 2

  open (unit=lutemp,status='old',form='formatted',file=trim(fname_with_data),iostat=ios)

  if ( ios /= 0 ) then
    write (lulog,'(/a)') ' subroutine read_with_info_driver'
    write (lulog,'(a,a)') ' problems opening file ', trim(fname_with_data)
    write (lulog,'(a,i10)') ' ios=', ios
    call exit ( 9 )
    stop
  end if

  nstrt = 1
  nmax = ndval

  do

    read (lutemp,'(a)',iostat=ios) nrec
    if ( ios /= 0 ) then
      close (unit=lutemp,status='keep')
      exit
    end if

    call rdrec ( nstrt, nrec, nmax, chold, rhold, ihold, &
      rmiss, imiss, cmiss, lulog )

    nmo = ihold(1)
    ndy = ihold(2)
    nyr = ihold(3)
    nhr = 0
    nmin = 0
    jmin = imissw

    demand = rhold(1)
    linkid_rd = ihold(4)

    nfind = imiss

    do nc = 1, nlinks
      if ( linkid(nc) == linkid_rd ) then
        nfind = nc
        exit
      end if
    end do

    if ( nfind >= 0 ) then
      call calc_julian_minute ( nyr, nmo, ndy, nhr, nmin, &
        nyr_base, nmo_base, ndy_base, nhr_base, &
        lulog, jmin )
    end if

    if ( nfind >= 0 .and. npass == 1 ) then

      if ( jmin < jmin_min ) jmin_min = jmin
      if ( jmin > jmin_max ) jmin_max = jmin
      if ( jmin_old >= 0 ) then
        jdiff = jmin - jmin_old
        if ( jdiff > 0 .and. jdiff /= jmin_day ) then
          write (lulog,'(/a)') ' subroutine read_with_info_driver'
          write (lulog,'(a)') ' expecting daily data ???'
          write (lulog,'(a,i10)') ' jdiff=', jdiff
          write (lulog,'(a,i10)') ' jmin_day=', jmin_day
          call exit ( 9 )
          stop
        end if
      end if
      jmin_old = jmin
      if ( linkid_rd < linkid_min ) linkid_min = linkid_rd
      if ( linkid_rd > linkid_max ) linkid_max = linkid_rd

    else if ( nfind >= 0 .and. npass == 2 ) then

      ntloc = ( jmin - jmin_min ) / jmin_day
      ntloc = ntloc + 1
      linkid_loc = linkid_rd - linkid_min + 1

      winfo%jmin_store(ntloc) = jmin
      winfo%linkid(ntloc,linkid_loc) = linkid_rd
      winfo%demand(ntloc,linkid_loc) = demand

    end if

  end do

  if ( npass == 1 ) then
    call allocate_winfo
  end if

end do PASS

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call MPI_BARRIER ( HYDRO_COMM_WORLD, ierr )
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!       call MPI_BCAST ( nhold, ndim5, MPI_INTEGER, 0, HYDRO_COMM_WORLD, ierr )

!       if ( ierr /= MPI_SUCCESS ) then
!       write (lulog,'(/a)') ' subroutine read_reservoir_info_driver'
!       write (lulog,'(a)') ' problem on MPI_BCAST for nhold ???'
!       call flush ( lulog )
!       call exit ( 9 )
!       stop
!       end if

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
subroutine calc_julian_minute ( nyr_in, nmo_in, ndy_in, nhr_in, nmin_in, &
  nyr_base, nmo_base, ndy_base, nhr_base, &
  lulog, jul_min )

!  Modules for needed subroutines ...

!  Global data module

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: nyr_in
integer, intent(in) :: nmo_in
integer, intent(in) :: ndy_in
integer, intent(in) :: nhr_in
integer, intent(in) :: nmin_in

integer, intent(in) :: nyr_base
integer, intent(in) :: nmo_base
integer, intent(in) :: ndy_base
integer, intent(in) :: nhr_base

integer, intent(in) :: lulog

integer, intent(inout) :: jul_min

!  Local declarations

integer :: nyr
integer :: nmo
integer :: ndy
integer :: nhr
integer :: nmin
integer :: jday
integer :: jmin
integer :: jminb
integer :: ny
integer :: nyend
integer :: jtest
integer :: nyr_out
integer :: nmo_out
integer :: ndy_out
integer :: nhr_out
integer :: nmin_out

!
!=======================================================================
! Calculate time in julian minutes from the specified reference date.
!=======================================================================
!

jul_min = 0

if ( nyr_in > nyr_base ) then
  nyend = nyr_in - 1
  nmo = 12
  ndy = 31
  nhr = 24
  nmin = 0
  do ny = nyr_base, nyend
    call julian ( nmo, ndy, ny, jday )
    call getjtime ( jday, nhr, nmin, jmin )
    jul_min = jul_min + jmin
  end do
  call julian ( nmo_in, ndy_in, nyr_in, jday )
  call getjtime ( jday, nhr_in, nmin_in, jmin )
  jul_min = jul_min + jmin
else if ( nyr_in == nyr_base ) then
  call julian ( nmo_in, ndy_in, nyr_in, jday )
  call getjtime ( jday, nhr_in, nmin_in, jmin )
  jul_min = jul_min + jmin
else if ( nyr_in < nyr_base ) then
  write (lulog,'(/a)') ' subroutine calc_julian_minute'
  write (lulog,'(a)') &
  ' requested date is before base time for julian minute calculations'
  write (lulog,'(a,i5)') ' nyr_base=',nyr_base
  write (lulog,'(a,i5)') ' nyr_in=',nyr_in
  close (unit=lulog,status='keep')
  stop
end if

end subroutine
!
!***********************************************************************
!
subroutine inverse_julian ( imo, idy, iyr2, jday )

implicit none

!  Procedure dummy argument declarations

integer, intent(inout) :: imo
integer, intent(inout) :: idy
integer, intent(in) :: iyr2
integer, intent(in) :: jday

!  Local declarations

integer, parameter :: nmonth = 12
integer, dimension (nmonth), save :: mday
integer :: iyr
integer :: jsum
integer :: jsumold
integer :: l
integer :: n100
integer :: n400
integer :: nadd
integer :: nleap
integer :: nltest

mday = (/ &
 31, 28, 31, 30, 31, 30, &
 31, 31, 30, 31, 30, 31 &
 /)

!	test for leap year
!	a leap year occurs every 4th year with the exception of
!	centenary years not divisible by 400

if ( iyr2 >= 1900 ) then
  iyr = iyr2
else
  if ( iyr2 <= 50 ) then
    iyr = iyr2 + 2000
  else
    iyr = iyr2 + 1900
  end if
end if

nleap = 0
nltest = mod( iyr,4 )

if ( nltest == 0 ) then
  nleap = 1
  n100 = mod( iyr,100 )
  if ( n100 == 0 ) then
    n400 = mod( iyr,400 )
    if ( n400 /= 0 ) nleap = 0
  end if
end if

jsum = 0

do l = 1, nmonth
  if ( l == 2 ) then
    nadd = nleap
  else
    nadd = 0
  end if
  jsumold = jsum
  jsum = jsum + mday(l) + nadd
  if ( jsum >= jday ) then
    imo = l
    idy = jday - jsumold
    exit
  end if
end do

end subroutine
!
!***********************************************************************
!
subroutine inv_getjtime ( jday, nhr, nmin, jmin )

implicit none

!  Procedure dummy argument declarations

integer, intent(inout) :: jday
integer, intent(inout) :: nhr
integer, intent(inout) :: nmin
integer, intent(in) :: jmin

!  Local declarations

integer :: jdmin
integer :: jhmin
integer :: jminr
real :: xday
real :: xhour

xday = float(jmin) / 1440.0
jday = int( xday )
jdmin = jday * 1440
jminr = jmin - jdmin
xhour = float(jminr) / 60.0
nhr = int( xhour )
jhmin = nhr * 60
nmin = jminr - jhmin
jday = jday + 1

end subroutine
!
!***********************************************************************
!
subroutine inv_julian_minute ( nyr_out, nmo_out, ndy_out, nhr_out, nmin_out, &
  nyr_base, nmo_base, ndy_base, nhr_base, &
  lulog, jul_min )

!  Modules for needed subroutines ...

!  Global data module

implicit none

!  Procedure dummy argument declarations

integer, intent(inout) :: nyr_out
integer, intent(inout) :: nmo_out
integer, intent(inout) :: ndy_out
integer, intent(inout) :: nhr_out
integer, intent(inout) :: nmin_out

integer, intent(in) :: nyr_base
integer, intent(in) :: nmo_base
integer, intent(in) :: ndy_base
integer, intent(in) :: nhr_base

integer, intent(in) :: lulog

integer, intent(in) :: jul_min

!  Local declarations

integer :: nyr
integer :: nmo
integer :: ndy
integer :: nhr
integer :: nmin
integer :: jday
integer :: jmin
integer :: jminb
integer :: ny
integer :: nyend
integer :: jtest

nyr = nyr_base
nmo = 12
ndy = 31
nhr = 24
nmin = 0
jtest = 0

do
  call julian ( nmo, ndy, nyr, jday )
  call getjtime ( jday, nhr, nmin, jmin )
  jtest = jtest + jmin
  if ( jtest > jul_min ) then
    jtest = jtest - jmin
    jmin = jul_min - jtest
    nyr_out = nyr
    call inv_getjtime ( jday, nhr_out, nmin_out, jmin )
    call inverse_julian ( nmo_out, ndy_out, nyr, jday )
    exit
  end if
  nyr = nyr + 1
end do

end subroutine
!
!***********************************************************************
!
subroutine julian ( imo, idy, iyr2, jday )

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: imo
integer, intent(in) :: idy
integer, intent(in) :: iyr2
integer, intent(out) :: jday

!  Local declarations

integer, parameter :: nmonth = 12
integer, dimension (nmonth), save :: mday
integer :: imob
integer :: iyr
integer :: jsum
integer :: l
integer :: n100
integer :: n400
integer :: nadd
integer :: nleap
integer :: nltest

mday = (/ &
 31, 28, 31, 30, 31, 30, &
 31, 31, 30, 31, 30, 31 &
 /)

!	test for leap year
!	a leap year occurs every 4th year with the exception of
!	centenary years not divisible by 400

nleap = 0

if ( iyr2 >= 1900 ) then
  iyr = iyr2
else
  if ( iyr2 <= 50 ) then
    iyr = iyr2 + 2000
  else
    iyr = iyr2 + 1900
  end if
end if

nltest = mod( iyr,4 )

if ( nltest == 0 ) then
  nleap = 1
  n100 = mod( iyr,100 )
  if ( n100 == 0 ) then
    n400 = mod( iyr,400 )
    if ( n400 /= 0 ) nleap = 0
  end if
end if

jsum = 0

imob = imo - 1

if ( imob > 0 ) then
  do l = 1, imob
    if ( l == 2 ) then
      nadd = nleap
    else
      nadd = 0
    end if
    jsum = jsum + mday(l) + nadd
  end do
end if

jday = jsum + idy

end subroutine
!
!***********************************************************************
!
subroutine getjtime ( jday, nhr, nmin, jmin )

implicit none

!  Procedure dummy argument declarations

integer, intent(in) :: jday
integer, intent(in) :: nhr
integer, intent(in) :: nmin
integer, intent(out) :: jmin

jmin = (jday - 1) * 1440 + nhr * 60 + nmin

end subroutine
!
!***********************************************************************
!
subroutine rdrec ( nstrt, nrec, nmax, chold, rhold, ihold, &
  rmiss, imiss, cmiss, lulog )

implicit none

!  Procedure dummy argument declarations

integer, intent(inout) :: nstrt
character ( len = * ), intent(inout) :: nrec
integer, intent(inout) :: nmax
character ( len = * ), intent(inout), dimension (nmax) :: chold
real, intent(inout), dimension (nmax) :: rhold
integer, intent(inout), dimension (nmax) :: ihold
real, intent(in) :: rmiss
integer, intent(in) :: imiss
character ( len = * ), intent(in) :: cmiss
integer, intent(in) :: lulog

!  Local declarations

character ( len = 1 ), dimension (54), save :: alphabet
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
 & 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', &
 & 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', &
 & 'u', 'v', 'w', 'x', 'y', 'z', &
 & 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', &
 & 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', &
 & 'U', 'V', 'W', 'X', 'Y', 'Z', '_', '/' &
 & /)

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

      inner_a: do nc = 1, 54
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
subroutine allocate_winfo

!  Modules for needed subroutines ...

!  Global data module

USE module_global_winfo

implicit none

!  Procedure dummy argument declarations

!  Local declarations

integer :: istatus
integer :: kdum = 1
integer :: nbad
integer, parameter :: jmin_day = 24 * 60

nbad = 0
if ( jmin_min < 0 ) nbad = nbad + 1
if ( jmin_max < 0 ) nbad = nbad + 1
if ( linkid_min < 0 ) nbad = nbad + 1
if ( linkid_max < 0 ) nbad = nbad + 1

if ( nbad > 0 ) then
  write (lulog,'(/a)') ' subroutine allocate_winfo'
  write (lulog,'(a)') ' one or more dimensions NOT DEFINED ???'
  write (lulog,'(a,i10)') ' linkid_min=', linkid_min
  write (lulog,'(a,i10)') ' linkid_max=', linkid_max
  write (lulog,'(a,i10)') ' jmin_min=', jmin_min
  write (lulog,'(a,i10)') ' jmin_max=', jmin_max
  call flush ( lulog )
  call exit ( 9 )
  stop
end if

ntmax_winfo = ( jmin_max - jmin_min ) / jmin_day
ntmax_winfo = ntmax_winfo + 1
linkid_max_winfo = linkid_max - linkid_min + 1

write (lulog,'(/a)') ' subroutine allocate_winfo'
write (lulog,'(a)') ' Dimension SUMMARY'
write (lulog,'(a,i10)') ' linkid_min=', linkid_min
write (lulog,'(a,i10)') ' linkid_max=', linkid_max
write (lulog,'(a,i10)') ' jmin_min=', jmin_min
write (lulog,'(a,i10)') ' jmin_max=', jmin_max
write (lulog,'(a,i10)') ' ntmax_winfo=', ntmax_winfo
write (lulog,'(a,i10)') ' linkid_max_winfo=', linkid_max_winfo

allocate ( winfo%jmin_store(ntmax_winfo), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_winfo', &
  'winfo%jmin_store', istatus, &
  '1D', ntmax_winfo, kdum, kdum, lulog )
end if

allocate ( winfo%linkid(ntmax_winfo,linkid_max_winfo), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_winfo', &
  'winfo%linkid', istatus, &
  '1D', ntmax_winfo, linkid_max_winfo, kdum, lulog )
end if

allocate ( winfo%demand(ntmax_winfo,linkid_max_winfo), stat = istatus )

if ( istatus /= 0 ) then
  call write_alloc_status ( 'subroutine allocate_winfo', &
  'winfo%demand', istatus, &
  '1D', ntmax_winfo, linkid_max_winfo, kdum, lulog )
end if

winfo%jmin_store = imissw
winfo%linkid = imissw
winfo%demand = rmissw

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
!
!***********************************************************************
!
end module module_channel_routing

!! Is this outside the module scope on purpose?
#ifdef MPP_LAND
 subroutine checkReach(ii,  inVar)
   use module_mpp_land
   use module_RT_data, only: rt_domain
   use MODULE_mpp_ReachLS, only : updatelinkv,                   &
                                 ReachLS_write_io, gbcastvalue, &
                                 gbcastreal2
   implicit none
   integer :: ii
   real,dimension(rt_domain(1)%nlinksl) :: inVar
   real:: g_var(rt_domain(1)%gnlinksl)
   call ReachLS_write_io(inVar, g_var)
   if(my_id .eq. io_id) then
      write(ii,*) g_var
      call flush(ii)
   endif
 end subroutine checkReach
#endif
