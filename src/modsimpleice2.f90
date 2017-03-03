!> \file modsimpleice.f90

!>
!!  Ice microphysics.
!>
!! Calculates ice microphysics in a cheap scheme without prognostic nr
!!  simpleice is called from *modmicrophysics*
!! \see  Grabowski, 1998, JAS 
!! and Khairoutdinov and Randall, 2006, JAS 
!!  \author Steef B\"oing, TU Delft
!!  \par Revision list
!
! FJ: seems the ref should be Khairoutdinov and Randall, 2003, JAS 
!
! http://dx.doi.org/10.1175/1520-0469(1998)055%3C3283:TCRMOL%3E2.0.CO;2
! http://dx.doi.org/10.1175/JAS3810.1
! http://dx.doi.org/10.1175/1520-0469(2003)060<0607:CRMOTA>2.0.CO;2   - 2003
!
!  This file is part of DALES.
!
! DALES is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! DALES is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.
!
!  Copyright 1993-2009 Delft University of Technology, Wageningen University, Utrecht University, KNMI
!


module modsimpleice2
  use modmicrodata
  use modfields, only : rhobf
  implicit none
  real :: gamb1r
  real :: gambd1r
  real :: gamb1s
  real :: gambd1s
  real :: gamb1g
  real :: gambd1g
  real :: gam2dr
  real :: gam2ds
  real :: gam2dg
  real :: gammaddr3
  real :: gammadds3
  real :: gammaddg3
  contains

!> Initializes and allocates the arrays
  subroutine initsimpleice
    use modglobal, only : ih,i1,jh,j1,k1,lacz_gamma
    implicit none
    integer:: k


    allocate (qr(2-ih:i1+ih,2-jh:j1+jh,k1)        & ! qr (total precipitation!) converted from a scalar variable
             ,qrp(2-ih:i1+ih,2-jh:j1+jh,k1)       & ! qr tendency due to microphysics only, for statistics
             ,nr(2-ih:i1+ih,2-jh:j1+jh,k1)        & ! qr (total precipitation!) converted from a scalar variable
             ,nrp(2-ih:i1+ih,2-jh:j1+jh,k1)       & ! qr tendency due to microphysics only, for statistics
             ,thlpmcr(2-ih:i1+ih,2-jh:j1+jh,k1)   & ! thl tendency due to microphysics only, for statistics
             ,qtpmcr(2-ih:i1+ih,2-jh:j1+jh,k1)    & ! qt tendency due to microphysics only, for statistics
             ,sed_qr(2-ih:i1+ih,2-jh:j1+jh,k1)    & ! sedimentation rain droplets mixing ratio
             ,qr_spl(2-ih:i1+ih,2-jh:j1+jh,k1)    & ! time-splitting substep qr
             ,ilratio(2-ih:i1+ih,2-jh:j1+jh,k1)   & ! partition ratio cloud water vs cloud ice
             ,rsgratio(2-ih:i1+ih,2-jh:j1+jh,k1)  & ! partition ratio rain vs. snow/graupel
             ,sgratio(2-ih:i1+ih,2-jh:j1+jh,k1)   & ! partition ratio snow vs graupel
             ,lambdar(2-ih:i1+ih,2-jh:j1+jh,k1)   & ! slope parameter for rain
             ,lambdas(2-ih:i1+ih,2-jh:j1+jh,k1)   & ! slope parameter for snow
             ,lambdag(2-ih:i1+ih,2-jh:j1+jh,k1))    ! slope parameter for graupel

    allocate (qrmask(2-ih:i1+ih,2-jh:j1+jh,k1)    & ! mask for rain water
             ,qcmask(2-ih:i1+ih,2-jh:j1+jh,k1))     ! mask for cloud water

    allocate(precep(2-ih:i1+ih,2-jh:j1+jh,k1))      ! precipitation for statistics

    allocate(ccrz(k1),ccsz(k1),ccgz(k1))

     gamb1r=lacz_gamma(bbr+1)
     gambd1r=lacz_gamma(bbr+ddr+1)
     gamb1s=lacz_gamma(bbs+1)
     gambd1s=lacz_gamma(bbs+dds+1)
     gamb1g=lacz_gamma(bbg+1)
     gambd1g=lacz_gamma(bbg+ddg+1)
     gam2dr=lacz_gamma(2.5+0.5*ddr)
     gam2ds=lacz_gamma(2.5+0.5*dds)
     gam2dg=lacz_gamma(2.5+0.5*ddg)
     gammaddr3=lacz_gamma(3.+ddr)
     gammadds3=lacz_gamma(3.+dds)
     gammaddg3=lacz_gamma(3.+ddg)

     
     ! Density corrected fall speed parameters, see Tomita 2008
     ! rhobf is constant in time
     do k=1,k1
        ccrz(k)=ccr*(1.29/rhobf(k))**0.5
        ccsz(k)=ccs*(1.29/rhobf(k))**0.5
        ccgz(k)=ccg*(1.29/rhobf(k))**0.5
     end do

    nrp=0. ! not used in this scheme 
    nr=0.  ! set to 0 here in case the statistics use them
     
  end subroutine initsimpleice

!> Cleaning up after the run
  subroutine exitsimpleice
    implicit none
    deallocate(nr,nrp,qr,qrp,thlpmcr,qtpmcr,sed_qr,qr_spl,ilratio,rsgratio,sgratio,lambdar,lambdas,lambdag)
    deallocate(qrmask,qcmask)
    deallocate(precep)
    deallocate(ccrz,ccsz,ccgz)
  end subroutine exitsimpleice

