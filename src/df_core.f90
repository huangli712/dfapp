!!!-----------------------------------------------------------------------
!!! project : azalea
!!! program : df_run
!!!           df_std
!!!           df_ladder
!!!           df_dyson
!!! source  : df_core.f90
!!! type    : subroutines
!!! author  : li huang (email:lihuang.dmft@gmail.com)
!!! history : 09/16/2009 by li huang (created)
!!!           06/03/2019 by li huang (last modified)
!!! purpose : main subroutines for the dual fermion framework.
!!! status  : unstable
!!! comment :
!!!-----------------------------------------------------------------------

!!
!! @sub df_run
!!
!! core computational engine, it is used to dispatch the jobs
!!
  subroutine df_run()
     use control, only : isdia
     use control, only : myid, master

     use context, only : fmesh, bmesh
     use context, only : dmft_y
     use context, only : dual_g, dual_s, dual_b
     use context, only : latt_g, latt_s
     use context, only : susc_c, susc_s

     implicit none

! dispatch the jobs, decide which dual fermion engine should be used
     DF_CORE: &
     select case ( isdia )

         case (1) ! only standard 2nd diagrams are considered
             call df_std()

         case (2) ! only ladder diagrams are considered
             call df_ladder()

         case default
             call s_print_error('df_run','this feature is not implemented')

     end select DF_CORE

