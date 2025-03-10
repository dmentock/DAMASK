!--------------------------------------------------------------------------------------------------
!> @author Pratheek Shanthraj, Max-Planck-Institut für Eisenforschung GmbH
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @author Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @brief Grid solver for mechanics: Spectral basic
!--------------------------------------------------------------------------------------------------
module grid_mechanical_spectral_basic
#include <petsc/finclude/petscsnes.h>
#include <petsc/finclude/petscdmda.h>
  use PETScDMDA
  use PETScSNES
#if (PETSC_VERSION_MAJOR==3 && PETSC_VERSION_MINOR>14) && !defined(PETSC_HAVE_MPI_F90MODULE_VISIBILITY)
  use MPI_f08
#endif

  use prec
  use parallelization
  use CLI
  use IO
  use HDF5
  use HDF5_utilities
  use math
  use rotations
  use spectral_utilities
  use config
  use homogenization
  use discretization_grid

#if (PETSC_VERSION_MAJOR==3 && PETSC_VERSION_MINOR>14) && !defined(PETSC_HAVE_MPI_F90MODULE_VISIBILITY)
  implicit none(type,external)
#else
  implicit none
#endif
  private

  type(tSolutionParams) :: params

  type :: tNumerics
    logical :: update_gamma                                                                         !< update gamma operator with current stiffness
    integer :: &
      itmin, &                                                                                      !< minimum number of iterations
      itmax                                                                                         !< maximum number of iterations
    real(pREAL) :: &
      eps_div_atol, &                                                                               !< absolute tolerance for equilibrium
      eps_div_rtol, &                                                                               !< relative tolerance for equilibrium
      eps_stress_atol, &                                                                            !< absolute tolerance for fullfillment of stress BC
      eps_stress_rtol                                                                               !< relative tolerance for fullfillment of stress BC
  end type tNumerics

  type(tNumerics) :: num                                                                            ! numerics parameters. Better name?

!--------------------------------------------------------------------------------------------------
! PETSc data
  DM   :: da
  SNES :: SNES_mechanical
  Vec  :: solution_vec

!--------------------------------------------------------------------------------------------------
! common pointwise data
  real(pREAL), dimension(:,:,:,:,:), allocatable ::  &
    F_lastInc, &                                                                                    !< field of previous compatible deformation gradients
    Fdot                                                                                            !< field of assumed rate of compatible deformation gradient

!--------------------------------------------------------------------------------------------------
! stress, stiffness and compliance average etc.
  real(pREAL), dimension(3,3) :: &
    F_aimDot = 0.0_pREAL, &                                                                         !< assumed rate of average deformation gradient
    F_aim = math_I3, &                                                                              !< current prescribed deformation gradient
    F_aim_lastInc = math_I3, &                                                                      !< previous average deformation gradient
    P_av = 0.0_pREAL, &                                                                             !< average 1st Piola--Kirchhoff stress
    P_aim = 0.0_pREAL
  character(len=:), allocatable :: incInfo                                                          !< time and increment information
  real(pREAL), dimension(3,3,3,3) :: &
    C_volAvg = 0.0_pREAL, &                                                                         !< current volume average stiffness
    C_volAvgLastInc = 0.0_pREAL, &                                                                  !< previous volume average stiffness
    C_minMaxAvg = 0.0_pREAL, &                                                                      !< current (min+max)/2 stiffness
    C_minMaxAvgLastInc = 0.0_pREAL, &                                                               !< previous (min+max)/2 stiffness
    C_minMaxAvgRestart = 0.0_pREAL, &                                                               !< (min+max)/2 stiffnes (restart)
    S = 0.0_pREAL                                                                                   !< current compliance (filled up with zeros)

  real(pREAL) :: &
    err_BC, &                                                                                       !< deviation from stress BC
    err_div                                                                                         !< RMS of div of P

#if (PETSC_VERSION_MAJOR==3 && PETSC_VERSION_MINOR>14) && !defined(PETSC_HAVE_MPI_F90MODULE_VISIBILITY)
  type(MPI_Status) :: status
#else
  integer, dimension(MPI_STATUS_SIZE) :: status