!> Calculates the microphysical source term.
  subroutine simpleice
    use modglobal, only : i1,j1,k1,rdt,rk3step,timee,rlv,cp,tup,tdn,pi,tmelt,kmax,dzf,dzh
    use modfields, only : sv0,svm,svp,qtp,thlp,qt0,ql0,exnf,rhof,tmp0,rhobf,qvsl,qvsi,esl
    
    use modsimpleicestat, only : simpleicetend
    implicit none
    integer:: i,j,k
    real:: qrsmall, qrsum,qrtest
    real :: qll,qli,ddisp,lwc,autl,tc,times,auti,aut ! autoconvert
    real :: qrr,qrs,qrg, gaccrl,gaccsl,gaccgl,gaccri,gaccsi,gaccgi,accr,accs,accg,acc  !accrete
    real :: ssl,ssi,ventr,vents,ventg,thfun,evapdepr,evapdeps,evapdepg,devap  !evapdep
    real :: dt_spl,wfallmax,vtr,vts,vtg,vtf ! precipitation
    real :: tmp_lambdar, tmp_lambdas, tmp_lambdag
    integer :: jn
    integer :: n_spl      !<  sedimentation time splitting loop

    real :: ilratio_,rsgratio_,sgratio_,lambdar_,lambdas_,lambdag_ ! local values instead of global arrays
    logical :: qrmask_, qcmask_
    logical :: rain_present, snow_present, graupel_present
    
    delt = rdt/ (4. - dble(rk3step))
    
    wfallmax = 9.9 ! cap for fall velocity
    n_spl = ceiling(wfallmax*delt/(minval(dzf)*courantp)) ! number of sub-timesteps for precipitation 
    dt_spl = delt/real(n_spl)                              ! fixed time step for precipitation sub-stepping!
    
    sed_qr = 0. ! reset sedimentation fluxes

    
    
     ! Density corrected fall speed parameters, see Tomita 2008
     ! rhobf is constant in time
     ! do k=1,k1
     !   ccrz(k)=ccr*(1.29/rhobf(k))**0.5
     !   ccsz(k)=ccs*(1.29/rhobf(k))**0.5
     !   ccgz(k)=ccg*(1.29/rhobf(k))**0.5
     ! end do
   
    ! used to check on negative qr and nr
    qrsum=0.
    qrsmall=0.
    ! reset microphysics tendencies
    qrp=0.

    !nrp=0. ! not used in this scheme
    !nr=0.
    
    thlpmcr=0.
    qtpmcr=0.

    do k=kmax,1,-1 ! reverse order for upwind scheme at the end
       do j=2,j1
          do i=2,i1
             rain_present = .false.
             snow_present = .false.
             graupel_present = .false.
             
             ! initialise qr
             qr(i,j,k)= sv0(i,j,k,iqr)
             ! initialise qc mask
             if (ql0(i,j,k) > qcmin) then
                qcmask_ = .true.
             else
                qcmask_ = .false.
             end if
             
             ! initialise qr mask and check if we are not throwing away too much rain
             if (l_rain) then
                qrsum = qrsum+qr(i,j,k)
                if (qr(i,j,k) <= qrmin) then
                   qrmask_ = .false.
                   if(qr(i,j,k)<0.) then
                      qrsmall = qrsmall-qr(i,j,k)
                      qr(i,j,k)=0.
                   end if
                else
                   qrmask_=.true.
                endif
             endif


             ! logic
             !
             ! qrmask: true if cell contains rain. qr > threshold
             ! rsgratio, sgratio, lambda* calculated
             !
             ! qcmask: true if cell contains cloud - condensed water - ql > threshold
             ! ilratio, qll, qli calculated
             !
             ! qr, qrp  - rain, tendency
             ! qtpmcr   - qt tendency from microphysics
             ! thlpmcr  - thl tendency from microphysics
             

             
             !partitioning and determination of intercept parameter

             if(qrmask_.eqv..true.) then
                if(l_warm) then !partitioning and determination of intercept parameter
                   rsgratio(i,j,k)=1.   ! rain vs snow/graupel partitioning
                   rain_present = .true.
                   
                   sgratio(i,j,k)=0.   ! snow versus graupel partitioning
                   lambdar_=(aar*n0rr*gamb1r/(rhof(k)*(qr(i,j,k))))**(1./(1.+bbr)) ! lambda rain
                   !lambdas_=lambdar_ ! lambda snow    ! probably not right but they will not be used
                   !lambdag_=lambdar_ ! lambda graupel
                elseif(l_graupel) then                  
                   rsgratio(i,j,k)=max(0.,min(1.,(tmp0(i,j,k)-tdnrsg)/(tuprsg-tdnrsg))) ! rain vs snow/graupel partitioning   rsg = 1 if t > tuprsg
                   sgratio(i,j,k)=max(0.,min(1.,(tmp0(i,j,k)-tdnsg)/(tupsg-tdnsg))) ! snow versus graupel partitioning    sg = 1 -> only graupel
                   if (rsgratio(i,j,k) > 0) then                                                                               ! sg = 0 -> only snow
                      rain_present = .true.
                      lambdar_=(aar*n0rr*gamb1r/(rhof(k)*(qr(i,j,k)*rsgratio(i,j,k))))**(1./(1.+bbr)) ! lambda rain
                   endif
                   if (rsgratio(i,j,k) < 1) then
                      if (sgratio(i,j,k) > 0) then
                         graupel_present = .true.
                         lambdag_=(aag*n0rg*gamb1g/(rhof(k)*(qr(i,j,k)*(1.-rsgratio(i,j,k))*sgratio(i,j,k))))**(1./(1.+bbg)) ! graupel
                      endif                      
                      if (sgratio(i,j,k) < 1) then
                         snow_present = .true.
                         lambdas_=(aas*n0rs*gamb1s/(rhof(k)*(qr(i,j,k)*(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k)))))**(1./(1.+bbs)) ! snow
                      endif
                   endif

                   ! lambdas, lambdag are inf or nan if no snow/graupel present ??
                   ! no: the +1.e-6 in the denominator make them finite
                   ! no snow/graupel -> large lambda
                else ! rain, snow but no graupel
                   rsgratio(i,j,k)=max(0.,min(1.,(tmp0(i,j,k)-tdnrsg)/(tuprsg-tdnrsg)))   ! rain vs snow/graupel partitioning
                   sgratio(i,j,k)=0.
                   if (rsgratio(i,j,k) > 0) then 
                      rain_present = .true.
                      lambdar_=(aar*n0rr*gamb1r/(rhof(k)*(qr(i,j,k)*rsgratio(i,j,k))))**(1./(1.+bbr)) ! lambda rain
                   endif
                   if (rsgratio(i,j,k) < 1) then
                         snow_present = .true.
                         lambdas_=(aas*n0rs*gamb1s/(rhof(k)*(qr(i,j,k)*(1.-rsgratio(i,j,k)))))**(1./(1.+bbs)) ! lambda snow
                   endif
                   ! lambdag_=lambdas_ ! FJ: probably wrong - routines below don't always check sgratio                                         
                end if
                
                !write(*,*) i,j,k
                !write(*,*) 'qr:', qr(i,j,k)
                !write(*,*) 'rain:', rain_present, 'snow:', snow_present, 'graupel:', graupel_present
                !write(*,*) 'lambdar:', lambdar_,  'lambdas:', lambdas_,  'lambdag:', lambdag_

              endif
              
              
              
              ! Autoconvert
              if (qcmask_.eqv..true.) then
                 if(l_warm) then 
                    ilratio_=1.   
                 else
                    ilratio_=max(0.,min(1.,(tmp0(i,j,k)-tdn)/(tup-tdn)))! cloud water vs cloud ice partitioning
                 endif
                 
                 ! ql partitioning - used here and in Accrete
                 qll=ql0(i,j,k)*ilratio_
                 qli=ql0(i,j,k)-qll
                 
                 if(l_berry.eqv..true.) then ! Berry/Hsie autoconversion
                    ! ql partitioning
                    ! qll=ql0(i,j,k)*ilratio(i,j,k)
                    ! qli=ql0(i,j,k)-qll
                    
                    ddisp=0.146-5.964e-2*alog(Nc_0/2.e9) ! Relative dispersion coefficient for Berry autoconversion
                    lwc=1.e3*rhof(k)*qll ! Liquid water content in g/kg
                    autl=1./rhof(k)*1.67e-5*lwc*lwc/(5. + .0366*Nc_0/(1.e6*ddisp*(lwc+1.e-6)))
                    tc=tmp0(i,j,k)-tmelt ! Temperature wrt melting point
                    times=min(1.e3,(3.56*tc+106.7)*tc+1.e3) ! Time scale for ice autoconversion
                    auti=qli/times
                    aut = min(autl + auti,ql0(i,j,k)/delt)
                    qrp(i,j,k) = qrp(i,j,k)+aut
                    qtpmcr(i,j,k) = qtpmcr(i,j,k)-aut
                    thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*aut
                 else  ! Lin/Kessler autoconversion as in Khairoutdinov and Randall, 2006

                    ! ql partitioning
                    ! qll=ql0(i,j,k)*ilratio(i,j,k)
                    ! qli=ql0(i,j,k)-qll
                    
                    autl=max(0.,timekessl*(qll-qll0))
                    tc=tmp0(i,j,k)-tmelt
                    auti=max(0.,betakessi*exp(0.025*tc)*(qli-qli0))
                    aut = min(autl + auti,ql0(i,j,k)/delt)
                    qrp(i,j,k) = qrp(i,j,k)+aut
                    qtpmcr(i,j,k) = qtpmcr(i,j,k)-aut
                    thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*aut
                 endif

              endif

              ! Accrete
              
              if (qrmask_.eqv..true.) then
                 if (qcmask_.eqv..true.) then ! apply mask
                    ! ql partitioning - calculated in Autoconvert
                    !qll=ql0(i,j,k)*ilratio(i,j,k)
                    !qli=ql0(i,j,k)-qll

                    ! qr partitioning
                    qrr=qr(i,j,k)*rsgratio(i,j,k)
                    qrs=qr(i,j,k)*(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))
                    qrg=qr(i,j,k)*(1.-rsgratio(i,j,k))*sgratio(i,j,k)
                    ! collection of cloud water by rain etc.

                    accr = 0
                    accs = 0
                    accg = 0
                    if (rain_present) then
                       gaccrl=pi/4.*ccrz(k)*ceffrl*rhof(k)*qll*qrr*lambdar_**(bbr-2.-ddr)*gammaddr3/(aar*gamb1r)
                       gaccri=pi/4.*ccrz(k)*ceffri*rhof(k)*qli*qrr*lambdar_**(bbr-2.-ddr)*gammaddr3/(aar*gamb1r)
                       accr=(gaccrl+gaccri) !*qrr/(qrr+1.e-9)
                    endif

                    if (snow_present) then
                       gaccsl=pi/4.*ccsz(k)*ceffsl*rhof(k)*qll*qrs*lambdas_**(bbs-2.-dds)*gammadds3/(aas*gamb1s)
                       gaccsi=pi/4.*ccsz(k)*ceffsi*rhof(k)*qli*qrs*lambdas_**(bbs-2.-dds)*gammadds3/(aas*gamb1s)
                       accs=(gaccsl+gaccsi) !*qrs/(qrs+1.e-9)  ! why this division? makes accr small if qr* << 1e-9
                    endif

                    if (graupel_present) then
                       gaccgl=pi/4.*ccgz(k)*ceffgl*rhof(k)*qll*qrg*lambdag_**(bbg-2.-ddg)*gammaddg3/(aag*gamb1g)
                       gaccgi=pi/4.*ccgz(k)*ceffgi*rhof(k)*qli*qrg*lambdag_**(bbg-2.-ddg)*gammaddg3/(aag*gamb1g)
                       accg=(gaccgl+gaccgi) !*qrg/(qrg+1.e-9)
                    endif
                    
                    acc= min(accr+accs+accg,ql0(i,j,k)/delt)  ! total growth by accretion
                    qrp(i,j,k) = qrp(i,j,k)+acc
                    qtpmcr(i,j,k) = qtpmcr(i,j,k)-acc
                    thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*acc
                 end if
              end if

              ! evapdep
              
              if (qrmask_.eqv..true.) then
                  ! saturation ratios
                 ssl=(qt0(i,j,k)-ql0(i,j,k))/qvsl(i,j,k)
                 ssi=(qt0(i,j,k)-ql0(i,j,k))/qvsi(i,j,k)
                 !integration over ventilation factors and diameters, see e.g. seifert 2008
                 evapdepr = 0
                 evapdeps = 0
                 evapdepg = 0
                 thfun=1.e-7/(2.2*tmp0(i,j,k)/esl(i,j,k)+2.2e2/tmp0(i,j,k))  ! thermodynamic function
                 
                 if (rain_present) then
                    ventr=.78*n0rr/lambdar_**2 + gam2dr*.27*n0rr*sqrt(ccrz(k)/2.e-5)*lambdar_**(-2.5-0.5*ddr)
                    evapdepr=(4.*pi/(betar*rhof(k)))*(ssl-1.)*ventr*thfun
                 endif
                 if (snow_present) then
                    vents=.78*n0rs/lambdas_**2 + gam2ds*.27*n0rs*sqrt(ccsz(k)/2.e-5)*lambdas_**(-2.5-0.5*dds)
                    evapdeps=(4.*pi/(betas*rhof(k)))*(ssi-1.)*vents*thfun
                 endif
                 if (graupel_present) then
                    ventg=.78*n0rg/lambdag_**2 + gam2dg*.27*n0rg*sqrt(ccgz(k)/2.e-5)*lambdag_**(-2.5-0.5*ddg)
                    evapdepg=(4.*pi/(betag*rhof(k)))*(ssi-1.)*ventg*thfun
                 endif
                 
                 ! total growth by deposition and evaporation
                 ! limit with qr and ql after accretion and autoconversion
                 devap= max(min(evapfactor*(evapdepr+evapdeps+evapdepg),ql0(i,j,k)/delt+qrp(i,j,k)),-qr(i,j,k)/delt-qrp(i,j,k))
                 qrp(i,j,k) = qrp(i,j,k)+devap
                 qtpmcr(i,j,k) = qtpmcr(i,j,k)-devap
                 thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*devap
                 
                  ! ! Grabowski 1998 has different coefficients here for snow
                 
                 
              end if


              ! precipitate - part 1
              qr_spl(i,j,k) = qr(i,j,k) ! prepare for sub-timestepping precipitation
                                        ! this is the first substep, using lambdas already calculated
              if (qrmask_.eqv..true.) then
                 vtf = 0
                 if (rain_present) then
                    vtr=ccrz(k)*(gambd1r/gamb1r)/(lambdar_**ddr)  ! terminal velocity rain
                    vtf = vtf + rsgratio(i,j,k)*vtr
                 endif                
                 if (snow_present) then
                    vts=ccsz(k)*(gambd1s/gamb1s)/(lambdas_**dds)  ! terminal velocity snow
                    vtf = vtf + (1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))*vts
                 endif                 
                 if (graupel_present) then
                    vtg=ccgz(k)*(gambd1g/gamb1g)/(lambdag_**ddg)  ! terminal velocity graupel
                    vtf = vtf + (1.-rsgratio(i,j,k))*sgratio(i,j,k)*vtg
                 endif
                 ! vtf=rsgratio(i,j,k)*vtr+(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))*vts+(1.-rsgratio(i,j,k))*sgratio(i,j,k)*vtg ! weighted
                 vtf = min(wfallmax,vtf)
                 ! write(*,*) 'vtf', vtf
                 
                 precep(i,j,k) = vtf*qr_spl(i,j,k)
                 sed_qr(i,j,k) = precep(i,j,k)*rhobf(k) ! convert to flux
              else
                 precep(i,j,k) = 0.
                 sed_qr(i,j,k) = 0.
              end if

              !  advect precipitation using upwind scheme
              ! note this relies on loop order - k decreasing

              qr_spl(i,j,k) = qr_spl(i,j,k) + (sed_qr(i,j,k+1) - sed_qr(i,j,k))*dt_spl/(dzh(k+1)*rhobf(k))
          enddo
       enddo
    enddo


    ! precipitate part 2
    

    !  advect precipitation using upwind scheme
