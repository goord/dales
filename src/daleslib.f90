!> \file daleslib.f90
!! Library API for Dales.
!  This file is part of DALESLIB.
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

! Initializes the libary's dales instance. This routine requires a path to the namoptions file to be passed 
! as an argument, and optionally the mpi communicator can be set too (this is particularly useful when 
! nesting into other parallelized codes). If the latter argument is not provided, the communicator will be 
! assumed to be MPI_COMM_WORLD. 

module daleslib

    implicit none

    integer, parameter :: FIELDID_U=1
    integer, parameter :: FIELDID_V=2
    integer, parameter :: FIELDID_W=3
    integer, parameter :: FIELDID_THL=4
    integer, parameter :: FIELDID_QT=5
    
    integer :: my_task,master_task

    real, allocatable :: u_tend(:)
    real, allocatable :: v_tend(:)
    real, allocatable :: thl_tend(:)
    real, allocatable :: qt_tend(:)
        
    
    contains

        subroutine initialize(path,mpi_comm)

            !!----------------------------------------------------------------
            !!     0.0    USE STATEMENTS FOR CORE MODULES
            !!----------------------------------------------------------------
            use modmpi,             only : initmpicomm,myid
            use modstartup,         only : startup

            !----------------------------------------------------------------
            !     0.1     USE STATEMENTS FOR ADDONS STATISTICAL ROUTINES
            !----------------------------------------------------------------
            use modcape,            only : initcape
            use modchecksim,        only : initchecksim
            use modstat_nc,         only : initstat_nc
            !use modspectra2,       only : initspectra2
            use modtimestat,        only : inittimestat
            use modgenstat,         only : initgenstat
            use modradstat,         only : initradstat
            use modlsmstat,         only : initlsmstat
            use modsampling,        only : initsampling
            use modquadrant,        only : initquadrant
            use modcrosssection,    only : initcrosssection 
            use modAGScross,        only : initAGScross
            use modlsmcrosssection, only : initlsmcrosssection
            use modcloudfield,      only : initcloudfield
            use modfielddump,       only : initfielddump
            use modsamptend,        only : initsamptend

            use modbulkmicrostat,   only : initbulkmicrostat
            use modbudget,          only : initbudget
            use modheterostats,     only : initheterostats

            ! modules below are disabled by default to improve compilation time
            !use modstress,         only : initstressbudget

            !use modtilt,           only : inittilt
            !use modparticles,      only : initparticles
            use modnudge,           only : initnudge
            !use modprojection,     only : initprojection
            use modchem,            only : initchem
            use modcanopy,          only : initcanopy

            implicit none

            character(len=256), intent(in)  :: path
            integer, intent(in), optional   :: mpi_comm

            !----------------------------------------------------------------
            !     0      INITIALIZE MPI COMMUNICATOR
            !----------------------------------------------------------------

            call initmpicomm(mpi_comm)

            !----------------------------------------------------------------
            !     1      READ NAMELISTS,INITIALISE GRID, CONSTANTS AND FIELDS
            !----------------------------------------------------------------

            call startup(path)

            !---------------------------------------------------------
            !      2     INITIALIZE STATISTICAL ROUTINES AND ADD-ONS
            !---------------------------------------------------------
            call initchecksim
            call initstat_nc   ! Should be called before stat-routines that might do netCDF
            call inittimestat  ! Timestat must preceed all other timeseries that could write in the same netCDF file (unless stated otherwise
            call initgenstat   ! Genstat must preceed all other statistics that could write in the same netCDF file (unless stated otherwise
            !call inittilt
            call initsampling
            call initquadrant
            call initcrosssection
            call initAGScross
            call initlsmcrosssection
            !call initprojection
            call initcloudfield
            call initfielddump
            call initsamptend
            call initradstat
            call initlsmstat
            !call initparticles
            call initnudge
            call initbulkmicrostat
            call initbudget
            !call initstressbudget
            call initchem
            call initheterostats
            call initcanopy

            !call initspectra2
            call initcape

            !Set additional library information
            my_task=myid
            master_task=0

            call initdaleslib
            
        end subroutine initialize


        ! allocate arrays for tendencies set through the daleslib interface        
        subroutine initdaleslib
          use modglobal, only: itot,jtot,kmax
          ! use modforces, only: lforce_user
          implicit none

          allocate(u_tend(1:kmax))
          allocate(v_tend(1:kmax))
          allocate(thl_tend(1:kmax))
          allocate(qt_tend(1:kmax))
          u_tend = 0
          v_tend = 0
          thl_tend = 0
          qt_tend = 0
          ! lforce_user = .true.
          
        end subroutine initdaleslib

                ! deallocate arrays for tendencies 
        subroutine exitdaleslib
          use modglobal, only: itot,jtot,kmax
          implicit none

          deallocate(u_tend)
          deallocate(v_tend)
          deallocate(thl_tend)
          deallocate(qt_tend)
          
        end subroutine exitdaleslib

        subroutine force_tendencies
          use modglobal, only : i1,j1,kmax,dzh,nsv,lmomsubs
          use modfields, only : up,vp,thlp,qtp,svp
          implicit none
          integer i,j,k

          !if (myid == 0)
          print *, "force_tendencies"
          !print *, "u_tend"
          !print *, u_tend
          !print *, i1, j1, kmax
          
          !print *, up(:,:,5)

          print*, u_tend(4)
          print*, u_tend(5)
          print*, u_tend(6)
          
          do k=1,kmax
             up  (2:i1,2:j1,k) = up  (2:i1,2:j1,k) + u_tend(k) 
             vp  (2:i1,2:j1,k) = vp  (2:i1,2:j1,k) + v_tend(k) 
             thlp(2:i1,2:j1,k) = thlp(2:i1,2:j1,k) + thl_tend(k)
             qtp (2:i1,2:j1,k) = qtp (2:i1,2:j1,k) + qt_tend(k)            
          enddo
          !print *, up(:,:,6)
          
        end subroutine force_tendencies



        
        ! Performs a single time step. This is exactly the code inside the time loop of the main program. 
        ! If the adaptive time stepping is enabled, the new time stamp is not guaranteed to be a dt later.

        subroutine step
            !!----------------------------------------------------------------
            !!     0.0    USE STATEMENTS FOR CORE MODULES
            !!----------------------------------------------------------------
            use modstartup,         only : writerestartfiles
            use modtimedep,         only : timedep
            use modboundary,        only : boundary, grwdamp! JvdD ,tqaver
            use modthermodynamics,  only : thermodynamics
            use modmicrophysics,    only : microsources
            use modsurface,         only : surface
            use modsubgrid,         only : subgrid
            use modforces,          only : forces, coriolis, lstend
            use modradiation,       only : radiation
            use modpois,            only : poisson
            !use modedgecold,       only : coldedge

            !----------------------------------------------------------------
            !     0.1     USE STATEMENTS FOR ADDONS STATISTICAL ROUTINES
            !----------------------------------------------------------------
            use modcape,            only : docape
            use modchecksim,        only : checksim
            !use modspectra2,       only : dospecs, tanhfilter
            use modtimestat,        only : timestat
            use modgenstat,         only : genstat
            use modradstat,         only : radstat
            use modlsmstat,         only : lsmstat
            use modsampling,        only : sampling
            use modquadrant,        only : quadrant
            use modcrosssection,    only : crosssection
            use modAGScross,        only : AGScross
            use modlsmcrosssection, only : lsmcrosssection
            use modcloudfield,      only : cloudfield
            use modfielddump,       only : fielddump
            use modsamptend,        only : samptend,tend_start,tend_adv,tend_subg,tend_force,&
                tend_rad,tend_ls,tend_micro,tend_topbound,tend_pois,tend_addon,tend_coriolis,leibniztend

            use modbulkmicrostat,   only : bulkmicrostat
            use modbudget,          only : budgetstat
            use modheterostats,     only : heterostats

            ! modules below are disabled by default to improve compilation time
            !use modstress,         only : stressbudgetstat

            !use modtilt,           only : tiltedgravity, tiltedboundary
            !use modparticles,      only : particles
            use modnudge,           only : nudge
            !use modprojection,     only : projection
            use modchem,            only : twostep
            use modcanopy,          only : canopy

            implicit none

            write (*,*) "STEP !!\n"

                      
            call tstep_update                           ! Calculate new timestep
            call timedep
            call samptend(tend_start,firstterm=.true.)

            !-----------------------------------------------------
            !   3.1   RADIATION         
            !-----------------------------------------------------
            call radiation !radiation scheme
            call samptend(tend_rad)

            !-----------------------------------------------------
            !   3.2   THE SURFACE LAYER
            !-----------------------------------------------------
            call surface

            !-----------------------------------------------------
            !   3.3   ADVECTION AND DIFFUSION
            !-----------------------------------------------------
            call advection
            call samptend(tend_adv)
            call subgrid
            call canopy
            call samptend(tend_subg)

            !-----------------------------------------------------
            !   3.4   REMAINING TERMS
            !-----------------------------------------------------
            call coriolis !remaining terms of ns equation
            call samptend(tend_coriolis)
            call forces !remaining terms of ns equation
            call force_tendencies         ! NOTE - not standard DALES, these are our own tendencies
            call samptend(tend_force)

            call lstend !large scale forcings
            call samptend(tend_ls)
            call microsources !Drizzle etc.
            call samptend(tend_micro)

            !------------------------------------------------------
            !   3.4   EXECUTE ADD ONS
            !------------------------------------------------------
            call nudge
            !    call dospecs
            !    call tiltedgravity

            call samptend(tend_addon)

            !-----------------------------------------------------------------------
            !   3.5  PRESSURE FLUCTUATIONS, TIME INTEGRATION AND BOUNDARY CONDITIONS
            !-----------------------------------------------------------------------
            call grwdamp !damping at top of the model
            !JvdD    call tqaver !set thl, qt and sv(n) equal to slab average at level kmax
            call samptend(tend_topbound)
            call poisson
            call samptend(tend_pois,lastterm=.true.)

            call tstep_integrate                        ! Apply tendencies to all variables
            call boundary
            !call tiltedboundary
            !-----------------------------------------------------
            !   3.6   LIQUID WATER CONTENT AND DIAGNOSTIC FIELDS
            !-----------------------------------------------------
            call thermodynamics
            call leibniztend
            !-----------------------------------------------------
            !   3.7  WRITE RESTARTFILES AND DO STATISTICS
            !------------------------------------------------------
            call twostep
            !call coldedge
            call checksim
            call timestat  !Timestat must preceed all other timeseries that could write in the same netCDF file (unless stated otherwise
            call genstat  !Genstat must preceed all other statistics that could write in the same netCDF file (unless stated otherwise
            call radstat
            call lsmstat
            call sampling
            call quadrant
            call crosssection
            call AGScross
            call lsmcrosssection
            !call tanhfilter
            call docape
            !call projection
            call cloudfield
            call fielddump
            !call particles

            call bulkmicrostat
            call budgetstat
            !call stressbudgetstat
            call heterostats

            call writerestartfiles


        end subroutine step

        ! Performs repeatedly time stepping until the tstop (measured in seconds after the cold start) is reached. 
        ! Note that the resulting model time may be a bit later than tstop.

        subroutine run_to(tstop)

            use modglobal,          only: timee,longint,rk3step

            implicit none

            integer(kind=longint),intent(in) :: tstop

            do while (timee < tstop .or. rk3step < 3)
                call step
            end do

        end subroutine run_to

        ! Returns the model time, measured in s after the cold start.

        function get_model_time() result(ret)

            use modglobal,          only: timee,longint

            implicit none

            integer(kind=longint) :: ret

            ret=timee

        end function get_model_time

        ! Cleans up; closes file handles ans deallocates arrays. This is a copy of the code 
        ! in the main program after the time loop. 

        subroutine finalize

            !!----------------------------------------------------------------
            !!     0.0    USE STATEMENTS FOR CORE MODULES
            !!----------------------------------------------------------------
            use modstartup,         only : exitmodules

            !----------------------------------------------------------------
            !     0.1     USE STATEMENTS FOR ADDONS STATISTICAL ROUTINES
            !----------------------------------------------------------------
            use modcape,            only : exitcape
            use modgenstat,         only : exitgenstat
            use modradstat,         only : exitradstat
            use modlsmstat,         only : exitlsmstat
            use modsampling,        only : exitsampling
            use modquadrant,        only : exitquadrant
            use modcrosssection,    only : exitcrosssection  
            use modAGScross,        only : exitAGScross
            use modlsmcrosssection, only : exitlsmcrosssection
            use modcloudfield,      only : cloudfield
            use modfielddump,       only : exitfielddump
            use modsamptend,        only : exitsamptend

            use modbulkmicrostat,   only : exitbulkmicrostat
            use modbudget,          only : exitbudget
            use modheterostats,     only : exitheterostats

            ! modules below are disabled by default to improve compilation time
            !use modstress,         only : exitstressbudget

            !use modtilt,           only : exittilt
            !use modparticles,      only : exitparticles
            use modnudge,           only : exitnudge
            use modcanopy,          only : exitcanopy

            implicit none

            !--------------------------------------------------------
            !    4    FINALIZE ADD ONS AND THE MAIN PROGRAM
            !-------------------------------------------------------
            call exitgenstat
            call exitradstat
            call exitlsmstat
            !call exitparticles
            call exitnudge
            call exitsampling
            call exitquadrant
            call exitsamptend
            call exitbulkmicrostat
            call exitbudget
            !call exitstressbudget
            call exitcrosssection
            call exitAGScross
            call exitlsmcrosssection
            call exitcape
            call exitfielddump
            call exitheterostats
            call exitcanopy
            call exitmodules
            call exitdaleslib

        end subroutine finalize

        function grid_shape() result(s)

            use modglobal, only: itot,jtot,kmax

            implicit none

            integer:: s(3)

            s=(/itot,jtot,kmax/)

        end function

        function allocate_z_axis(a) result(ierr)

            use modglobal, only: kmax

            implicit none

            real, allocatable :: a(:)
            integer           :: ierr

            ierr=0
            
            if(allocated(a)) then
                deallocate(a,stat=ierr)
            endif
            
            if(ierr/=0) then
                return
            endif

            allocate(a(kmax),stat=ierr)

        end function

        function allocate_2d(a) result(ierr)

            use modglobal, only: itot,jtot

            implicit none

            real, allocatable :: a(:,:)
            integer           :: ierr

            ierr=0
            
            if(allocated(a)) then
                deallocate(a,stat=ierr)
            endif
            
            if(ierr/=0) then
                return
            endif

            allocate(a(itot,jtot),stat=ierr)

        end function
        
        function allocate_3d(a) result(ierr)

            use modglobal, only: itot,jtot,kmax

            implicit none

            real, allocatable :: a(:,:,:)
            integer           :: ierr

            ierr=0
            
            if(allocated(a)) then
                deallocate(a,stat=ierr)
            endif
            
            if(ierr/=0) then
                return
            endif

            allocate(a(itot,jtot,kmax),stat=ierr)

        end function

        function get_field_layer_avg(field_id,a) result(ierr)

            use modglobal, only: i1,j1,k1,itot,jtot,kmax
            use modfields, only: u0,v0,w0,thl0,qt0
            use modmpi,    only: gatherlayeravg, gatherlayeravg2, gatherlayeravg3, myid

            implicit none

            integer                         :: ierr,iminl,imaxl,jminl,jmaxl,kminl,kmaxl
            integer, intent(in)             :: field_id
            real, intent(out)               :: a(kmax)

            ! Local array sizes, without ghost cells:
            iminl=2
            imaxl=i1
            jminl=2
            jmaxl=j1
            kminl=1
            kmaxl=k1-1

            ierr=0

            select case(field_id)
            case(FIELDID_U)
               !call gatherlayeravg(u0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,kmax)
               !call gatherlayeravg2(u0, a)
               call gatherlayeravg3(u0(2:i1, 2:j1, :), a)
            case(FIELDID_V)
               !call gatherlayeravg(v0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,kmax)
               !call gatherlayeravg2(v0, a)
               call gatherlayeravg3(v0(2:i1, 2:j1, :), a)
            case(FIELDID_W)
               !call gatherlayeravg(w0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,kmax)
               !call gatherlayeravg2(w0, a)
               call gatherlayeravg3(w0(2:i1, 2:j1, :), a)
            case(FIELDID_THL)
               !call gatherlayeravg(thl0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,kmax)
               !call gatherlayeravg2(thl0, a)
               call gatherlayeravg3(thl0(2:i1, 2:j1, :), a)
            case(FIELDID_QT)
               !call gatherlayeravg(qt0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,kmax)
               !call gatherlayeravg2(qt0, a)
               call gatherlayeravg3(qt0(2:i1, 2:j1, :), a)
            case default
                ierr=1
            end select

            !if (myid == 0) then
            !  print *, "get_field_layer_avg returning:"
            !  print *, a
            !endif
          end function get_field_layer_avg
          
          function set_field_tendency(field_id,a) result(ierr)

            use modglobal, only: i1,j1,k1,itot,jtot,kmax
            use modfields, only: u0,v0,w0,thl0,qt0
            use modmpi,    only: gatherlayeravg
            use modmpi,    only: comm3d,  my_real, myid
            
            implicit none

            integer                         :: ierr,iminl,imaxl,jminl,jmaxl,kminl,kmaxl
            integer, intent(in)             :: field_id
            real, intent(in)               :: a(kmax)

            ! Local array sizes, without ghost cells:
            iminl=2
            imaxl=i1
            jminl=2
            jmaxl=j1
            kminl=1
            kmaxl=k1-1

            ierr=0

            call MPI_BCAST(a, kmaxl, MY_REAL, 0, comm3d, ierr)
            
            select case(field_id)
            case(FIELDID_U)
               if(myid == 0) then
                  print *, "set_field_tendency U"
                  print *, a
                endif
               u_tend = a
               if(myid == 0) then
                  print *, u_tend
                  print *, "u_tend(1)"
                  print *, u_tend(1)
                  print *, "u_tend(2)"
                  print *, u_tend(2)

               endif
            case(FIELDID_V)
               v_tend = a
            case(FIELDID_W)
               print *, "No tendency setting for w at the moment :("
               ierr = 1
            case(FIELDID_THL)
               thl_tend = a
            case(FIELDID_QT)
               qt_tend = a
            case default
                ierr=1 
            end select

        end function

        

        
        function get_field_3d(field_id,a) result(ierr)

            use modglobal, only: i1,j1,k1,itot,jtot,kmax
            use modfields, only: u0,v0,w0,thl0,qt0
            use modmpi,    only: gathervol

            implicit none

            integer                         :: ierr,iminl,imaxl,jminl,jmaxl,kminl,kmaxl
            integer, intent(in)             :: field_id
            real, intent(out)               :: a(itot,jtot,kmax)

            ! Local array sizes, without ghost cells:
            iminl=2
            imaxl=i1
            jminl=2
            jmaxl=j1
            kminl=1
            kmaxl=k1-1

            ierr=0

            select case(field_id)
            case(FIELDID_U)
                call gathervol(u0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,itot,jtot,kmax)
            case(FIELDID_V)
                call gathervol(v0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,itot,jtot,kmax)
            case(FIELDID_W)
                call gathervol(w0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,itot,jtot,kmax)
            case(FIELDID_THL)
                call gathervol(thl0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,itot,jtot,kmax)
            case(FIELDID_QT)
                call gathervol(qt0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,a,itot,jtot,kmax)
            case default
                ierr=1
            end select

        end function

        function get_field_2d(field_id,klev,a) result(ierr)

            use modglobal, only: i1,j1,k1,itot,jtot
            use modfields, only: u0,v0,w0,thl0,qt0
            use modmpi,    only: gatherslab

            implicit none

            integer                         :: ierr,iminl,imaxl,jminl,jmaxl,&
                                             & kminl,kmaxl
            integer, intent(in)             :: field_id,klev
            real, intent(out)               :: a(itot,jtot)

            ! Local array sizes, without ghost cells:
            iminl=2
            imaxl=i1
            jminl=2
            jmaxl=j1
            kminl=1
            kmaxl=k1-1

            ierr=0

            select case(field_id)
            case(FIELDID_U)
                call gatherslab(u0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,klev,a,itot,jtot)
            case(FIELDID_V)
                call gatherslab(v0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,klev,a,itot,jtot)
            case(FIELDID_W)
                call gatherslab(w0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,klev,a,itot,jtot)
            case(FIELDID_THL)
                call gatherslab(thl0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,klev,a,itot,jtot)
            case(FIELDID_QT)
                call gatherslab(qt0,iminl,imaxl,jminl,jmaxl,kminl,kmaxl,klev,a,itot,jtot)
            case default
                ierr=1
            end select

        end function

    end module daleslib