#endif

  integer :: &
    totalIter = 0                                                                                   !< total iteration in current increment

  public :: &
    grid_mechanical_spectral_basic_init, &
    grid_mechanical_spectral_basic_solution, &
    grid_mechanical_spectral_basic_forward, &
    grid_mechanical_spectral_basic_updateCoords, &
    grid_mechanical_spectral_basic_restartWrite

contains

!--------------------------------------------------------------------------------------------------
!> @brief allocates all necessary fields and fills them with data, potentially from restart info
!--------------------------------------------------------------------------------------------------
subroutine grid_mechanical_spectral_basic_init()

  real(pREAL), dimension(3,3,cells(1),cells(2),cells3) :: P
  PetscErrorCode :: err_PETSc
  integer(MPI_INTEGER_KIND) :: err_MPI
  real(pREAL), pointer, dimension(:,:,:,:) :: &
    F                                                                                               ! pointer to solution data
  PetscInt, dimension(0:worldsize-1) :: localK
  real(pREAL), dimension(3,3,product(cells(1:2))*cells3) :: temp33n
  integer(HID_T) :: fileHandle, groupHandle
  type(tDict), pointer :: &
    num_grid
  character(len=pSTRLEN) :: &
    extmsg = ''


  print'(/,1x,a)', '<<<+-  grid_mechanical_spectral_basic init  -+>>>'; flush(IO_STDOUT)

  print'(/,1x,a)', 'P. Eisenlohr et al., International Journal of Plasticity 46:37–53, 2013'
  print'(  1x,a)', 'https://doi.org/10.1016/j.ijplas.2012.09.012'//IO_EOL

  print'(  1x,a)', 'P. Shanthraj et al., International Journal of Plasticity 66:31–45, 2015'
  print'(  1x,a)', 'https://doi.org/10.1016/j.ijplas.2014.02.006'

!-------------------------------------------------------------------------------------------------
! read numerical parameters and do sanity checks
  num_grid => config_numerics%get_dict('grid',defaultVal=emptyDict)

  num%update_gamma    = num_grid%get_asBool('update_gamma',   defaultVal=.false.)
  num%eps_div_atol    = num_grid%get_asReal('eps_div_atol',   defaultVal=1.0e-4_pREAL)
  num%eps_div_rtol    = num_grid%get_asReal('eps_div_rtol',   defaultVal=5.0e-4_pREAL)
  num%eps_stress_atol = num_grid%get_asReal('eps_stress_atol',defaultVal=1.0e3_pREAL)
  num%eps_stress_rtol = num_grid%get_asReal('eps_stress_rtol',defaultVal=1.0e-3_pREAL)
  num%itmin           = num_grid%get_asInt ('itmin',defaultVal=1)
  num%itmax           = num_grid%get_asInt ('itmax',defaultVal=250)

  if (num%eps_div_atol <= 0.0_pREAL)             extmsg = trim(extmsg)//' eps_div_atol'
  if (num%eps_div_rtol < 0.0_pREAL)              extmsg = trim(extmsg)//' eps_div_rtol'
  if (num%eps_stress_atol <= 0.0_pREAL)          extmsg = trim(extmsg)//' eps_stress_atol'
  if (num%eps_stress_rtol < 0.0_pREAL)           extmsg = trim(extmsg)//' eps_stress_rtol'
  if (num%itmax <= 1)                            extmsg = trim(extmsg)//' itmax'
  if (num%itmin > num%itmax .or. num%itmin < 1)  extmsg = trim(extmsg)//' itmin'

  if (extmsg /= '') call IO_error(301,ext_msg=trim(extmsg))

!--------------------------------------------------------------------------------------------------
! set default and user defined options for PETSc
  call PetscOptionsInsertString(PETSC_NULL_OPTIONS,'-mechanical_snes_type ngmres',err_PETSc)
  CHKERRQ(err_PETSc)
  call PetscOptionsInsertString(PETSC_NULL_OPTIONS,num_grid%get_asStr('petsc_options',defaultVal=''),err_PETSc)
  CHKERRQ(err_PETSc)