!    do k=1,kmax
!    do j=2,j1
!    do i=2,i1
!      qr_spl(i,j,k) = qr_spl(i,j,k) + (sed_qr(i,j,k+1) - sed_qr(i,j,k))*dt_spl/(dzh(k+1)*rhobf(k))
!    enddo
!    enddo
!    enddo
! merged into loop above - OK when counting don
    
    write(*,*) 'n_spl', n_spl
    ! begin time splitting loop
    IF (n_spl > 1) THEN
      DO jn = 2 , n_spl

        ! reset fluxes at each step of loop
        sed_qr = 0.
        do k=kmax,1,-1
        do j=2,j1
        do i=2,i1
          if (qr_spl(i,j,k) > qrmin) then
            ! re-evaluate lambda
            !lambdar(i,j,k)=(aar*n0rr*gamb1r/(rhof(k)*(qr_spl(i,j,k)*rsgratio(i,j,k)+1.e-6)))**(1./(1.+bbr)) ! lambda rain
            !lambdas(i,j,k)=(aas*n0rs*gamb1s/(rhof(k)*(qr_spl(i,j,k)*(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))+1.e-6)))**(1./(1.+bbs)) ! lambda snow
            !lambdag(i,j,k)=(aag*n0rg*gamb1g/(rhof(k)*(qr_spl(i,j,k)*(1.-rsgratio(i,j,k))*sgratio(i,j,k)+1.e-6)))**(1./(1.+bbg)) ! lambda graupel
            !vtr=ccrz(k)*(gambd1r/gamb1r)/(lambdar(i,j,k)**ddr)  ! terminal velocity rain
            !vts=ccsz(k)*(gambd1s/gamb1s)/(lambdas(i,j,k)**dds)  ! terminal velocity snow
            !vtg=ccgz(k)*(gambd1g/gamb1g)/(lambdag(i,j,k)**ddg)  ! terminal velocity graupel

             ! what's with the 1e-6? just to avoid negative values?

             !these ifs are here to avoid performing the power calculations unless they are going to be used
            if (rsgratio(i,j,k) > 0) then
               tmp_lambdar=(aar*n0rr*gamb1r/(rhof(k)*(qr_spl(i,j,k)*rsgratio(i,j,k))))**(1./(1.+bbr)) ! lambda rain
               vtr=ccrz(k)*(gambd1r/gamb1r)/(tmp_lambdar**ddr)  ! terminal velocity rain
            else
               vtr = 0
            end if
            
            if ( (1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k)) > 0 ) then
               tmp_lambdas=(aas*n0rs*gamb1s/(rhof(k)*(qr_spl(i,j,k)*(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k)))))**(1./(1.+bbs)) ! lambda snow
               vts=ccsz(k)*(gambd1s/gamb1s)/(tmp_lambdas**dds)  ! terminal velocity snow
            else
               vts = 0
            end if

            if ( (1.-rsgratio(i,j,k))*sgratio(i,j,k) > 0 ) then
               tmp_lambdag=(aag*n0rg*gamb1g/(rhof(k)*(qr_spl(i,j,k)*(1.-rsgratio(i,j,k))*sgratio(i,j,k))))**(1./(1.+bbg)) ! lambda graupel
               vtg=ccgz(k)*(gambd1g/gamb1g)/(tmp_lambdag**ddg)  ! terminal velocity graupel
            else
               vtg = 0
            end if
            
            vtf=rsgratio(i,j,k)*vtr+(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))*vts+(1.-rsgratio(i,j,k))*sgratio(i,j,k)*vtg  ! mass-weighted terminal velocity
            vtf=min(wfallmax,vtf)
            sed_qr(i,j,k) = vtf*qr_spl(i,j,k)*rhobf(k)
          else
            sed_qr(i,j,k) = 0.
         endif

         ! update
         ! note k must decrease in the loop
         qr_spl(i,j,k) = qr_spl(i,j,k) + (sed_qr(i,j,k+1) - sed_qr(i,j,k))*dt_spl/(dzh(k+1)*rhobf(k))
        enddo
        enddo
        enddo

        ! merge this loop with the one above - if looping from high k to low, so that sed_qr(k+1) has already been updated
        ! gains: only one loop
        !        need to calculate only where there is something to advect
        ! 
        ! only need sed_qr from the previous layer, not a full block
        !do k=1,kmax 
       ! do j=2,j1
       ! do i=2,i1
       !   qr_spl(i,j,k) = qr_spl(i,j,k) + (sed_qr(i,j,k+1) - sed_qr(i,j,k))*dt_spl/(dzh(k+1)*rhobf(k))
        !enddo
       ! enddo
       ! enddo

      ! end time splitting loop and if n>1
      ENDDO
    ENDIF

    ! no thl and qt tendencies build in, implying no heat transfer between precipitation and air
