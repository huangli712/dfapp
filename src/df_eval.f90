!!!-----------------------------------------------------------------------
!!! project : azalea
!!! program : df_eval_dmft_h
!!!           df_eval_latt_g
!!!           df_eval_latt_s
!!!           df_eval_susc_c
!!!           df_eval_susc_s
!!! source  : df_eval.f90
!!! type    : subroutines
!!! author  : li huang (email:lihuang.dmft@gmail.com)
!!! history : 04/29/2009 by li huang (created)
!!!           05/29/2019 by li huang (last modified)
!!! purpose : try to evaluate some key observables.
!!! status  : unstable
!!! comment :
!!!-----------------------------------------------------------------------

!!========================================================================
!!>>> evaluate local observables                                       <<<
!!========================================================================

!!
!! @sub df_eval_dmft_h
!!
!! calculate the local hybridization function within the dual fermion framework
!!
  subroutine df_eval_dmft_h()
     use constants, only : one

     use control, only : norbs
     use control, only : nffrq

     use context, only : dmft_g, dmft_h
     use context, only : dual_g
     use context, only : latt_g

     implicit none

! local variables
! loop index for fermionic frequency \omega
     integer :: i

! loop index for orbitals
     integer :: j

!!
!! note:
!!
!! dual_g and latt_g must be updated ahead of time.
!!
     do j=1,norbs
         do i=1,nffrq
             associate ( zh => ( sum( dual_g(i,j,:) ) / sum( latt_g(i,j,:) ) ) )
                 dmft_h(i,j) = dmft_h(i,j) + one / dmft_g(i,j) * zh 
             end associate
         enddo ! over i={1,nffrq} loop
     enddo ! over j={1,norbs} loop

     return
  end subroutine df_eval_dmft_h

!!========================================================================
!!>>> evaluate lattice observables                                     <<<
!!========================================================================

!!
!! @sub df_eval_latt_g
!!
!! calculate the lattice green's function within the dual fermion framework
!!
  subroutine df_eval_latt_g()
     use constants, only : one

     use control, only : norbs
     use control, only : nffrq
     use control, only : nkpts

     use context, only : ek
     use context, only : dmft_g, dmft_h
     use context, only : dual_g
     use context, only : latt_g

     implicit none

! local variables
! loop index for fermionic frequency \omega
     integer :: i

! loop index for orbitals
     integer :: j

! loop index for k-points
     integer :: k

!!
!! note:
!!
!! dual_g must be updated ahead of time. however, dmft_h is old.
!!
     do k=1,nkpts
         do j=1,norbs
             do i=1,nffrq
                 associate ( zh => ( one / ( dmft_h(i,j) - ek(k) ) ) )
                     latt_g(i,j,k) =  zh + zh**2 / dmft_g(i,j)**2 * dual_g(i,j,k)
                 end associate
             enddo ! over i={1,nffrq} loop
         enddo ! over j={1,norbs} loop
     enddo ! over k={1,nkpts} loop

     return
  end subroutine df_eval_latt_g

!!
!! @sub df_eval_latt_s
!!
!! calculate the lattice self-energy function within the dual fermion framework
!!
  subroutine df_eval_latt_s()
     use constants, only : one

     use control, only : norbs
     use control, only : nffrq
     use control, only : nkpts

     use context, only : dmft_g, dmft_s
     use context, only : dual_s
     use context, only : latt_s

     implicit none

! local variables
! loop index for fermionic frequency \omega
     integer :: i

! loop index for orbitals
     integer :: j

! loop index for k-points
     integer :: k

!!
!! note:
!!
!! dual_s must be updated ahead of time. however, dmft_g and dmft_s are old.
!!
     do k=1,nkpts
         do j=1,norbs
             do i=1,nffrq
                 associate ( val => ( dual_s(i,j,k) * dmft_g(i,j) + one ) )
                     latt_s(i,j,k) = dmft_s(i,j) + dual_s(i,j,k) / val
                 end associate
             enddo ! over i={1,nffrq} loop
         enddo ! over j={1,norbs} loop
     enddo ! over k={1,nkpts} loop

     return
  end subroutine df_eval_latt_s

!!========================================================================
!!>>> evaluate q-dependent susceptibilities                            <<<
!!========================================================================

!!
!! @sub df_eval_susc_c
!!
!! calculate the charge susceptibility within the dual fermion framework
!!
  subroutine df_eval_susc_c()
     use constants, only : dp, one

     use control, only : nkpts, norbs, nffrq
     use context, only : dmft_g, dmft_h, ek, dual_b, dual_g

     implicit none

     integer :: i, j, k
     complex(dp), allocatable :: Lwk(:,:,:)
     allocate(Lwk(nffrq,norbs,nkpts))

     !! print *, 'here'

     do k=1,nkpts
         do j=1,norbs
             do i=1,nffrq
                 Lwk(i,j,k) = one / ( one / dmft_g(i,j) + dmft_h(i,j) - ek(k) ) 
             enddo ! over i={1,nffrq} loop
         enddo ! over j={1,norbs} loop
     enddo ! over k={1,nkpts} loop

     Lwk = Lwk / dual_b * (-one)
     Lwk = Lwk * dual_g

     !! DEBUG
     do i=1,nffrq
         print *, i, Lwk(i,1,1), Lwk(i,1,2)
     enddo
     STOP

     return
  end subroutine df_eval_susc_c

!!
!! @sub df_eval_susc_s
!!
!! calculate the spin susceptibility within the dual fermion framework
!!
  subroutine df_eval_susc_s()
     implicit none

     return
  end subroutine df_eval_susc_s