!--------------------------------------------------------------------------------------------------
! allocate global fields
  allocate(F_lastInc(3,3,cells(1),cells(2),cells3),source = 0.0_pREAL)
  allocate(Fdot     (3,3,cells(1),cells(2),cells3),source = 0.0_pREAL)

!--------------------------------------------------------------------------------------------------
! initialize solver specific parts of PETSc
  call SNESCreate(PETSC_COMM_WORLD,SNES_mechanical,err_PETSc)
  CHKERRQ(err_PETSc)
  call SNESSetOptionsPrefix(SNES_mechanical,'mechanical_',err_PETSc)
  CHKERRQ(err_PETSc)
  localK            = 0_pPetscInt
  localK(worldrank) = int(cells3,pPetscInt)
  call MPI_Allreduce(MPI_IN_PLACE,localK,worldsize,MPI_INTEGER,MPI_SUM,MPI_COMM_WORLD,err_MPI)
  if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'
  call DMDACreate3d(PETSC_COMM_WORLD, &
         DM_BOUNDARY_NONE, DM_BOUNDARY_NONE, DM_BOUNDARY_NONE, &                                    ! cut off stencil at boundary
         DMDA_STENCIL_BOX, &                                                                        ! Moore (26) neighborhood around central point
         int(cells(1),pPetscInt),int(cells(2),pPetscInt),int(cells(3),pPetscInt), &                 ! global cells
         1_pPetscInt, 1_pPetscInt, int(worldsize,pPetscInt), &
         9_pPetscInt, 0_pPetscInt, &                                                                ! #dof (F, tensor), ghost boundary width (domain overlap)
         [int(cells(1),pPetscInt)],[int(cells(2),pPetscInt)],localK, &                              ! local cells
         da,err_PETSc)                                                                              ! handle, error
  CHKERRQ(err_PETSc)
  call DMsetFromOptions(da,err_PETSc)
  CHKERRQ(err_PETSc)
  call DMsetUp(da,err_PETSc)
  CHKERRQ(err_PETSc)
  call DMcreateGlobalVector(da,solution_vec,err_PETSc)                                              ! global solution vector (cells x 9, i.e. every def grad tensor)
  CHKERRQ(err_PETSc)
  call DMDASNESsetFunctionLocal(da,INSERT_VALUES,formResidual,PETSC_NULL_SNES,err_PETSc)            ! residual vector of same shape as solution vector
  CHKERRQ(err_PETSc)
  call SNESsetConvergenceTest(SNES_mechanical,converged,PETSC_NULL_SNES,PETSC_NULL_FUNCTION,err_PETSc) ! specify custom convergence check function "converged"
  CHKERRQ(err_PETSc)
  call SNESSetDM(SNES_mechanical,da,err_PETSc)
  CHKERRQ(err_PETSc)
  call SNESsetFromOptions(SNES_mechanical,err_PETSc)                                                ! pull it all together with additional CLI arguments
  CHKERRQ(err_PETSc)