!    do k=1,kmax
!    do j=2,j1
!    do i=2,i1
!      qrp(i,j,k)= qrp(i,j,k) + (qr_spl(i,j,k) - qr(i,j,k))/delt
!    enddo
!    enddo
!    enddo
! merge with loop below


    
    if (qrsmall > 0.000001*qrsum) then
      write(*,*)'amount of neg. qr thrown away is too high  ',timee, ' sec', qrsmall, qrsum
    end if


    do k=1,k1
    do j=2,j1
    do i=2,i1
      qrp(i,j,k)= qrp(i,j,k) + (qr_spl(i,j,k) - qr(i,j,k))/delt
      qrtest=svm(i,j,k,iqr)+(svp(i,j,k,iqr)+qrp(i,j,k))*delt
      if (qrtest .lt. qrmin) then ! correction, after Jerome's implementation in Gales
        qtp(i,j,k) = qtp(i,j,k) + qtpmcr(i,j,k) + svm(i,j,k,iqr)/delt + svp(i,j,k,iqr) + qrp(i,j,k)
        thlp(i,j,k) = thlp(i,j,k) +thlpmcr(i,j,k) - (rlv/(cp*exnf(k)))*(svm(i,j,k,iqr)/delt + svp(i,j,k,iqr) + qrp(i,j,k))
        svp(i,j,k,iqr) = - svm(i,j,k,iqr)/delt
      else
      svp(i,j,k,iqr)=svp(i,j,k,iqr)+qrp(i,j,k)
      thlp(i,j,k)=thlp(i,j,k)+thlpmcr(i,j,k)
      qtp(i,j,k)=qtp(i,j,k)+qtpmcr(i,j,k)
      ! adjust negative qr tendencies at the end of the time-step
     end if
    enddo
    enddo
    enddo