! now dual_s (dual self-energy function) and dual_g (dual green's function)
! are already updated, we can try to evaluate the other quantities.

! try to update lattice quantities
     call df_eval_latt_g()
     call df_eval_latt_s()

! try to update local hybridization function. it can be fed back to the
! quantum impurity solver
     call df_eval_dmft_h()

! try to calculate charge susceptibility and spin susceptibility
     call df_eval_susc_c()
     call df_eval_susc_s()

! save the relevant data to external files. they are local hybridization
! function, dual green's function, dual self-energy function, dual bath
! green's function, charge susceptibility, and spin susceptibility. only
! the master node can do this
     if ( myid == master ) then
         call df_dump_dmft_h(fmesh, dmft_y)
     endif ! back if ( myid == master ) block

     if ( myid == master ) then
         call df_dump_dual_g(fmesh, dual_g)
     endif ! back if ( myid == master ) block

     if ( myid == master ) then
         call df_dump_dual_s(fmesh, dual_s)
     endif ! back if ( myid == master ) block

     if ( myid == master ) then
         call df_dump_dual_b(fmesh, dual_b)
     endif ! back if ( myid == master ) block

     if ( myid == master ) then
         call df_dump_latt_g(fmesh, latt_g)
     endif ! back if ( myid == master ) block

     if ( myid == master ) then
         call df_dump_latt_s(fmesh, latt_s)
     endif ! back if ( myid == master ) block

     if ( myid == master ) then
         call df_dump_susc_c(bmesh, susc_c)
     endif ! back if ( myid == master ) block

     if ( myid == master ) then
         call df_dump_susc_s(bmesh, susc_s)
     endif ! back if ( myid == master ) block

     return
  end subroutine df_run

!!
!! @sub df_std
!!
!! implement the standard dual fermion approximation framework. here, only
!! the standard second-order diagrams are taken into considerations.
!!
!!
  subroutine df_std()
     implicit none

     CONTINUE

     return
  end subroutine df_std

!!
!! @sub df_ladder
!!
!! implement the ladder dual fermion approximation framework. here, only
!! the ladder-type diagrams are taken into considerations.
!!
  subroutine df_ladder()
     use constants, only : dp
     use constants, only : one, half, czero
     use constants, only : mystd

     use control, only : norbs
     use control, only : nffrq, nbfrq
     use control, only : nkpts, nkp_x, nkp_y
     use control, only : ndfit, dfmix
     use control, only : beta
     use control, only : myid, master

     use context, only : bmesh
     use context, only : dual_g, dual_s, dual_b
     use context, only : vert_d, vert_m

     implicit none

! local variables
! loop index for dual fermion iterations
     integer  :: it

! loop index for k-points
     integer  :: k

! loop index for orbitals
     integer  :: o

! loop index for bosonic frequency \nu
     integer  :: v

! loop index for fermionic frequency \omega
     integer  :: w

! status flag
     integer  :: istat

! current bosonic frequency
     real(dp) :: om

! dummy complex(dp) arrays, used to do fourier transformation
     complex(dp) :: vr(nkpts)
     complex(dp) :: gr(nkpts)

! matrix form for bubble function, \chi
     complex(dp), allocatable :: imat(:,:)

! matrix form for vertex function (magnetic channel, \gamma^m)
     complex(dp), allocatable :: mmat(:,:)

! matrix form for vertex function (density channel, \gamma^d)
     complex(dp), allocatable :: dmat(:,:)

! fully dressed vertex function, \Gamma
     complex(dp), allocatable :: Gmat(:,:)

! two-particle bubble function
     complex(dp), allocatable :: g2  (:,:,:)

! shifted dual green's function
     complex(dp), allocatable :: gstp(:,:,:)

! new dual green's function
     complex(dp), allocatable :: gnew(:,:,:)

! ladder green's function, used to calculate dual self-energy function
     complex(dp), allocatable :: gvrt(:,:,:)

! allocate memory
     allocate(imat(nffrq,nffrq),       stat=istat)
     allocate(mmat(nffrq,nffrq),       stat=istat)
     allocate(dmat(nffrq,nffrq),       stat=istat)
     allocate(Gmat(nffrq,nffrq),       stat=istat)

     allocate(g2  (nffrq,norbs,nkpts), stat=istat)
     allocate(gstp(nffrq,norbs,nkpts), stat=istat)
     allocate(gnew(nffrq,norbs,nkpts), stat=istat)
     allocate(gvrt(nffrq,norbs,nkpts), stat=istat)

     if ( istat /= 0 ) then
         call s_print_error('df_ladder','can not allocate enough memory')
     endif ! back if ( istat /= 0 ) block

!!========================================================================
!!>>> starting ladder dual fermion iteration                           <<<
!!========================================================================

     DF_LOOP: do it=1,ndfit

         if ( myid == master ) then ! only master node can do it
             write(mystd,'(2X,A,I3)') 'dual fermion iteration (ladder):', it
         endif ! back if ( myid == master ) block

         V_LOOP: do v=1,nbfrq

             om = bmesh(v)
             if ( myid == master ) then ! only master node can do it
                 write(mystd,'(4X,A,I2,A,F12.8,A)') 'bosonic frequency => ', v, ' (', om, ')'
             endif ! back if ( myid == master ) block

             call cat_fill_k(dual_g, gstp, om)
             call cat_dia_2d(dual_g, gstp, g2)
             gvrt = czero

             O_LOOP: do o=1,norbs

                 mmat = vert_m(:,:,v)
                 dmat = vert_d(:,:,v)

                 K_LOOP: do k=1,nkpts

                     call s_diag_z(nffrq, g2(:,o,k), imat)

                     call cat_bse_solver(imat, mmat, Gmat)
                     call s_vecadd_z(nffrq, gvrt(:,o,k), Gmat, half * 3.0_dp)
                     call cat_bse_iterator(1, one, imat, mmat, Gmat)
                     call s_vecadd_z(nffrq, gvrt(:,o,k), Gmat, -half * half * 3.0_dp)

                     call cat_bse_solver(imat, dmat, Gmat)
                     call s_vecadd_z(nffrq, gvrt(:,o,k), Gmat, half * 1.0_dp)
                     call cat_bse_iterator(1, one, imat, dmat, Gmat)
                     call s_vecadd_z(nffrq, gvrt(:,o,k), Gmat, -half * half * 1.0_dp)

                 enddo K_LOOP

                 W_LOOP: do w=1,nffrq
                     call cat_fft_2d(+1, nkp_x, nkp_y, gvrt(w,o,:), vr)
                     call cat_fft_2d(-1, nkp_x, nkp_y, gstp(w,o,:), gr)
                     gr = vr * gr / real(nkpts * nkpts)
                     call cat_fft_2d(+1, nkp_x, nkp_y, gr, vr)
                     dual_s(w,o,:) = dual_s(w,o,:) + vr / beta
                 enddo W_LOOP

             enddo O_LOOP

         enddo V_LOOP

         call df_dyson(+1, gnew, dual_s, dual_b)

         call s_mix_z( size(gnew), dual_g, gnew, dfmix)

         dual_g = gnew
         dual_s = czero

         if ( myid == master ) then
             write(mystd,*)
         endif

     enddo DF_LOOP

!!========================================================================
!!>>> finishing ladder dual fermion iteration                          <<<
!!========================================================================

     call df_dyson(-1, dual_g, dual_s, dual_b)

! deallocate memory
     deallocate(imat)
     deallocate(mmat)
     deallocate(dmat)
     deallocate(Gmat)

     deallocate(g2)
     deallocate(gstp)
     deallocate(gnew)
     deallocate(gvrt)

     return
  end subroutine df_ladder

!!
!! @sub df_dyson
!!
!! try to calculate the dual green's function or self-energy function by
!! using the dyson equation
!!
  subroutine df_dyson(op, dual_g, dual_s, dual_b)
     use constants, only : dp
     use constants, only : one

     use control, only : norbs
     use control, only : nffrq
     use control, only : nkpts

     implicit none

! external arguments
     integer, intent(in) :: op

     complex(dp), intent(inout) :: dual_g(nffrq,norbs,nkpts)
     complex(dp), intent(inout) :: dual_s(nffrq,norbs,nkpts)
     complex(dp), intent(inout) :: dual_b(nffrq,norbs,nkpts)

     if ( op == 1 ) then
         dual_g = one / ( one / dual_b - dual_s )
     else
         dual_s = one / dual_b - one / dual_g
     endif ! back if ( op == 1 ) block

     return
  end subroutine df_dyson