!--------------------------------------------------------------------------------------------------
! init fields
  call DMDAVecGetArrayF90(da,solution_vec,F,err_PETSc)                                              ! places pointer on PETSc data
  CHKERRQ(err_PETSc)

  restartRead: if (CLI_restartInc > 0) then
    print'(/,1x,a,i0,a)', 'reading restart data of increment ', CLI_restartInc, ' from file'

    fileHandle  = HDF5_openFile(getSolverJobName()//'_restart.hdf5','r')
    groupHandle = HDF5_openGroup(fileHandle,'solver')

    call HDF5_read(P_aim,groupHandle,'P_aim',.false.)
    call MPI_Bcast(P_aim,9_MPI_INTEGER_KIND,MPI_DOUBLE,0_MPI_INTEGER_KIND,MPI_COMM_WORLD,err_MPI)
    if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'
    call HDF5_read(F_aim,groupHandle,'F_aim',.false.)
    call MPI_Bcast(F_aim,9_MPI_INTEGER_KIND,MPI_DOUBLE,0_MPI_INTEGER_KIND,MPI_COMM_WORLD,err_MPI)
    if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'
    call HDF5_read(F_aim_lastInc,groupHandle,'F_aim_lastInc',.false.)
    call MPI_Bcast(F_aim_lastInc,9_MPI_INTEGER_KIND,MPI_DOUBLE,0_MPI_INTEGER_KIND,MPI_COMM_WORLD,err_MPI)
    if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'
    call HDF5_read(F_aimDot,groupHandle,'F_aimDot',.false.)
    call MPI_Bcast(F_aimDot,9_MPI_INTEGER_KIND,MPI_DOUBLE,0_MPI_INTEGER_KIND,MPI_COMM_WORLD,err_MPI)
    if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'
    call HDF5_read(temp33n,groupHandle,'F')
    F = reshape(temp33n,[9,cells(1),cells(2),cells3])
    call HDF5_read(temp33n,groupHandle,'F_lastInc')
    F_lastInc = reshape(temp33n,[3,3,cells(1),cells(2),cells3])

  elseif (CLI_restartInc == 0) then restartRead
    F_lastInc = spread(spread(spread(math_I3,3,cells(1)),4,cells(2)),5,cells3)                      ! initialize to identity
    F = reshape(F_lastInc,[9,cells(1),cells(2),cells3])
  end if restartRead

  homogenization_F0 = reshape(F_lastInc, [3,3,product(cells(1:2))*cells3])                          ! set starting condition for homogenization_mechanical_response
  call utilities_updateCoords(reshape(F,shape(F_lastInc)))
  call utilities_constitutiveResponse(P,P_av,C_volAvg,C_minMaxAvg, &                                ! stress field, stress avg, global average of stiffness and (min+max)/2
                                      reshape(F,shape(F_lastInc)), &                                ! target F
                                      0.0_pREAL)                                                    ! time increment
  call DMDAVecRestoreArrayF90(da,solution_vec,F,err_PETSc)                                          ! deassociate pointer
  CHKERRQ(err_PETSc)

  restartRead2: if (CLI_restartInc > 0) then
    print'(1x,a,i0,a)', 'reading more restart data of increment ', CLI_restartInc, ' from file'
    call HDF5_read(C_volAvg,groupHandle,'C_volAvg',.false.)
    call MPI_Bcast(C_volAvg,81_MPI_INTEGER_KIND,MPI_DOUBLE,0_MPI_INTEGER_KIND,MPI_COMM_WORLD,err_MPI)
    if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'
    call HDF5_read(C_volAvgLastInc,groupHandle,'C_volAvgLastInc',.false.)
    call MPI_Bcast(C_volAvgLastInc,81_MPI_INTEGER_KIND,MPI_DOUBLE,0_MPI_INTEGER_KIND,MPI_COMM_WORLD,err_MPI)
    if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'
    call HDF5_read(C_minMaxAvg,groupHandle,'C_minMaxAvg',.false.)
    call MPI_Bcast(C_minMaxAvg,81_MPI_INTEGER_KIND,MPI_DOUBLE,0_MPI_INTEGER_KIND,MPI_COMM_WORLD,err_MPI)
    if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'

    call HDF5_closeGroup(groupHandle)
    call HDF5_closeFile(fileHandle)

  end if restartRead2

  call utilities_updateGamma(C_minMaxAvg)
  C_minMaxAvgRestart = C_minMaxAvg

end subroutine grid_mechanical_spectral_basic_init


!--------------------------------------------------------------------------------------------------
!> @brief solution for the basic scheme with internal iterations
!--------------------------------------------------------------------------------------------------
function grid_mechanical_spectral_basic_solution(incInfoIn) result(solution)

!--------------------------------------------------------------------------------------------------
! input data for solution
  character(len=*),            intent(in) :: &
    incInfoIn
  type(tSolutionState)                    :: &
    solution
!--------------------------------------------------------------------------------------------------
! PETSc Data
  PetscErrorCode :: err_PETSc
  SNESConvergedReason :: reason

  incInfo = incInfoIn

!--------------------------------------------------------------------------------------------------
! update stiffness (and gamma operator)
  S = utilities_maskedCompliance(params%rotation_BC,params%stress_mask,C_volAvg)
  if (num%update_gamma) call utilities_updateGamma(C_minMaxAvg)

  call SNESsolve(SNES_mechanical,PETSC_NULL_VEC,solution_vec,err_PETSc)
  CHKERRQ(err_PETSc)
  call SNESGetConvergedReason(SNES_mechanical,reason,err_PETSc)
  CHKERRQ(err_PETSc)

  solution%converged = reason > 0
  solution%iterationsNeeded = totalIter
  solution%termIll = terminallyIll
  terminallyIll = .false.
  P_aim = merge(P_av,P_aim,params%stress_mask)

end function grid_mechanical_spectral_basic_solution


!--------------------------------------------------------------------------------------------------
!> @brief forwarding routine
!> @details find new boundary conditions and best F estimate for end of current timestep
!--------------------------------------------------------------------------------------------------
subroutine grid_mechanical_spectral_basic_forward(cutBack,guess,Delta_t,Delta_t_old,t_remaining,&
                                            deformation_BC,stress_BC,rotation_BC)

  logical,                  intent(in) :: &
    cutBack, &
    guess
  real(pREAL),              intent(in) :: &
    Delta_t_old, &
    Delta_t, &
    t_remaining                                                                                     !< remaining time of current load case
  type(tBoundaryCondition), intent(in) :: &
    stress_BC, &
    deformation_BC
  type(tRotation),           intent(in) :: &
    rotation_BC
  PetscErrorCode :: err_PETSc
  real(pREAL), pointer, dimension(:,:,:,:) :: F


  call DMDAVecGetArrayF90(da,solution_vec,F,err_PETSc)
  CHKERRQ(err_PETSc)

  if (cutBack) then
    C_volAvg    = C_volAvgLastInc
    C_minMaxAvg = C_minMaxAvgLastInc
  else
    C_volAvgLastInc    = C_volAvg
    C_minMaxAvgLastInc = C_minMaxAvg

    F_aimDot = merge(merge(.0_pREAL,(F_aim-F_aim_lastInc)/Delta_t_old,stress_BC%mask),.0_pREAL,guess) ! estimate deformation rate for prescribed stress components
    F_aim_lastInc = F_aim

    !-----------------------------------------------------------------------------------------------
    ! calculate rate for aim
    if     (deformation_BC%myType=='L') then                                                        ! calculate F_aimDot from given L and current F
      F_aimDot = F_aimDot &
               + matmul(merge(.0_pREAL,deformation_BC%values,deformation_BC%mask),F_aim_lastInc)
    elseif (deformation_BC%myType=='dot_F') then                                                    ! F_aimDot is prescribed
      F_aimDot = F_aimDot &
               + merge(.0_pREAL,deformation_BC%values,deformation_BC%mask)
    elseif (deformation_BC%myType=='F') then                                                        ! aim at end of load case is prescribed
      F_aimDot = F_aimDot &
               + merge(.0_pREAL,(deformation_BC%values - F_aim_lastInc)/t_remaining,deformation_BC%mask)
    end if

    Fdot = utilities_calculateRate(guess, &
                                   F_lastInc,reshape(F,[3,3,cells(1),cells(2),cells3]),Delta_t_old, &
                                   rotation_BC%rotate(F_aimDot,active=.true.))
    F_lastInc = reshape(F,[3,3,cells(1),cells(2),cells3])

    homogenization_F0 = reshape(F,[3,3,product(cells(1:2))*cells3])
  end if

!--------------------------------------------------------------------------------------------------
! update average and local deformation gradients
  F_aim = F_aim_lastInc + F_aimDot * Delta_t
  if (stress_BC%myType=='P')     P_aim = P_aim &
                                       + merge(.0_pREAL,(stress_BC%values - P_aim)/t_remaining,stress_BC%mask)*Delta_t
  if (stress_BC%myType=='dot_P') P_aim = P_aim &
                                       + merge(.0_pREAL,stress_BC%values,stress_BC%mask)*Delta_t

  F = reshape(utilities_forwardField(Delta_t,F_lastInc,Fdot, &                                      ! estimate of F at end of time+Delta_t that matches rotated F_aim on average
              rotation_BC%rotate(F_aim,active=.true.)),[9,cells(1),cells(2),cells3])
  call DMDAVecRestoreArrayF90(da,solution_vec,F,err_PETSc)
  CHKERRQ(err_PETSc)

!--------------------------------------------------------------------------------------------------
! set module wide available data
  params%stress_mask = stress_BC%mask
  params%rotation_BC = rotation_BC
  params%Delta_t     = Delta_t

end subroutine grid_mechanical_spectral_basic_forward


!--------------------------------------------------------------------------------------------------
!> @brief Update coordinates
!--------------------------------------------------------------------------------------------------
subroutine grid_mechanical_spectral_basic_updateCoords

  PetscErrorCode :: err_PETSc
  real(pREAL), dimension(:,:,:,:), pointer :: F

  call DMDAVecGetArrayF90(da,solution_vec,F,err_PETSc)
  CHKERRQ(err_PETSc)
  call utilities_updateCoords(F)
  call DMDAVecRestoreArrayF90(da,solution_vec,F,err_PETSc)
  CHKERRQ(err_PETSc)

end subroutine grid_mechanical_spectral_basic_updateCoords


!--------------------------------------------------------------------------------------------------
!> @brief Write current solver and constitutive data for restart to file
!--------------------------------------------------------------------------------------------------
subroutine grid_mechanical_spectral_basic_restartWrite

  PetscErrorCode :: err_PETSc
  integer(HID_T) :: fileHandle, groupHandle
  real(pREAL), dimension(:,:,:,:), pointer :: F

  call DMDAVecGetArrayF90(da,solution_vec,F,err_PETSc)
  CHKERRQ(err_PETSc)

  if (num%update_gamma) C_minMaxAvgRestart = C_minMaxAvg

  print'(1x,a)', 'saving solver data required for restart'; flush(IO_STDOUT)

  fileHandle  = HDF5_openFile(getSolverJobName()//'_restart.hdf5','w')
  groupHandle = HDF5_addGroup(fileHandle,'solver')
  call HDF5_write(reshape(F,[3,3,product(cells(1:2))*cells3]),groupHandle,'F')
  call HDF5_write(reshape(F_lastInc,[3,3,product(cells(1:2))*cells3]),groupHandle,'F_lastInc')
  call HDF5_closeGroup(groupHandle)
  call HDF5_closeFile(fileHandle)

  if (worldrank == 0) then
    fileHandle  = HDF5_openFile(getSolverJobName()//'_restart.hdf5','a',.false.)
    groupHandle = HDF5_openGroup(fileHandle,'solver')
    call HDF5_write(P_aim,groupHandle,'P_aim',.false.)
    call HDF5_write(F_aim,groupHandle,'F_aim',.false.)
    call HDF5_write(F_aim_lastInc,groupHandle,'F_aim_lastInc',.false.)
    call HDF5_write(F_aimDot,groupHandle,'F_aimDot',.false.)
    call HDF5_write(C_volAvg,groupHandle,'C_volAvg',.false.)
    call HDF5_write(C_volAvgLastInc,groupHandle,'C_volAvgLastInc',.false.)
    call HDF5_write(C_minMaxAvgRestart,groupHandle,'C_minMaxAvg',.false.)
    call HDF5_closeGroup(groupHandle)
    call HDF5_closeFile(fileHandle)
  end if

  call DMDAVecRestoreArrayF90(da,solution_vec,F,err_PETSc)
  CHKERRQ(err_PETSc)

end subroutine grid_mechanical_spectral_basic_restartWrite


!--------------------------------------------------------------------------------------------------
!> @brief convergence check
!--------------------------------------------------------------------------------------------------
subroutine converged(snes_local,PETScIter,devNull1,devNull2,devNull3,reason,dummy,err_PETSc)

  SNES :: snes_local
  PetscInt,  intent(in) :: PETScIter
  PetscReal, intent(in) :: &
    devNull1, &
    devNull2, &
    devNull3
  SNESConvergedReason :: reason
  PetscObject :: dummy
  PetscErrorCode :: err_PETSc
  real(pREAL) :: &
    divTol, &
    BCTol

  divTol = max(maxval(abs(P_av))*num%eps_div_rtol, num%eps_div_atol)
  BCTol = max(maxval(abs(P_av))*num%eps_stress_rtol, num%eps_stress_atol)

  if ((totalIter >= num%itmin .and. all([err_div/divTol, err_BC/BCTol] < 1.0_pREAL)) &
       .or. terminallyIll) then
    reason = 1
  elseif (totalIter >= num%itmax) then
    reason = -1
  else
    reason = 0
  end if

  print'(/,1x,a)', '... reporting .............................................................'
  print'(/,1x,a,f12.2,a,es8.2,a,es9.2,a)', 'error divergence = ', &
          err_div/divTol,  ' (',err_div,' / m, tol = ',divTol,')'
  print'(1x,a,f12.2,a,es8.2,a,es9.2,a)',    'error stress BC  = ', &
          err_BC/BCTol,    ' (',err_BC, ' Pa,  tol = ',BCTol,')'
  print'(/,1x,a)', '==========================================================================='
  flush(IO_STDOUT)
  err_PETSc = 0

end subroutine converged


!--------------------------------------------------------------------------------------------------
!> @brief Construct the residual vector.
!--------------------------------------------------------------------------------------------------
subroutine formResidual(residual_subdomain, F, &
                        r, dummy, err_PETSc)

  DMDALocalInfo, dimension(DMDA_LOCAL_INFO_SIZE) :: &
    residual_subdomain                                                                              !< DMDA info (needs to be named "in" for macros like XRANGE to work)
  real(pREAL), dimension(3,3,cells(1),cells(2),cells3), intent(in) :: &
    F                                                                                               !< deformation gradient field
  real(pREAL), dimension(3,3,cells(1),cells(2),cells3), intent(out) :: &
    r                                                                                               !< residuum field
  PetscObject :: dummy
  PetscErrorCode :: err_PETSc

  real(pREAL),  dimension(3,3) :: &
    deltaF_aim
  PetscInt :: &
    PETScIter, &
    nfuncs
  integer(MPI_INTEGER_KIND) :: err_MPI


  call SNESGetNumberFunctionEvals(SNES_mechanical,nfuncs,err_PETSc)
  CHKERRQ(err_PETSc)
  call SNESGetIterationNumber(SNES_mechanical,PETScIter,err_PETSc)
  CHKERRQ(err_PETSc)

  if (nfuncs == 0 .and. PETScIter == 0) totalIter = -1                                              ! new increment

  newIteration: if (totalIter <= PETScIter) then
    totalIter = totalIter + 1
    print'(1x,a,3(a,i0))', trim(incInfo), ' @ Iteration ', num%itmin, '≤',totalIter, '≤', num%itmax
    if (any(dNeq(params%rotation_BC%asQuaternion(), real([1.0, 0.0, 0.0, 0.0],pREAL)))) &
      print'(/,1x,a,/,2(3(f12.7,1x)/),3(f12.7,1x))', &
      'deformation gradient aim (lab) =', transpose(params%rotation_BC%rotate(F_aim,active=.true.))
    print'(/,1x,a,/,2(3(f12.7,1x)/),3(f12.7,1x))', &
      'deformation gradient aim       =', transpose(F_aim)
    flush(IO_STDOUT)
  end if newIteration

  associate (P => r)
    call utilities_constitutiveResponse(P, &
                                        P_av,C_volAvg,C_minMaxAvg, &
                                        F,params%Delta_t,params%rotation_BC)
    call MPI_Allreduce(MPI_IN_PLACE,terminallyIll,1_MPI_INTEGER_KIND,MPI_LOGICAL,MPI_LOR,MPI_COMM_WORLD,err_MPI)
    if (err_MPI /= 0_MPI_INTEGER_KIND) error stop 'MPI error'
    err_div = utilities_divergenceRMS(P)
  end associate

  deltaF_aim = math_mul3333xx33(S, P_av - P_aim)                                                    ! S = 0.0 for no bc
  F_aim = F_aim - deltaF_aim
  err_BC = maxval(abs(merge(.0_pREAL,P_av - P_aim,params%stress_mask)))

  r = utilities_GammaConvolution(r,params%rotation_BC%rotate(deltaF_aim,active=.true.))

end subroutine formResidual


end module grid_mechanical_spectral_basic