!    if (l_rain) then
!      call simpleicetend !after corrections
!    endif
  end subroutine simpleice








  
  subroutine autoconvert
    use modglobal, only : i1,j1,k1,rlv,cp,tmelt
    use modfields, only : ql0,exnf,rhof,tmp0
    implicit none
    real :: qll,qli,ddisp,lwc,autl,tc,times,auti,aut
    integer:: i,j,k

    if(l_berry.eqv..true.) then ! Berry/Hsie autoconversion
    do k=1,k1
    do j=2,j1
    do i=2,i1
        if (qcmask(i,j,k).eqv..true.) then
          ! ql partitioning
          qll=ql0(i,j,k)*ilratio(i,j,k)
          qli=ql0(i,j,k)-qll
          ddisp=0.146-5.964e-2*alog(Nc_0/2.e9) ! Relative dispersion coefficient for Berry autoconversion
          lwc=1.e3*rhof(k)*qll ! Liquid water content in g/kg
          autl=1./rhof(k)*1.67e-5*lwc*lwc/(5. + .0366*Nc_0/(1.e6*ddisp*(lwc+1.e-6)))
          tc=tmp0(i,j,k)-tmelt ! Temperature wrt melting point
          times=min(1.e3,(3.56*tc+106.7)*tc+1.e3) ! Time scale for ice autoconversion
          auti=qli/times
          aut = min(autl + auti,ql0(i,j,k)/delt)
          qrp(i,j,k) = qrp(i,j,k)+aut
          qtpmcr(i,j,k) = qtpmcr(i,j,k)-aut
          thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*aut
        endif
      enddo
      enddo
      enddo
    else ! Lin/Kessler autoconversion as in Khairoutdinov and Randall, 2006
      do k=1,k1
      do j=2,j1
      do i=2,i1
        if (qcmask(i,j,k).eqv..true.) then
          ! ql partitioning
          qll=ql0(i,j,k)*ilratio(i,j,k)
          qli=ql0(i,j,k)-qll
          autl=max(0.,timekessl*(qll-qll0))
          tc=tmp0(i,j,k)-tmelt
          auti=max(0.,betakessi*exp(0.025*tc)*(qli-qli0))
          aut = min(autl + auti,ql0(i,j,k)/delt)
          qrp(i,j,k) = qrp(i,j,k)+aut
          qtpmcr(i,j,k) = qtpmcr(i,j,k)-aut
          thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*aut
        endif
      enddo
      enddo
      enddo
    endif

  end subroutine autoconvert

  subroutine accrete
    use modglobal, only : i1,j1,k1,rlv,cp,pi
    use modfields, only : ql0,exnf,rhof
    implicit none
    real :: qll,qli,qrr,qrs,qrg,&
            gaccrl,gaccsl,gaccgl,gaccri,gaccsi,gaccgi,accr,accs,accg,acc
    integer:: i,j,k

    do k=1,k1
    do j=2,j1
    do i=2,i1
      if (qrmask(i,j,k).eqv..true.) then
      if (qcmask(i,j,k).eqv..true.) then ! apply mask
        ! ql partitioning
        qll=ql0(i,j,k)*ilratio(i,j,k)
        qli=ql0(i,j,k)-qll
        ! qr partitioning
        qrr=qr(i,j,k)*rsgratio(i,j,k)
        qrs=qr(i,j,k)*(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))
        qrg=qr(i,j,k)*(1.-rsgratio(i,j,k))*sgratio(i,j,k)
        ! collection of cloud water by rain etc.
        gaccrl=pi/4.*ccrz(k)*ceffrl*rhof(k)*qll*qrr*lambdar(i,j,k)**(bbr-2.-ddr)*gammaddr3/(aar*gamb1r)
        gaccsl=pi/4.*ccsz(k)*ceffsl*rhof(k)*qll*qrs*lambdas(i,j,k)**(bbs-2.-dds)*gammadds3/(aas*gamb1s)
        gaccgl=pi/4.*ccgz(k)*ceffgl*rhof(k)*qll*qrg*lambdag(i,j,k)**(bbg-2.-ddg)*gammaddg3/(aag*gamb1g)
        gaccri=pi/4.*ccrz(k)*ceffri*rhof(k)*qli*qrr*lambdar(i,j,k)**(bbr-2.-ddr)*gammaddr3/(aar*gamb1r)
        gaccsi=pi/4.*ccsz(k)*ceffsi*rhof(k)*qli*qrs*lambdas(i,j,k)**(bbs-2.-dds)*gammadds3/(aas*gamb1s)
        gaccgi=pi/4.*ccgz(k)*ceffgi*rhof(k)*qli*qrg*lambdag(i,j,k)**(bbg-2.-ddg)*gammaddg3/(aag*gamb1g)
        accr=(gaccrl+gaccri)*qrr/(qrr+1.e-9)
        accs=(gaccsl+gaccsi)*qrs/(qrs+1.e-9)
        accg=(gaccgl+gaccgi)*qrg/(qrg+1.e-9)
        acc= min(accr+accs+accg,ql0(i,j,k)/delt)  ! total growth by accretion
        qrp(i,j,k) = qrp(i,j,k)+acc
        qtpmcr(i,j,k) = qtpmcr(i,j,k)-acc
        thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*acc
      end if
      end if
    enddo
    enddo
    enddo

  end subroutine accrete

  subroutine evapdep
    use modglobal, only : i1,j1,k1,rlv,cp,pi
    use modfields, only : qt0,ql0,exnf,rhof,tmp0,qvsl,qvsi,esl
    implicit none

    real :: ssl,ssi,ventr,vents,ventg,&
            thfun,evapdepr,evapdeps,evapdepg,devap
    integer:: i,j,k

    do k=1,k1
    do j=2,j1
    do i=2,i1
       if (qrmask(i,j,k).eqv..true.) then
        ! saturation ratios
        ssl=(qt0(i,j,k)-ql0(i,j,k))/qvsl(i,j,k)
        ssi=(qt0(i,j,k)-ql0(i,j,k))/qvsi(i,j,k)
        !integration over ventilation factors and diameters, see e.g. seifert 2008
        ventr=.78*n0rr/lambdar(i,j,k)**2 + gam2dr*.27*n0rr*sqrt(ccrz(k)/2.e-5)*lambdar(i,j,k)**(-2.5-0.5*ddr)
        vents=.78*n0rs/lambdas(i,j,k)**2 + gam2ds*.27*n0rs*sqrt(ccsz(k)/2.e-5)*lambdas(i,j,k)**(-2.5-0.5*dds)
        ventg=.78*n0rg/lambdag(i,j,k)**2 + gam2dg*.27*n0rg*sqrt(ccgz(k)/2.e-5)*lambdag(i,j,k)**(-2.5-0.5*ddg)
        thfun=1.e-7/(2.2*tmp0(i,j,k)/esl(i,j,k)+2.2e2/tmp0(i,j,k))  ! thermodynamic function
        evapdepr=(4.*pi/(betar*rhof(k)))*(ssl-1.)*ventr*thfun
        evapdeps=(4.*pi/(betas*rhof(k)))*(ssi-1.)*vents*thfun
        evapdepg=(4.*pi/(betag*rhof(k)))*(ssi-1.)*ventg*thfun
        ! total growth by deposition and evaporation
        ! limit with qr and ql after accretion and autoconversion
        devap= max(min(evapfactor*(evapdepr+evapdeps+evapdepg),ql0(i,j,k)/delt+qrp(i,j,k)),-qr(i,j,k)/delt-qrp(i,j,k))
        qrp(i,j,k) = qrp(i,j,k)+devap
        qtpmcr(i,j,k) = qtpmcr(i,j,k)-devap
        thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*devap

          

          
        ! ! saturation ratios
        ! ssl=(qt0(i,j,k)-ql0(i,j,k))/qvsl(i,j,k)
        ! ssi=(qt0(i,j,k)-ql0(i,j,k))/qvsi(i,j,k)

        ! thfun=1.e-7/(2.2*tmp0(i,j,k)/esl(i,j,k)+2.2e2/tmp0(i,j,k))  ! thermodynamic function

        ! !integration over ventilation factors and diameters, see e.g. seifert 2008
        ! ventr=.78*n0rr/lambdar(i,j,k)**2 + gam2dr*.27*n0rr*sqrt(ccrz(k)/2.e-5)*lambdar(i,j,k)**(-2.5-0.5*ddr)
        ! evapdepr=(4.*pi/(betar*rhof(k)))*(ssl-1.)*ventr*thfun


        ! ! these IF:s are for optimizatin - calculate only if necessary
        ! ! CHECK - they may be wrong !
        ! ! what is lambdas if no snow is present?
        ! !    --seems large but finite -> evapdeps contribution is small
        
        ! if (lambdas(i,j,k) /= 0) then ! snow - calculate only if snow present 
        !    vents=.78*n0rs/lambdas(i,j,k)**2 + gam2ds*.27*n0rs*sqrt(ccsz(k)/2.e-5)*lambdas(i,j,k)**(-2.5-0.5*dds)
        !    evapdeps=(4.*pi/(betas*rhof(k)))*(ssi-1.)*vents*thfun
        ! else
        !    evapdeps = 0
        ! endif

        ! if (lambdag(i,j,k) /= 0) then ! graupel - calculate only if graupel present
        !    ventg=.78*n0rg/lambdag(i,j,k)**2 + gam2dg*.27*n0rg*sqrt(ccgz(k)/2.e-5)*lambdag(i,j,k)**(-2.5-0.5*ddg)
        !    evapdepg=(4.*pi/(betag*rhof(k)))*(ssi-1.)*ventg*thfun
        ! else
        !    evapdepg = 0
        ! endif

        ! ! Grabowski 1998 has different coefficients here for snow
        
        
        
        ! ! total growth by deposition and evaporation
        ! ! limit with qr and ql after accretion and autoconversion
        ! devap= max(min(evapfactor*(evapdepr+evapdeps+evapdepg),ql0(i,j,k)/delt+qrp(i,j,k)),-qr(i,j,k)/delt-qrp(i,j,k))
        ! qrp(i,j,k) = qrp(i,j,k)+devap
        ! qtpmcr(i,j,k) = qtpmcr(i,j,k)-devap
        ! thlpmcr(i,j,k) = thlpmcr(i,j,k)+(rlv/(cp*exnf(k)))*devap
      end if
    enddo
    enddo
    enddo

  end subroutine evapdep

  subroutine precipitate
    use modglobal, only : i1,j1,k1,kmax,dzf,dzh
    use modfields, only : rhof,rhobf
    implicit none
    integer :: i,j,k,jn
    integer :: n_spl      !<  sedimentation time splitting loop
    real :: dt_spl,wfallmax,vtr,vts,vtg,vtf
    real :: tmp_lambdar, tmp_lambdas, tmp_lambdag
    
    wfallmax = 9.9
    n_spl = ceiling(wfallmax*delt/(minval(dzf)*courantp))
    dt_spl = delt/real(n_spl) !fixed time step

    sed_qr = 0. ! reset sedimentation fluxes


    ! merge this loop with the one below for regularity?
    ! cost: must calculate lambda once more
    !       separate assignment to qr_spl
    do k=1,k1 !all these loops should go to kmax, not k1 ?
    do j=2,j1
    do i=2,i1
      qr_spl(i,j,k) = qr(i,j,k)
      if (qrmask(i,j,k).eqv..true.) then
        vtr=ccrz(k)*(gambd1r/gamb1r)/(lambdar(i,j,k)**ddr)  ! terminal velocity rain
        vts=ccsz(k)*(gambd1s/gamb1s)/(lambdas(i,j,k)**dds)  ! terminal velocity snow
        vtg=ccgz(k)*(gambd1g/gamb1g)/(lambdag(i,j,k)**ddg)  ! terminal velocity graupel
        vtf=rsgratio(i,j,k)*vtr+(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))*vts+(1.-rsgratio(i,j,k))*sgratio(i,j,k)*vtg ! weighted
        vtf = min(wfallmax,vtf)
        precep(i,j,k) = vtf*qr_spl(i,j,k)
        sed_qr(i,j,k) = precep(i,j,k)*rhobf(k) ! convert to flux
      else
        precep(i,j,k) = 0.
        sed_qr(i,j,k) = 0.
      end if
    enddo
    enddo
    enddo

    !  advect precipitation using upwind scheme
    do k=1,kmax
    do j=2,j1
    do i=2,i1
      qr_spl(i,j,k) = qr_spl(i,j,k) + (sed_qr(i,j,k+1) - sed_qr(i,j,k))*dt_spl/(dzh(k+1)*rhobf(k))
    enddo
    enddo
    enddo

    ! begin time splitting loop
    IF (n_spl > 1) THEN
      DO jn = 2 , n_spl

        ! reset fluxes at each step of loop
        sed_qr = 0.
        do k=1,k1
        do j=2,j1
        do i=2,i1
          if (qr_spl(i,j,k) > qrmin) then
            ! re-evaluate lambda
            !lambdar(i,j,k)=(aar*n0rr*gamb1r/(rhof(k)*(qr_spl(i,j,k)*rsgratio(i,j,k)+1.e-6)))**(1./(1.+bbr)) ! lambda rain
            !lambdas(i,j,k)=(aas*n0rs*gamb1s/(rhof(k)*(qr_spl(i,j,k)*(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))+1.e-6)))**(1./(1.+bbs)) ! lambda snow
            !lambdag(i,j,k)=(aag*n0rg*gamb1g/(rhof(k)*(qr_spl(i,j,k)*(1.-rsgratio(i,j,k))*sgratio(i,j,k)+1.e-6)))**(1./(1.+bbg)) ! lambda graupel
            !vtr=ccrz(k)*(gambd1r/gamb1r)/(lambdar(i,j,k)**ddr)  ! terminal velocity rain
            !vts=ccsz(k)*(gambd1s/gamb1s)/(lambdas(i,j,k)**dds)  ! terminal velocity snow
            !vtg=ccgz(k)*(gambd1g/gamb1g)/(lambdag(i,j,k)**ddg)  ! terminal velocity graupel

             ! what's with the 1e-6? just to avoid negative values?

             !these ifs are here to avoid performing the power calculations unless they are going to be used
            if (rsgratio(i,j,k) > 0) then
               tmp_lambdar=(aar*n0rr*gamb1r/(rhof(k)*(qr_spl(i,j,k)*rsgratio(i,j,k)+1.e-6)))**(1./(1.+bbr)) ! lambda rain
               vtr=ccrz(k)*(gambd1r/gamb1r)/(tmp_lambdar**ddr)  ! terminal velocity rain
            else
               vtr = 0
            end if
            
            if ( (1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k)) > 0 ) then
               tmp_lambdas=(aas*n0rs*gamb1s/(rhof(k)*(qr_spl(i,j,k)*(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))+1.e-6)))**(1./(1.+bbs)) ! lambda snow
               vts=ccsz(k)*(gambd1s/gamb1s)/(tmp_lambdas**dds)  ! terminal velocity snow
            else
               vts = 0
            end if

            if ( (1.-rsgratio(i,j,k))*sgratio(i,j,k) > 0 ) then
               tmp_lambdag=(aag*n0rg*gamb1g/(rhof(k)*(qr_spl(i,j,k)*(1.-rsgratio(i,j,k))*sgratio(i,j,k)+1.e-6)))**(1./(1.+bbg)) ! lambda graupel
               vtg=ccgz(k)*(gambd1g/gamb1g)/(tmp_lambdag**ddg)  ! terminal velocity graupel
            else
               vtg = 0
            end if
            
            vtf=rsgratio(i,j,k)*vtr+(1.-rsgratio(i,j,k))*(1.-sgratio(i,j,k))*vts+(1.-rsgratio(i,j,k))*sgratio(i,j,k)*vtg  ! mass-weighted terminal velocity
            vtf=min(wfallmax,vtf)
            sed_qr(i,j,k) = vtf*qr_spl(i,j,k)*rhobf(k)
          else
            sed_qr(i,j,k) = 0.
          endif
        enddo
        enddo
        enddo

        ! merge this loop with the one above - if looping from high k to low, so that sed_qr(k+1) has already been updated
        ! gains: only one loop
        !        need to calculate only where there is something to advect
        ! 
        ! only need sed_qr from the previous layer, not a full block
        do k=1,kmax 
        do j=2,j1
        do i=2,i1
          qr_spl(i,j,k) = qr_spl(i,j,k) + (sed_qr(i,j,k+1) - sed_qr(i,j,k))*dt_spl/(dzh(k+1)*rhobf(k))
        enddo
        enddo
        enddo

      ! end time splitting loop and if n>1
      ENDDO
    ENDIF

    ! no thl and qt tendencies build in, implying no heat transfer between precipitation and air
    do k=1,kmax
    do j=2,j1
    do i=2,i1
      qrp(i,j,k)= qrp(i,j,k) + (qr_spl(i,j,k) - qr(i,j,k))/delt
    enddo
    enddo
    enddo

  end subroutine precipitate

end module modsimpleice2
