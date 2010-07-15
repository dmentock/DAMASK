!* $Id: constitutive_titanmod.f90 519 2010-03-24 08:17:27Z MPIE\f.roters $
!************************************
!*      Module: CONSTITUTIVE        *
!************************************

MODULE constitutive_titanmod

!* Include other modules
use prec, only: pReal,pInt
implicit none

!* Lists of states and physical parameters
character(len=*), parameter :: constitutive_titanmod_label = 'titanmod'
character(len=18), dimension(2), parameter:: constitutive_titanmod_listBasicSlipStates = (/'rho_edge   ', &
                                                                                            'rho_screw'/)
character(len=18), dimension(1), parameter:: constitutive_titanmod_listBasicTwinStates = (/'twinFraction'/)                                                                                            
character(len=18), dimension(5), parameter:: constitutive_titanmod_listDependentSlipStates =(/'invLambdaSlipe', &
																							   'invLambdaSlips', &
																							   'etauSlipThreshold', &
                                                                                               'stauSlipThreshold', &
                                                                                               'invLambdaSlipTwin'/)

character(len=18), dimension(4), parameter:: constitutive_titanmod_listDependentTwinStates =(/'invLambdaTwin   ', &
                                                                                               'meanFreePathTwin', &                                                
                                                                                               'tauTwinThreshold', &
                                                                                               'twinVolume      '/)
real(pReal), parameter :: kB = 1.38e-23_pReal ! Boltzmann constant in J/Kelvin

!* Definition of global variables
integer(pInt), dimension(:), allocatable ::               constitutive_titanmod_sizeDotState, &                ! number of dotStates
                                                          constitutive_titanmod_sizeState, &                   ! total number of microstructural state variables
                                                          constitutive_titanmod_sizePostResults                ! cumulative size of post results
integer(pInt), dimension(:,:), allocatable, target ::     constitutive_titanmod_sizePostResult                 ! size of each post result output
character(len=64), dimension(:,:), allocatable, target :: constitutive_titanmod_output                         ! name of each post result output 
character(len=32), dimension(:), allocatable ::           constitutive_titanmod_structureName                  ! name of the lattice structure
integer(pInt), dimension(:), allocatable ::               constitutive_titanmod_structure, &                   ! number representing the kind of lattice structure
                                                          constitutive_titanmod_totalNslip, &                  ! total number of active slip systems for each instance
                                                          constitutive_titanmod_totalNtwin                     ! total number of active twin systems for each instance
integer(pInt), dimension(:,:), allocatable ::             constitutive_titanmod_Nslip, &                       ! number of active slip systems for each family and instance
                                                          constitutive_titanmod_Ntwin, &                       ! number of active twin systems for each family and instance
                                                          constitutive_titanmod_slipFamily, &                  ! lookup table relating active slip system to slip family for each instance
                                                          constitutive_titanmod_twinFamily, &                  ! lookup table relating active twin system to twin family for each instance
                                                          constitutive_titanmod_slipSystemLattice, &           ! lookup table relating active slip system index to lattice slip system index for each instance
                                                          constitutive_titanmod_twinSystemLattice              ! lookup table relating active twin system index to lattice twin system index for each instance
real(pReal), dimension(:), allocatable ::                 constitutive_titanmod_CoverA, &                      ! c/a ratio for hex type lattice
                                                          constitutive_titanmod_C11, &                         ! C11 element in elasticity matrix
                                                          constitutive_titanmod_C12, &                         ! C12 element in elasticity matrix
                                                          constitutive_titanmod_C13, &                         ! C13 element in elasticity matrix
                                                          constitutive_titanmod_C33, &                         ! C33 element in elasticity matrix
                                                          constitutive_titanmod_C44, &                         ! C44 element in elasticity matrix
                                                          constitutive_titanmod_Gmod, &                        ! shear modulus
                                                          constitutive_titanmod_CAtomicVolume, &               ! atomic volume in Bugers vector unit
                                                          constitutive_titanmod_D0, &                          ! prefactor for self-diffusion coefficient
                                                          constitutive_titanmod_Qsd, &                         ! activation energy for dislocation climb
                                                          constitutive_titanmod_GrainSize, &                   ! grain size - Not being used
                                                          constitutive_titanmod_MaxTwinFraction, &             ! maximum allowed total twin volume fraction
                                                          constitutive_titanmod_r, &                           ! r-exponent in twin nucleation rate
                                                          constitutive_titanmod_CEdgeDipMinDistance, &         ! Not being used
                                                          constitutive_titanmod_Cmfptwin, &                    ! Not being used
                                                          constitutive_titanmod_Cthresholdtwin, &              ! Not being used
                                                          constitutive_titanmod_relevantRho                    ! dislocation density considered relevant												  
real(pReal),       dimension(:,:,:),       allocatable :: constitutive_titanmod_Cslip_66                       ! elasticity matrix in Mandel notation for each instance
real(pReal),       dimension(:,:,:,:),     allocatable :: constitutive_titanmod_Ctwin_66                       ! twin elasticity matrix in Mandel notation for each instance
real(pReal),       dimension(:,:,:,:,:),   allocatable :: constitutive_titanmod_Cslip_3333                     ! elasticity matrix for each instance
real(pReal),       dimension(:,:,:,:,:,:), allocatable :: constitutive_titanmod_Ctwin_3333                     ! twin elasticity matrix for each instance
real(pReal), dimension(:,:), allocatable ::               constitutive_titanmod_rho_edge0, &                   ! initial edge dislocation density per slip system for each family and instance
                                                          constitutive_titanmod_rho_screw0, &                  ! initial screw dislocation density per slip system for each family and instance
                                                          constitutive_titanmod_burgersPerSlipFamily, &        ! absolute length of burgers vector [m] for each slip family and instance
                                                          constitutive_titanmod_burgersPerSlipSystem, &        ! absolute length of burgers vector [m] for each slip system and instance
                                                          constitutive_titanmod_burgersPerTwinFamily, &        ! absolute length of burgers vector [m] for each twin family and instance
                                                          constitutive_titanmod_burgersPerTwinSystem, &        ! absolute length of burgers vector [m] for each twin system and instance
                                                          constitutive_titanmod_f0_PerSlipFamily, &            ! activation energy for glide [J] for each slip family and instance
                                                          constitutive_titanmod_f0_PerSlipSystem, &            ! activation energy for glide [J] for each slip system and instance
                                                          constitutive_titanmod_tau0e_PerSlipFamily, &         ! Initial yield stress edge dislocations per slip family
                                                          constitutive_titanmod_tau0e_PerSlipSystem, &         ! Initial yield stress edge dislocations per slip system
                                                          constitutive_titanmod_tau0s_PerSlipFamily, &         ! Initial yield stress screw dislocations per slip family
                                                          constitutive_titanmod_tau0s_PerSlipSystem, &         ! Initial yield stress screw dislocations per slip system
                                                          constitutive_titanmod_capre_PerSlipFamily, &         ! Capture radii for edge dislocations per slip family
                                                          constitutive_titanmod_capre_PerSlipSystem, &         ! Capture radii for edge dislocations per slip system
                                                          constitutive_titanmod_caprs_PerSlipFamily, &         ! Capture radii for screw dislocations per slip family
                                                          constitutive_titanmod_caprs_PerSlipSystem, &         ! Capture radii for screw dislocations per slip system
                                                          constitutive_titanmod_pe_PerSlipFamily, &            ! p-exponent in glide velocity
                                                          constitutive_titanmod_ps_PerSlipFamily, &            ! p-exponent in glide velocity
                                                          constitutive_titanmod_qe_PerSlipFamily, &            ! q-exponent in glide velocity
                                                          constitutive_titanmod_qs_PerSlipFamily, &            ! q-exponent in glide velocity
                                                          constitutive_titanmod_pe_PerSlipSystem, &            ! p-exponent in glide velocity
                                                          constitutive_titanmod_ps_PerSlipSystem, &            ! p-exponent in glide velocity
                                                          constitutive_titanmod_qe_PerSlipSystem, &            ! q-exponent in glide velocity
                                                          constitutive_titanmod_qs_PerSlipSystem, &            ! q-exponent in glide velocity
                                                          constitutive_titanmod_v0e_PerSlipFamily, &           ! dislocation velocity prefactor [m/s] for each family and instance
                                                          constitutive_titanmod_v0e_PerSlipSystem, &           ! dislocation velocity prefactor [m/s] for each slip system and instance
                                                          constitutive_titanmod_v0s_PerSlipFamily, &           ! dislocation velocity prefactor [m/s] for each family and instance
                                                          constitutive_titanmod_v0s_PerSlipSystem, &           ! dislocation velocity prefactor [m/s] for each slip system and instance
                                                          constitutive_titanmod_Ndot0PerTwinFamily, &          ! twin nucleation rate [1/m³s] for each twin family and instance
                                                          constitutive_titanmod_Ndot0PerTwinSystem, &          ! twin nucleation rate [1/m³s] for each twin system and instance
                                                          constitutive_titanmod_twinsizePerTwinFamily, &       ! twin thickness [m] for each twin family and instance
                                                          constitutive_titanmod_twinsizePerTwinSystem, &       ! twin thickness [m] for each twin system and instance
                                                          constitutive_titanmod_CeLambdaSlipPerSlipFamily, &   ! Adj. parameter for distance between 2 forest dislocations for each slip family and instance
                                                          constitutive_titanmod_CeLambdaSlipPerSlipSystem, &   ! Adj. parameter for distance between 2 forest dislocations for each slip system and instance
                                                          constitutive_titanmod_CsLambdaSlipPerSlipFamily, &   ! Adj. parameter for distance between 2 forest dislocations for each slip family and instance
                                                          constitutive_titanmod_CsLambdaSlipPerSlipSystem, &   ! Adj. parameter for distance between 2 forest dislocations for each slip system and instance
                                                          constitutive_titanmod_interactionSlipSlip, &         ! coefficients for slip-slip interaction for each interaction type and instance
                                                          constitutive_titanmod_interactionSlipTwin, &         ! coefficients for slip-twin interaction for each interaction type and instance
                                                          constitutive_titanmod_interactionTwinSlip, &         ! coefficients for twin-slip interaction for each interaction type and instance
                                                          constitutive_titanmod_interactionTwinTwin            ! coefficients for twin-twin interaction for each interaction type and instance
real(pReal),       dimension(:,:,:),       allocatable :: constitutive_titanmod_interactionMatrixSlipSlip, &   ! interaction matrix of the different slip systems for each instance
                                                          constitutive_titanmod_interactionMatrixSlipTwin, &   ! interaction matrix of slip systems with twin systems for each instance
                                                          constitutive_titanmod_interactionMatrixTwinSlip, &   ! interaction matrix of twin systems with slip systems for each instance
                                                          constitutive_titanmod_interactionMatrixTwinTwin, &   ! interaction matrix of the different twin systems for each instance                                                          
                                                          constitutive_titanmod_forestProjectionEdge           ! matrix of forest projections of edge dislocations for each instance  
CONTAINS
!****************************************
!* - constitutive_titanmod_init
!* - constitutive_titanmod_stateInit
!* - constitutive_titanmod_relevantState
!* - constitutive_titanmod_homogenizedC
!* - constitutive_titanmod_microstructure
!* - constitutive_titanmod_LpAndItsTangent
!* - consistutive_titanmod_dotState
!* - constitutive_titanmod_dotTemperature
!* - consistutive_titanmod_postResults
!****************************************

subroutine constitutive_titanmod_init(file)
!**************************************
!*      Module initialization         *
!**************************************
use prec,    only: pInt,pReal
use math,    only: math_Mandel3333to66,math_Voigt66to3333,math_mul3x3
use IO
use material
use lattice

!* Input variables
integer(pInt), intent(in) :: file
!* Local variables
integer(pInt), parameter :: maxNchunks = 21
integer(pInt), dimension(1+2*maxNchunks) :: positions
integer(pInt) section,maxNinstance,f,i,j,k,l,m,n,o,p,q,r,s,s1,s2,t1,t2,ns,nt,output,mySize,myStructure,maxTotalNslip,maxTotalNtwin
character(len=64) tag
character(len=1024) line

!write(6,*)
!write(6,'(a20,a20,a12)') '<<<+-  constitutive_',constitutive_titanmod_label,' init  -+>>>'
!write(6,*) '$Id: constitutive_titanmod.f90 519 2010-03-24 08:17:27Z MPIE\f.roters $'
!write(6,*)

maxNinstance = count(phase_constitution == constitutive_titanmod_label)
if (maxNinstance == 0) return

!* Space allocation for global variables
allocate(constitutive_titanmod_sizeDotState(maxNinstance))       
allocate(constitutive_titanmod_sizeState(maxNinstance)) 
allocate(constitutive_titanmod_sizePostResults(maxNinstance)) 
allocate(constitutive_titanmod_sizePostResult(maxval(phase_Noutput),maxNinstance))
allocate(constitutive_titanmod_output(maxval(phase_Noutput),maxNinstance))
constitutive_titanmod_sizeDotState    = 0_pInt
constitutive_titanmod_sizeState       = 0_pInt
constitutive_titanmod_sizePostResults = 0_pInt
constitutive_titanmod_sizePostResult  = 0_pInt
constitutive_titanmod_output          = ''

allocate(constitutive_titanmod_structureName(maxNinstance)) 
allocate(constitutive_titanmod_structure(maxNinstance))
allocate(constitutive_titanmod_Nslip(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_Ntwin(lattice_maxNtwinFamily,maxNinstance))  
allocate(constitutive_titanmod_slipFamily(lattice_maxNslip,maxNinstance))
allocate(constitutive_titanmod_twinFamily(lattice_maxNtwin,maxNinstance))
allocate(constitutive_titanmod_slipSystemLattice(lattice_maxNslip,maxNinstance))
allocate(constitutive_titanmod_twinSystemLattice(lattice_maxNtwin,maxNinstance)) 
allocate(constitutive_titanmod_totalNslip(maxNinstance))   
allocate(constitutive_titanmod_totalNtwin(maxNinstance))   
constitutive_titanmod_structureName     = ''
constitutive_titanmod_structure         = 0_pInt
constitutive_titanmod_Nslip             = 0_pInt
constitutive_titanmod_Ntwin             = 0_pInt
constitutive_titanmod_slipFamily        = 0_pInt
constitutive_titanmod_twinFamily        = 0_pInt
constitutive_titanmod_slipSystemLattice = 0.0_pReal
constitutive_titanmod_twinSystemLattice = 0.0_pReal
constitutive_titanmod_totalNslip        = 0_pInt
constitutive_titanmod_totalNtwin        = 0_pInt
allocate(constitutive_titanmod_CoverA(maxNinstance))
allocate(constitutive_titanmod_C11(maxNinstance))
allocate(constitutive_titanmod_C12(maxNinstance))
allocate(constitutive_titanmod_C13(maxNinstance))
allocate(constitutive_titanmod_C33(maxNinstance))
allocate(constitutive_titanmod_C44(maxNinstance))
allocate(constitutive_titanmod_Gmod(maxNinstance))
allocate(constitutive_titanmod_CAtomicVolume(maxNinstance))
allocate(constitutive_titanmod_D0(maxNinstance))
allocate(constitutive_titanmod_Qsd(maxNinstance))
allocate(constitutive_titanmod_GrainSize(maxNinstance))
allocate(constitutive_titanmod_MaxTwinFraction(maxNinstance))
allocate(constitutive_titanmod_r(maxNinstance))
allocate(constitutive_titanmod_CEdgeDipMinDistance(maxNinstance))
allocate(constitutive_titanmod_Cmfptwin(maxNinstance))
allocate(constitutive_titanmod_Cthresholdtwin(maxNinstance))
allocate(constitutive_titanmod_relevantRho(maxNinstance))
allocate(constitutive_titanmod_Cslip_66(6,6,maxNinstance))
allocate(constitutive_titanmod_Cslip_3333(3,3,3,3,maxNinstance))
constitutive_titanmod_CoverA              = 0.0_pReal 
constitutive_titanmod_C11                 = 0.0_pReal
constitutive_titanmod_C12                 = 0.0_pReal
constitutive_titanmod_C13                 = 0.0_pReal
constitutive_titanmod_C33                 = 0.0_pReal
constitutive_titanmod_C44                 = 0.0_pReal
constitutive_titanmod_Gmod                = 0.0_pReal
constitutive_titanmod_CAtomicVolume       = 0.0_pReal
constitutive_titanmod_D0                  = 0.0_pReal
constitutive_titanmod_Qsd                 = 0.0_pReal
constitutive_titanmod_GrainSize           = 0.0_pReal
constitutive_titanmod_MaxTwinFraction     = 0.0_pReal
constitutive_titanmod_r                   = 0.0_pReal
constitutive_titanmod_CEdgeDipMinDistance = 0.0_pReal
constitutive_titanmod_Cmfptwin            = 0.0_pReal
constitutive_titanmod_Cthresholdtwin      = 0.0_pReal
constitutive_titanmod_relevantRho         = 0.0_pReal
constitutive_titanmod_Cslip_66            = 0.0_pReal
constitutive_titanmod_Cslip_3333          = 0.0_pReal
allocate(constitutive_titanmod_rho_edge0(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_rho_screw0(lattice_maxNslipFamily,maxNinstance)) 
allocate(constitutive_titanmod_burgersPerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_burgersPerTwinFamily(lattice_maxNtwinFamily,maxNinstance))
allocate(constitutive_titanmod_f0_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_tau0e_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_tau0s_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_capre_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_caprs_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_pe_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_ps_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_qe_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_qs_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_v0e_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_v0s_PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_Ndot0PerTwinFamily(lattice_maxNtwinFamily,maxNinstance))
allocate(constitutive_titanmod_twinsizePerTwinFamily(lattice_maxNtwinFamily,maxNinstance))
allocate(constitutive_titanmod_CeLambdaSlipPerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_titanmod_CsLambdaSlipPerSlipFamily(lattice_maxNslipFamily,maxNinstance))
constitutive_titanmod_rho_edge0                 = 0.0_pReal
constitutive_titanmod_rho_screw0              = 0.0_pReal
constitutive_titanmod_burgersPerSlipFamily     = 0.0_pReal
constitutive_titanmod_burgersPerTwinFamily     = 0.0_pReal
constitutive_titanmod_f0_PerSlipFamily       = 0.0_pReal
constitutive_titanmod_tau0e_PerSlipFamily       = 0.0_pReal
constitutive_titanmod_tau0s_PerSlipFamily       = 0.0_pReal
constitutive_titanmod_capre_PerSlipFamily       = 0.0_pReal
constitutive_titanmod_caprs_PerSlipFamily       = 0.0_pReal
constitutive_titanmod_v0e_PerSlipFamily          = 0.0_pReal
constitutive_titanmod_v0s_PerSlipFamily          = 0.0_pReal
constitutive_titanmod_Ndot0PerTwinFamily       = 0.0_pReal
constitutive_titanmod_twinsizePerTwinFamily    = 0.0_pReal
constitutive_titanmod_CeLambdaSlipPerSlipFamily = 0.0_pReal
constitutive_titanmod_CsLambdaSlipPerSlipFamily = 0.0_pReal
constitutive_titanmod_pe_PerSlipFamily = 0.0_pReal
constitutive_titanmod_ps_PerSlipFamily = 0.0_pReal
constitutive_titanmod_qe_PerSlipFamily = 0.0_pReal
constitutive_titanmod_qs_PerSlipFamily = 0.0_pReal
allocate(constitutive_titanmod_interactionSlipSlip(lattice_maxNinteraction,maxNinstance)) 
allocate(constitutive_titanmod_interactionSlipTwin(lattice_maxNinteraction,maxNinstance)) 
allocate(constitutive_titanmod_interactionTwinSlip(lattice_maxNinteraction,maxNinstance)) 
allocate(constitutive_titanmod_interactionTwinTwin(lattice_maxNinteraction,maxNinstance)) 
constitutive_titanmod_interactionSlipSlip = 0.0_pReal
constitutive_titanmod_interactionSlipTwin = 0.0_pReal
constitutive_titanmod_interactionTwinSlip = 0.0_pReal
constitutive_titanmod_interactionTwinTwin = 0.0_pReal

!* Readout data from material.config file
rewind(file)
line = ''
section = 0

write(6,*) 'Reading material parameters from material config file'

do while (IO_lc(IO_getTag(line,'<','>')) /= 'phase')     ! wind forward to <phase>
   read(file,'(a1024)',END=100) line
enddo

do                                                       ! read thru sections of phase part
   read(file,'(a1024)',END=100) line
   if (IO_isBlank(line)) cycle                            ! skip empty lines
   if (IO_getTag(line,'<','>') /= '') exit                ! stop at next part
   if (IO_getTag(line,'[',']') /= '') then                ! next section
     section = section + 1
     output = 0                                           ! reset output counter
   endif
   if (section > 0 .and. phase_constitution(section) == constitutive_titanmod_label) then  ! one of my sections
     i = phase_constitutionInstance(section)     ! which instance of my constitution is present phase
     positions = IO_stringPos(line,maxNchunks)
     tag = IO_lc(IO_stringValue(line,positions,1))        ! extract key
     select case(tag)
       case ('(output)')
         output = output + 1
         constitutive_titanmod_output(output,i) = IO_lc(IO_stringValue(line,positions,2))
		write(6,*) tag
		 case ('lattice_structure')
              constitutive_titanmod_structureName(i) = IO_lc(IO_stringValue(line,positions,2))
		write(6,*) tag
       case ('covera_ratio')
              constitutive_titanmod_CoverA(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('c11')
              constitutive_titanmod_C11(i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_C11(i)
       case ('c12')
              constitutive_titanmod_C12(i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_C12(i)
       case ('c13')
              constitutive_titanmod_C13(i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_C13(i)
       case ('c33')
              constitutive_titanmod_C33(i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_C33(i)
       case ('c44')
              constitutive_titanmod_C44(i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_C44(i)
       case ('nslip')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_Nslip(j,i) = IO_intValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_Nslip(1,i),constitutive_titanmod_Nslip(2,i),constitutive_titanmod_Nslip(3,i), &
			constitutive_titanmod_Nslip(4,i)
       case ('ntwin')
              forall (j = 1:lattice_maxNtwinFamily) &
                constitutive_titanmod_Ntwin(j,i) = IO_intValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_Ntwin(1,i),constitutive_titanmod_Ntwin(2,i),constitutive_titanmod_Ntwin(3,i), &
			constitutive_titanmod_Ntwin(4,i)
       case ('rho_edge0')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_rho_edge0(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_rho_edge0(1,i),constitutive_titanmod_rho_edge0(2,i), &
			constitutive_titanmod_rho_edge0(3,i), constitutive_titanmod_rho_edge0(4,i)
       case ('rho_screw0')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_rho_screw0(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_rho_screw0(1,i),constitutive_titanmod_rho_screw0(2,i), &
			constitutive_titanmod_rho_screw0(3,i), constitutive_titanmod_rho_screw0(4,i)
       case ('slipburgers')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_burgersPerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_burgersPerSlipFamily(1,i),constitutive_titanmod_burgersPerSlipFamily(2,i), &
			constitutive_titanmod_burgersPerSlipFamily(3,i), constitutive_titanmod_burgersPerSlipFamily(4,i)
       case ('twinburgers')
              forall (j = 1:lattice_maxNtwinFamily) &
                constitutive_titanmod_burgersPerTwinFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
       case ('f0')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_f0_PerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_f0_PerSlipFamily(1,i),constitutive_titanmod_f0_PerSlipFamily(2,i), &
			constitutive_titanmod_f0_PerSlipFamily(3,i), constitutive_titanmod_f0_PerSlipFamily(4,i)
       case ('tau0e')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_tau0e_PerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_tau0e_PerSlipFamily(1,i),constitutive_titanmod_tau0e_PerSlipFamily(2,i), &
			constitutive_titanmod_tau0e_PerSlipFamily(3,i), constitutive_titanmod_tau0e_PerSlipFamily(4,i)
       case ('tau0s')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_tau0s_PerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_tau0s_PerSlipFamily(1,i),constitutive_titanmod_tau0s_PerSlipFamily(2,i), &
			constitutive_titanmod_tau0s_PerSlipFamily(3,i), constitutive_titanmod_tau0s_PerSlipFamily(4,i)
       case ('capre')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_capre_PerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_capre_PerSlipFamily(1,i),constitutive_titanmod_capre_PerSlipFamily(2,i), &
			constitutive_titanmod_capre_PerSlipFamily(3,i), constitutive_titanmod_capre_PerSlipFamily(4,i)
       case ('caprs')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_caprs_PerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_caprs_PerSlipFamily(1,i),constitutive_titanmod_caprs_PerSlipFamily(2,i), &
			constitutive_titanmod_caprs_PerSlipFamily(3,i), constitutive_titanmod_caprs_PerSlipFamily(4,i)
       case ('v0e')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_v0e_PerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_v0e_PerSlipFamily(1,i),constitutive_titanmod_v0e_PerSlipFamily(2,i), &
			constitutive_titanmod_v0e_PerSlipFamily(3,i), constitutive_titanmod_v0e_PerSlipFamily(4,i)
       case ('v0s')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_v0s_PerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag,constitutive_titanmod_v0s_PerSlipFamily(1,i),constitutive_titanmod_v0s_PerSlipFamily(2,i), &
			constitutive_titanmod_v0s_PerSlipFamily(3,i), constitutive_titanmod_v0s_PerSlipFamily(4,i)
       case ('ndot0')
              forall (j = 1:lattice_maxNtwinFamily) &
                constitutive_titanmod_Ndot0PerTwinFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
       case ('twinsize')
              forall (j = 1:lattice_maxNtwinFamily) &
                constitutive_titanmod_twinsizePerTwinFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
       case ('celambdaslip')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_CeLambdaSlipPerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
       case ('cslambdaslip')
              forall (j = 1:lattice_maxNslipFamily) &
                constitutive_titanmod_CsLambdaSlipPerSlipFamily(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
       case ('grainsize')
              constitutive_titanmod_GrainSize(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('maxtwinfraction')
              constitutive_titanmod_MaxTwinFraction(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('pe')
			  forall (j = 1:lattice_maxNslipFamily) &
				constitutive_titanmod_pe_PerSlipFamily(j,i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_pe_PerSlipFamily(1,i),constitutive_titanmod_pe_PerSlipFamily(2,i), &
			constitutive_titanmod_pe_PerSlipFamily(3,i), constitutive_titanmod_pe_PerSlipFamily(4,i),i
       case ('ps')
			  forall (j = 1:lattice_maxNslipFamily) &
				constitutive_titanmod_ps_PerSlipFamily(j,i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_ps_PerSlipFamily(1,i),constitutive_titanmod_ps_PerSlipFamily(2,i), &
			constitutive_titanmod_ps_PerSlipFamily(3,i), constitutive_titanmod_ps_PerSlipFamily(4,i),i
       case ('qe')
			  forall (j = 1:lattice_maxNslipFamily) &
				constitutive_titanmod_qe_PerSlipFamily(j,i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_qe_PerSlipFamily(1,i),constitutive_titanmod_qe_PerSlipFamily(2,i), &
			constitutive_titanmod_qe_PerSlipFamily(3,i), constitutive_titanmod_qe_PerSlipFamily(4,i),i
       case ('qs')
			  forall (j = 1:lattice_maxNslipFamily) &
				constitutive_titanmod_qs_PerSlipFamily(j,i) = IO_floatValue(line,positions,2)
		write(6,*) tag,constitutive_titanmod_qs_PerSlipFamily(1,i),constitutive_titanmod_qs_PerSlipFamily(2,i), &
			constitutive_titanmod_qs_PerSlipFamily(3,i), constitutive_titanmod_qs_PerSlipFamily(4,i),i
       case ('rexponent')
              constitutive_titanmod_r(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('d0')
              constitutive_titanmod_D0(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('qsd')
              constitutive_titanmod_Qsd(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('relevantrho')
              constitutive_titanmod_relevantRho(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('cmfptwin') 
              constitutive_titanmod_Cmfptwin(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('cthresholdtwin') 
              constitutive_titanmod_Cthresholdtwin(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('cedgedipmindistance') 
              constitutive_titanmod_CEdgeDipMinDistance(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('catomicvolume') 
              constitutive_titanmod_CAtomicVolume(i) = IO_floatValue(line,positions,2)
		write(6,*) tag
       case ('interactionslipslip')
              forall (j = 1:lattice_maxNinteraction) &
                constitutive_titanmod_interactionSlipSlip(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
       case ('interactionsliptwin')
              forall (j = 1:lattice_maxNinteraction) &
                constitutive_titanmod_interactionSlipTwin(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
       case ('interactiontwinslip')
              forall (j = 1:lattice_maxNinteraction) &
                constitutive_titanmod_interactionTwinSlip(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
       case ('interactiontwintwin')
              forall (j = 1:lattice_maxNinteraction) &
                constitutive_titanmod_interactionTwinTwin(j,i) = IO_floatValue(line,positions,1+j)
		write(6,*) tag
     end select
   endif
enddo

write(6,*) 'Material Property reading done'
 
100 do i = 1,maxNinstance
   constitutive_titanmod_structure(i) = &
   lattice_initializeStructure(constitutive_titanmod_structureName(i),constitutive_titanmod_CoverA(i))
   myStructure = constitutive_titanmod_structure(i)

   !* Sanity checks
   if (myStructure < 1 .or. myStructure > 3)                                call IO_error(205)
   if (sum(constitutive_titanmod_Nslip(:,i)) <= 0_pInt)                    call IO_error(225)
   if (sum(constitutive_titanmod_Ntwin(:,i)) < 0_pInt)                     call IO_error(225) !***
   do f = 1,lattice_maxNslipFamily
     if (constitutive_titanmod_Nslip(f,i) > 0_pInt) then   
       if (constitutive_titanmod_rho_edge0(f,i) < 0.0_pReal)                 call IO_error(220)
       if (constitutive_titanmod_rho_screw0(f,i) < 0.0_pReal)              call IO_error(220)
       if (constitutive_titanmod_burgersPerSlipFamily(f,i) <= 0.0_pReal)    call IO_error(221)
       if (constitutive_titanmod_f0_PerSlipFamily(f,i) <= 0.0_pReal)         call IO_error(228)
       if (constitutive_titanmod_tau0e_PerSlipFamily(f,i) <= 0.0_pReal)         call IO_error(229)
       if (constitutive_titanmod_tau0s_PerSlipFamily(f,i) <= 0.0_pReal)         call IO_error(233)
       if (constitutive_titanmod_capre_PerSlipFamily(f,i) <= 0.0_pReal)         call IO_error(234)
       if (constitutive_titanmod_caprs_PerSlipFamily(f,i) <= 0.0_pReal)         call IO_error(235)
       if (constitutive_titanmod_v0e_PerSlipFamily(f,i) <= 0.0_pReal)         call IO_error(226)
       if (constitutive_titanmod_v0s_PerSlipFamily(f,i) <= 0.0_pReal)         call IO_error(227)
     endif
   enddo
   do f = 1,lattice_maxNtwinFamily
     if (constitutive_titanmod_Nslip(f,i) > 0_pInt) then   
       if (constitutive_titanmod_burgersPerTwinFamily(f,i) <= 0.0_pReal)    call IO_error(221) !***
       if (constitutive_titanmod_Ndot0PerTwinFamily(f,i) < 0.0_pReal)       call IO_error(226) !***
     endif
   enddo
!   if (any(constitutive_titanmod_interactionSlipSlip(1:maxval(lattice_interactionSlipSlip(:,:,myStructure)),i) < 1.0_pReal)) call IO_error(229)
   if (constitutive_titanmod_CAtomicVolume(i) <= 0.0_pReal)                 call IO_error(230)
   if (constitutive_titanmod_D0(i) <= 0.0_pReal)                            call IO_error(231)
   if (constitutive_titanmod_Qsd(i) <= 0.0_pReal)                           call IO_error(232)
   if (constitutive_titanmod_relevantRho(i) <= 0.0_pReal)                   call IO_error(233)
   
   !* Determine total number of active slip or twin systems
   constitutive_titanmod_Nslip(:,i) = min(lattice_NslipSystem(:,myStructure),constitutive_titanmod_Nslip(:,i))
   constitutive_titanmod_Ntwin(:,i) = min(lattice_NtwinSystem(:,myStructure),constitutive_titanmod_Ntwin(:,i))
   constitutive_titanmod_totalNslip(i) = sum(constitutive_titanmod_Nslip(:,i))
   constitutive_titanmod_totalNtwin(i) = sum(constitutive_titanmod_Ntwin(:,i))
  write(6,*) 'Sanity Checks done !'
enddo   
   
!* Allocation of variables whose size depends on the total number of active slip systems
maxTotalNslip = maxval(constitutive_titanmod_totalNslip)
maxTotalNtwin = maxval(constitutive_titanmod_totalNtwin)      
write(6,*) 'maxTotalNslip',maxTotalNslip
write(6,*) 'maxTotalNtwin',maxTotalNtwin
allocate(constitutive_titanmod_burgersPerSlipSystem(maxTotalNslip, maxNinstance))
allocate(constitutive_titanmod_burgersPerTwinSystem(maxTotalNtwin, maxNinstance))

allocate(constitutive_titanmod_f0_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_tau0e_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_tau0s_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_capre_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_caprs_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_pe_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_ps_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_qe_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_qs_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_v0e_PerSlipSystem(maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_v0s_PerSlipSystem(maxTotalNslip,maxNinstance))

allocate(constitutive_titanmod_Ndot0PerTwinSystem(maxTotalNtwin, maxNinstance))
allocate(constitutive_titanmod_twinsizePerTwinSystem(maxTotalNtwin, maxNinstance))
allocate(constitutive_titanmod_CeLambdaSlipPerSlipSystem(maxTotalNslip, maxNinstance))
allocate(constitutive_titanmod_CsLambdaSlipPerSlipSystem(maxTotalNslip, maxNinstance))
constitutive_titanmod_burgersPerSlipSystem     = 0.0_pReal
constitutive_titanmod_burgersPerTwinSystem     = 0.0_pReal
constitutive_titanmod_f0_PerSlipSystem       = 0.0_pReal
constitutive_titanmod_tau0e_PerSlipSystem       = 0.0_pReal
constitutive_titanmod_tau0s_PerSlipSystem       = 0.0_pReal
constitutive_titanmod_capre_PerSlipSystem       = 0.0_pReal
constitutive_titanmod_caprs_PerSlipSystem       = 0.0_pReal
constitutive_titanmod_v0e_PerSlipSystem          = 0.0_pReal
constitutive_titanmod_v0s_PerSlipSystem          = 0.0_pReal
constitutive_titanmod_pe_PerSlipSystem	= 0.0_pReal
constitutive_titanmod_ps_PerSlipSystem	= 0.0_pReal
constitutive_titanmod_qe_PerSlipSystem	= 0.0_pReal
constitutive_titanmod_qs_PerSlipSystem	= 0.0_pReal

constitutive_titanmod_Ndot0PerTwinSystem       = 0.0_pReal
constitutive_titanmod_twinsizePerTwinSystem    = 0.0_pReal
constitutive_titanmod_CeLambdaSlipPerSlipSystem = 0.0_pReal
constitutive_titanmod_CsLambdaSlipPerSlipSystem = 0.0_pReal

allocate(constitutive_titanmod_interactionMatrixSlipSlip(maxTotalNslip,maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_interactionMatrixSlipTwin(maxTotalNslip,maxTotalNtwin,maxNinstance))
allocate(constitutive_titanmod_interactionMatrixTwinSlip(maxTotalNtwin,maxTotalNslip,maxNinstance))
allocate(constitutive_titanmod_interactionMatrixTwinTwin(maxTotalNtwin,maxTotalNtwin,maxNinstance))
allocate(constitutive_titanmod_forestProjectionEdge(maxTotalNslip,maxTotalNslip,maxNinstance))
constitutive_titanmod_interactionMatrixSlipSlip = 0.0_pReal
constitutive_titanmod_interactionMatrixSlipTwin = 0.0_pReal
constitutive_titanmod_interactionMatrixTwinSlip = 0.0_pReal
constitutive_titanmod_interactionMatrixTwinTwin = 0.0_pReal
constitutive_titanmod_forestProjectionEdge      = 0.0_pReal

allocate(constitutive_titanmod_Ctwin_66(6,6,maxTotalNtwin,maxNinstance))
allocate(constitutive_titanmod_Ctwin_3333(3,3,3,3,maxTotalNtwin,maxNinstance))
constitutive_titanmod_Ctwin_66 = 0.0_pReal
constitutive_titanmod_Ctwin_3333 = 0.0_pReal
write(6,*) 'Allocated slip system variables'
do i = 1,maxNinstance 
   myStructure = constitutive_titanmod_structure(i)

   !* Inverse lookup of my slip system family
   l = 0_pInt
   do f = 1,lattice_maxNslipFamily
      do k = 1,constitutive_titanmod_Nslip(f,i)
         l = l + 1
         constitutive_titanmod_slipFamily(l,i) = f
         constitutive_titanmod_slipSystemLattice(l,i) = sum(lattice_NslipSystem(1:f-1,myStructure)) + k
   enddo; enddo
   
   !* Inverse lookup of my twin system family
   l = 0_pInt
   do f = 1,lattice_maxNtwinFamily
      do k = 1,constitutive_titanmod_Ntwin(f,i)
         l = l + 1
         constitutive_titanmod_twinFamily(l,i) = f
         constitutive_titanmod_twinSystemLattice(l,i) = sum(lattice_NtwinSystem(1:f-1,myStructure)) + k
   enddo; enddo
   
   !* Determine size of state array  
   ns = constitutive_titanmod_totalNslip(i)
   nt = constitutive_titanmod_totalNtwin(i)
   constitutive_titanmod_sizeDotState(i) = &
   size(constitutive_titanmod_listBasicSlipStates)*ns+size(constitutive_titanmod_listBasicTwinStates)*nt
   constitutive_titanmod_sizeState(i) = &
   constitutive_titanmod_sizeDotState(i)+ &
   size(constitutive_titanmod_listDependentSlipStates)*ns+size(constitutive_titanmod_listDependentTwinStates)*nt
  write(6,*) 'Determined size of state and dot state' 
   !* Determine size of postResults array   
   do o = 1,maxval(phase_Noutput)
      select case(constitutive_titanmod_output(o,i))
        case('rhoedge', &
             'rhoscrew', &
             'shear_rate_slip', &
             'mfp_slip', &
             'resolved_stress_slip', &
             'threshold_stress_slip' &
             )
           mySize = constitutive_titanmod_totalNslip(i)
        case('twin_fraction', &
             'shear_rate_twin', &
             'mfp_twin', &
             'resolved_stress_twin', &
             'threshold_stress_twin' &
             )
           mySize = constitutive_titanmod_totalNtwin(i)
        case default
           mySize = 0_pInt
      end select

       if (mySize > 0_pInt) then  ! any meaningful output found                               
          constitutive_titanmod_sizePostResult(o,i) = mySize
          constitutive_titanmod_sizePostResults(i)  = constitutive_titanmod_sizePostResults(i) + mySize
       endif
   enddo
   
write(6,*) 'Determining elasticity matrix'

   !* Elasticity matrix and shear modulus according to material.config
   select case (myStructure)
   case(1:2) ! cubic(s)
     forall(k=1:3)
       forall(j=1:3) &
         constitutive_titanmod_Cslip_66(k,j,i)     = constitutive_titanmod_C12(i)
         constitutive_titanmod_Cslip_66(k,k,i)     = constitutive_titanmod_C11(i)
         constitutive_titanmod_Cslip_66(k+3,k+3,i) = constitutive_titanmod_C44(i)
     end forall
   case(3:)   ! all hex
     constitutive_titanmod_Cslip_66(1,1,i) = constitutive_titanmod_C11(i)
     constitutive_titanmod_Cslip_66(2,2,i) = constitutive_titanmod_C11(i)
     constitutive_titanmod_Cslip_66(3,3,i) = constitutive_titanmod_C33(i)
     constitutive_titanmod_Cslip_66(1,2,i) = constitutive_titanmod_C12(i)
     constitutive_titanmod_Cslip_66(2,1,i) = constitutive_titanmod_C12(i)
     constitutive_titanmod_Cslip_66(1,3,i) = constitutive_titanmod_C13(i)
     constitutive_titanmod_Cslip_66(3,1,i) = constitutive_titanmod_C13(i)
     constitutive_titanmod_Cslip_66(2,3,i) = constitutive_titanmod_C13(i)
     constitutive_titanmod_Cslip_66(3,2,i) = constitutive_titanmod_C13(i)
     constitutive_titanmod_Cslip_66(4,4,i) = constitutive_titanmod_C44(i)
     constitutive_titanmod_Cslip_66(5,5,i) = constitutive_titanmod_C44(i)
     constitutive_titanmod_Cslip_66(6,6,i) = 0.5_pReal*(constitutive_titanmod_C11(i)-constitutive_titanmod_C12(i))
   end select
   constitutive_titanmod_Cslip_66(:,:,i) = math_Mandel3333to66(math_Voigt66to3333(constitutive_titanmod_Cslip_66(:,:,i)))
   constitutive_titanmod_Cslip_3333(:,:,:,:,i) = math_Voigt66to3333(constitutive_titanmod_Cslip_66(:,:,i))
   constitutive_titanmod_Gmod(i) = &
   0.2_pReal*(constitutive_titanmod_C11(i)-constitutive_titanmod_C12(i))+0.3_pReal*constitutive_titanmod_C44(i)
   
   !* Construction of the twin elasticity matrices
   do j=1,lattice_maxNtwinFamily
      do k=1,constitutive_titanmod_Ntwin(j,i)	   
         do l=1,3 ; do m=1,3 ; do n=1,3 ; do o=1,3 ; do p=1,3 ; do q=1,3 ; do r=1,3 ; do s=1,3
           constitutive_titanmod_Ctwin_3333(l,m,n,o,sum(constitutive_titanmod_Nslip(1:j-1,i))+k,i) = &
             constitutive_titanmod_Ctwin_3333(l,m,n,o,sum(constitutive_titanmod_Nslip(1:j-1,i))+k,i) + &
             constitutive_titanmod_Cslip_3333(p,q,r,s,i)*&
             lattice_Qtwin(l,p,sum(lattice_NslipSystem(1:j-1,myStructure))+k,myStructure)* &
             lattice_Qtwin(m,q,sum(lattice_NslipSystem(1:j-1,myStructure))+k,myStructure)* &
             lattice_Qtwin(n,r,sum(lattice_NslipSystem(1:j-1,myStructure))+k,myStructure)* &
             lattice_Qtwin(o,s,sum(lattice_NslipSystem(1:j-1,myStructure))+k,myStructure)
           enddo ; enddo ; enddo ; enddo ; enddo ; enddo ; enddo ; enddo
         constitutive_titanmod_Ctwin_66(:,:,k,i) = math_Mandel3333to66(constitutive_titanmod_Ctwin_3333(:,:,:,:,k,i))
        enddo
   enddo

   !* Burgers vector, dislocation velocity prefactor, mean free path prefactor and minimum dipole distance for each slip system 
   do s = 1,constitutive_titanmod_totalNslip(i)   
      f = constitutive_titanmod_slipFamily(s,i)    
      constitutive_titanmod_burgersPerSlipSystem(s,i)     = constitutive_titanmod_burgersPerSlipFamily(f,i)
      constitutive_titanmod_f0_PerSlipSystem(s,i)       = constitutive_titanmod_f0_PerSlipFamily(f,i)
      constitutive_titanmod_tau0e_PerSlipSystem(s,i)       = constitutive_titanmod_tau0e_PerSlipFamily(f,i)
      constitutive_titanmod_tau0s_PerSlipSystem(s,i)       = constitutive_titanmod_tau0s_PerSlipFamily(f,i)
      constitutive_titanmod_capre_PerSlipSystem(s,i)       = constitutive_titanmod_capre_PerSlipFamily(f,i)
      constitutive_titanmod_caprs_PerSlipSystem(s,i)       = constitutive_titanmod_caprs_PerSlipFamily(f,i)
      constitutive_titanmod_v0e_PerSlipSystem(s,i)          = constitutive_titanmod_v0e_PerSlipFamily(f,i)
      constitutive_titanmod_v0s_PerSlipSystem(s,i)          = constitutive_titanmod_v0s_PerSlipFamily(f,i)
      constitutive_titanmod_pe_PerSlipSystem(s,i)          = constitutive_titanmod_pe_PerSlipFamily(f,i)
      constitutive_titanmod_ps_PerSlipSystem(s,i)          = constitutive_titanmod_ps_PerSlipFamily(f,i)
      constitutive_titanmod_qe_PerSlipSystem(s,i)          = constitutive_titanmod_qe_PerSlipFamily(f,i)
      constitutive_titanmod_qs_PerSlipSystem(s,i)          = constitutive_titanmod_qs_PerSlipFamily(f,i)
      constitutive_titanmod_CeLambdaSlipPerSlipSystem(s,i) = constitutive_titanmod_CeLambdaSlipPerSlipFamily(f,i)
      constitutive_titanmod_CsLambdaSlipPerSlipSystem(s,i) = constitutive_titanmod_CsLambdaSlipPerSlipFamily(f,i)
   enddo   
   
   !* Burgers vector, nucleation rate prefactor and twin size for each twin system 
   do s = 1,constitutive_titanmod_totalNtwin(i)   
      f = constitutive_titanmod_twinFamily(s,i)    
      constitutive_titanmod_burgersPerTwinSystem(s,i)  = constitutive_titanmod_burgersPerTwinFamily(f,i)
      constitutive_titanmod_Ndot0PerTwinSystem(s,i)    = constitutive_titanmod_Ndot0PerTwinFamily(f,i)
      constitutive_titanmod_twinsizePerTwinSystem(s,i) = constitutive_titanmod_twinsizePerTwinFamily(f,i)
   enddo   
     
   !* Construction of interaction matrices
   do s1 = 1,constitutive_titanmod_totalNslip(i)
      do s2 = 1,constitutive_titanmod_totalNslip(i)     
         constitutive_titanmod_interactionMatrixSlipSlip(s1,s2,i) = &
         constitutive_titanmod_interactionSlipSlip(lattice_interactionSlipSlip(constitutive_titanmod_slipSystemLattice(s1,i), &
                                                                                constitutive_titanmod_slipSystemLattice(s2,i), &
                                                                                myStructure),i)
   enddo; enddo
   
   do s1 = 1,constitutive_titanmod_totalNslip(i)
      do t2 = 1,constitutive_titanmod_totalNtwin(i)     
         constitutive_titanmod_interactionMatrixSlipTwin(s1,t2,i) = &
         constitutive_titanmod_interactionSlipTwin(lattice_interactionSlipTwin(constitutive_titanmod_slipSystemLattice(s1,i), &
                                                                                constitutive_titanmod_twinSystemLattice(t2,i), &
                                                                                myStructure),i)         
   enddo; enddo
   
   do t1 = 1,constitutive_titanmod_totalNtwin(i)
      do s2 = 1,constitutive_titanmod_totalNslip(i)     
         constitutive_titanmod_interactionMatrixTwinSlip(t1,s2,i) = &
         constitutive_titanmod_interactionTwinSlip(lattice_interactionTwinSlip(constitutive_titanmod_twinSystemLattice(t1,i), &
                                                                                constitutive_titanmod_slipSystemLattice(s2,i), &
                                                                                myStructure),i)         
   enddo; enddo

   do t1 = 1,constitutive_titanmod_totalNtwin(i)
      do t2 = 1,constitutive_titanmod_totalNtwin(i)     
         constitutive_titanmod_interactionMatrixTwinTwin(t1,t2,i) = &
         constitutive_titanmod_interactionTwinTwin(lattice_interactionTwinTwin(constitutive_titanmod_twinSystemLattice(t1,i), &
                                                                                constitutive_titanmod_twinSystemLattice(t2,i), &
                                                                                myStructure),i)         
   enddo; enddo
   
   !* Calculation of forest projections for edge dislocations 
   do s1 = 1,constitutive_titanmod_totalNslip(i)
      do s2 = 1,constitutive_titanmod_totalNslip(i)      
         constitutive_titanmod_forestProjectionEdge(s1,s2,i) = &
         abs(math_mul3x3(lattice_sn(:,constitutive_titanmod_slipSystemLattice(s1,i),myStructure), &
                         lattice_st(:,constitutive_titanmod_slipSystemLattice(s2,i),myStructure))) 
   enddo; enddo
  
enddo
write(6,*) 'Init All done'
return
end subroutine


function constitutive_titanmod_stateInit(myInstance)
!*********************************************************************
!* initial microstructural state                                     *
!*********************************************************************
use prec,    only: pReal,pInt
use math,    only: pi
use lattice, only: lattice_maxNslipFamily,lattice_maxNtwinFamily
implicit none

!* Input-Output variables
integer(pInt) :: myInstance
real(pReal), dimension(constitutive_titanmod_sizeState(myInstance))  :: constitutive_titanmod_stateInit
!* Local variables
integer(pInt) s0,s1,s,t,f,ns,nt
real(pReal), dimension(constitutive_titanmod_totalNslip(myInstance)) :: rho_edge0, &
                                                                         rho_screw0, &
                                                                         invLambdaSlip0e, &
                                                                         invLambdaSlip0s, &
                                                                         etauSlipThreshold0, &
																		 stauSlipThreshold0
real(pReal), dimension(constitutive_titanmod_totalNtwin(myInstance)) :: MeanFreePathTwin0,TwinVolume0

ns = constitutive_titanmod_totalNslip(myInstance)
nt = constitutive_titanmod_totalNtwin(myInstance)
constitutive_titanmod_stateInit = 0.0_pReal

!* Initialize basic slip state variables
s1 = 0_pInt
do f = 1,lattice_maxNslipFamily
   s0 = s1 + 1_pInt
   s1 = s0 + constitutive_titanmod_Nslip(f,myInstance) - 1_pInt 
   do s = s0,s1
      rho_edge0(s)    = constitutive_titanmod_rho_edge0(f,myInstance)
      rho_screw0(s) = constitutive_titanmod_rho_screw0(f,myInstance)
   enddo 
enddo
constitutive_titanmod_stateInit(1:ns)      = rho_edge0
constitutive_titanmod_stateInit(ns+1:2*ns) = rho_screw0

!* Initialize dependent slip microstructural variables
forall (s = 1:ns) &
invLambdaSlip0e(s) = sqrt(sum(rho_edge0(1:ns))+sum(rho_screw0(1:ns)))/ &
constitutive_titanmod_CeLambdaSlipPerSlipSystem(s,myInstance) 
constitutive_titanmod_stateInit(2*ns+nt+1:3*ns+nt) = invLambdaSlip0e

forall (s = 1:ns) &
invLambdaSlip0s(s) = sqrt(sum(rho_edge0(1:ns))+sum(rho_screw0(1:ns)))/ &
constitutive_titanmod_CsLambdaSlipPerSlipSystem(s,myInstance)  
constitutive_titanmod_stateInit(4*ns+2*nt+1:5*ns+2*nt) = invLambdaSlip0s

forall (s = 1:ns) &
etauSlipThreshold0(s) = &
constitutive_titanmod_Gmod(myInstance)*constitutive_titanmod_burgersPerSlipSystem(s,myInstance)* &
sqrt(dot_product((rho_edge0+rho_screw0),constitutive_titanmod_interactionMatrixSlipSlip(1:ns,s,myInstance)))
constitutive_titanmod_stateInit(5*ns+3*nt+1:6*ns+3*nt) = etauSlipThreshold0

forall (s = 1:ns) &
stauSlipThreshold0(s) = &
constitutive_titanmod_Gmod(myInstance)*constitutive_titanmod_burgersPerSlipSystem(s,myInstance)* &
sqrt(dot_product((rho_edge0+rho_screw0),constitutive_titanmod_interactionMatrixSlipSlip(1:ns,s,myInstance)))
constitutive_titanmod_stateInit(6*ns+3*nt+1:7*ns+3*nt) = stauSlipThreshold0

!* Initialize dependent twin microstructural variables
forall (t = 1:nt) &
MeanFreePathTwin0(t) = constitutive_titanmod_GrainSize(myInstance)
constitutive_titanmod_stateInit(5*ns+2*nt+1:5*ns+3*nt) = MeanFreePathTwin0

forall (t = 1:nt) &
TwinVolume0(t) = & 
(pi/6.0_pReal)*constitutive_titanmod_twinsizePerTwinSystem(t,myInstance)*MeanFreePathTwin0(t)**(2.0_pReal)
constitutive_titanmod_stateInit(6*ns+4*nt+1:6*ns+5*nt) = TwinVolume0

!write(6,*) '#STATEINIT#'
!write(6,*)
!write(6,'(a,/,4(3(f30.20,x)/))') 'rho_edge',rho_edge0
!write(6,'(a,/,4(3(f30.20,x)/))') 'rho_screw',rho_screw0
!write(6,'(a,/,4(3(f30.20,x)/))') 'invLambdaSlipe',invLambdaSlip0e
!write(6,'(a,/,4(3(f30.20,x)/))') 'invLambdaSlips',invLambdaSlip0s
!write(6,'(a,/,4(3(f30.20,x)/))') 'tauSlipThreshold', tauSlipThreshold0
!write(6,'(a,/,4(3(f30.20,x)/))') 'MeanFreePathTwin', MeanFreePathTwin0
!write(6,'(a,/,4(3(f30.20,x)/))') 'TwinVolume', TwinVolume0

return
end function


pure function constitutive_titanmod_relevantState(myInstance)
!*********************************************************************
!* relevant microstructural state                                    *
!*********************************************************************
use prec,     only: pReal, pInt
implicit none

!* Input-Output variables
integer(pInt), intent(in) :: myInstance
real(pReal), dimension(constitutive_titanmod_sizeState(myInstance)) :: constitutive_titanmod_relevantState

constitutive_titanmod_relevantState = constitutive_titanmod_relevantRho(myInstance)

return
endfunction


pure function constitutive_titanmod_homogenizedC(state,g,ip,el)
!*********************************************************************
!* calculates homogenized elacticity matrix                          *
!*  - state           : microstructure quantities                    *
!*  - g               : component-ID of current integration point    *
!*  - ip              : current integration point                    *
!*  - el              : current element                              *
!*********************************************************************
use prec,     only: pReal,pInt,p_vec
use mesh,     only: mesh_NcpElems,mesh_maxNips
use material, only: homogenization_maxNgrains,material_phase,phase_constitutionInstance
implicit none

!* Input-Output variables
integer(pInt), intent(in) :: g,ip,el
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: state
real(pReal), dimension(6,6) :: constitutive_titanmod_homogenizedC
!* Local variables 
integer(pInt) myInstance,ns,nt,i
real(pReal) sumf
 
!* Shortened notation
myInstance = phase_constitutionInstance(material_phase(g,ip,el))
ns = constitutive_titanmod_totalNslip(myInstance)
nt = constitutive_titanmod_totalNtwin(myInstance)

!* Total twin volume fraction
sumf = sum(state(g,ip,el)%p((2*ns+1):(2*ns+nt))) ! safe for nt == 0

!* Homogenized elasticity matrix
constitutive_titanmod_homogenizedC = (1.0_pReal-sumf)*constitutive_titanmod_Cslip_66(:,:,myInstance)
do i=1,nt
   constitutive_titanmod_homogenizedC = &
   constitutive_titanmod_homogenizedC + state(g,ip,el)%p(2*ns+i)*constitutive_titanmod_Ctwin_66(:,:,i,myInstance)
enddo 

return
end function


subroutine constitutive_titanmod_microstructure(Temperature,state,g,ip,el)
!*********************************************************************
!* calculates quantities characterizing the microstructure           *
!*  - Temperature     : temperature                                  *
!*  - state           : microstructure quantities                    *
!*  - ipc             : component-ID of current integration point    *
!*  - ip              : current integration point                    *
!*  - el              : current element                              *
!*********************************************************************
use prec,     only: pReal,pInt,p_vec
use math,     only: pi
use mesh,     only: mesh_NcpElems,mesh_maxNips
use material, only: homogenization_maxNgrains,material_phase,phase_constitutionInstance
use lattice,  only: lattice_interactionSlipTwin,lattice_interactionTwinTwin
!use debug,    only: debugger
implicit none

!* Input-Output variables
integer(pInt), intent(in) :: g,ip,el
real(pReal), intent(in) :: Temperature
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(inout) :: state
!* Local variables
integer(pInt) myInstance,myStructure,ns,nt,s,t,i
real(pReal) sumf,sfe
real(pReal), dimension(constitutive_titanmod_totalNtwin(phase_constitutionInstance(material_phase(g,ip,el)))) :: fOverStacksize
 
!* Shortened notation
myInstance = phase_constitutionInstance(material_phase(g,ip,el))
myStructure = constitutive_titanmod_structure(myInstance)
ns = constitutive_titanmod_totalNslip(myInstance)
nt = constitutive_titanmod_totalNtwin(myInstance)
!* State: 1           :  ns         rho_edge
!* State: ns+1        :  2*ns       rho_screw
!* State: 2*ns+1      :  2*ns+nt    f
!* State: 2*ns+nt+1   :  3*ns+nt    1/lambda_slip
!* State: 3*ns+nt+1   :  4*ns+nt    1/lambda_sliptwin
!* State: 4*ns+nt+1   :  4*ns+2*nt  1/lambda_twin
!* State: 4*ns+2*nt+1 :  5*ns+2*nt  mfp_slip
!* State: 5*ns+2*nt+1 :  5*ns+3*nt  mfp_twin
!* State: 5*ns+3*nt+1 :  6*ns+3*nt  threshold_stress_slip
!* State: 6*ns+3*nt+1 :  6*ns+4*nt  threshold_stress_twin
!* State: 6*ns+4*nt+1 :  6*ns+5*nt  twin volume

!* Total twin volume fraction
sumf = sum(state(g,ip,el)%p((2*ns+1):(2*ns+nt))) ! safe for nt == 0

!* Stacking fault energy
sfe = 0.0002_pReal*Temperature-0.0396_pReal

!* rescaled twin volume fraction for topology
forall (t = 1:nt) &
  fOverStacksize(t) = &
    state(g,ip,el)%p(2*ns+t)/constitutive_titanmod_twinsizePerTwinSystem(t,myInstance)
 
!* 1/mean free distance between 2 forest dislocations seen by a moving dislocation
forall (s = 1:ns) &
  state(g,ip,el)%p(2*ns+nt+s) = &
    sqrt(state(g,ip,el)%p(s)+state(g,ip,el)%p(ns+s))/ &
    constitutive_titanmod_CeLambdaSlipPerSlipSystem(s,myInstance) 

!* 1/mean free distance between 2 twin stacks from different systems seen by a moving dislocation
!$OMP CRITICAL (evilmatmul)
state(g,ip,el)%p((3*ns+nt+1):(4*ns+nt)) = 0.0_pReal
if (nt > 0_pInt) &
  state(g,ip,el)%p((3*ns+nt+1):(4*ns+nt)) = &
    matmul(constitutive_titanmod_interactionMatrixSlipTwin(1:ns,1:nt,myInstance),fOverStacksize(1:nt))/(1.0_pReal-sumf)
!$OMP END CRITICAL (evilmatmul)

!* 1/mean free distance between 2 twin stacks from different systems seen by a growing twin
!$OMP CRITICAL (evilmatmul)
if (nt > 0_pInt) &
  state(g,ip,el)%p((4*ns+nt+1):(4*ns+2*nt)) = &
    matmul(constitutive_titanmod_interactionMatrixTwinTwin(1:nt,1:nt,myInstance),fOverStacksize(1:nt))/(1.0_pReal-sumf)
!$OMP END CRITICAL (evilmatmul)

!* mean free path between 2 obstacles seen by a moving dislocation
do s = 1,ns
   if (nt > 0_pInt) then
      state(g,ip,el)%p(4*ns+2*nt+s) = &
		constitutive_titanmod_CsLambdaSlipPerSlipSystem(s,myInstance) / &
	  sqrt(sum(state(g,ip,el)%p(1:2*ns)))
   else
      state(g,ip,el)%p(4*ns+s) = &
		constitutive_titanmod_CsLambdaSlipPerSlipSystem(s,myInstance) / &
	  sqrt(sum(state(g,ip,el)%p(1:2*ns)))
!       (1.0_pReal+constitutive_titanmod_GrainSize(myInstance)*(state(g,ip,el)%p(2*ns+s)))
   endif
enddo

!* mean free path between 2 obstacles seen by a growing twin
forall (t = 1:nt) &
  state(g,ip,el)%p(5*ns+2*nt+t) = &
    (constitutive_titanmod_Cmfptwin(myInstance)*constitutive_titanmod_GrainSize(myInstance))/&
    (1.0_pReal+constitutive_titanmod_GrainSize(myInstance)*state(g,ip,el)%p(4*ns+nt+t))     

!* threshold stress for edge dislocation motion
forall (s = 1:ns) &
  state(g,ip,el)%p(5*ns+3*nt+s) = &
    constitutive_titanmod_Gmod(myInstance)*constitutive_titanmod_burgersPerSlipSystem(s,myInstance)*&
    sqrt(dot_product((state(g,ip,el)%p(1:ns)+state(g,ip,el)%p(ns+1:2*ns)),&
	                 constitutive_titanmod_interactionMatrixSlipSlip(1:ns,s,myInstance)))

!* threshold stress for screw dislocation motion
forall (s = 1:ns) &
  state(g,ip,el)%p(6*ns+3*nt+s) = &
    constitutive_titanmod_Gmod(myInstance)*constitutive_titanmod_burgersPerSlipSystem(s,myInstance)*&
    sqrt(dot_product((state(g,ip,el)%p(1:ns)+state(g,ip,el)%p(ns+1:2*ns)),&
	                 constitutive_titanmod_interactionMatrixSlipSlip(1:ns,s,myInstance)))
					 
!* threshold stress for growing twin
forall (t = 1:nt) &
  state(g,ip,el)%p(6*ns+3*nt+t) = &
    constitutive_titanmod_Cthresholdtwin(myInstance)*&
    (sfe/(3.0_pReal*constitutive_titanmod_burgersPerTwinSystem(t,myInstance))+&
    3.0_pReal*constitutive_titanmod_burgersPerTwinSystem(t,myInstance)*constitutive_titanmod_Gmod(myInstance)/&
    state(g,ip,el)%p(5*ns+2*nt+t))

!* final twin volume after growth
forall (t = 1:nt) &
  state(g,ip,el)%p(6*ns+4*nt+t) = &
    (pi/6.0_pReal)*constitutive_titanmod_twinsizePerTwinSystem(t,myInstance)*state(g,ip,el)%p(5*ns+2*nt+t)**(2.0_pReal)

!if ((ip==1).and.(el==1)) then
!   write(6,*) '#MICROSTRUCTURE#'
! write(6,*)
! write(6,'(a,/,4(3(f10.4,x)/))') 'rho_edge',state(g,ip,el)%p(1:ns)/1e9
! write(6,'(a,/,4(3(f10.4,x)/))') 'rho_screw',state(g,ip,el)%p(ns+1:2*ns)/1e9
! write(6,'(a,/,4(3(f10.4,x)/))') 'Fraction',state(g,ip,el)%p(2*ns+1:2*ns+nt)
!endif


return
end subroutine


subroutine constitutive_titanmod_LpAndItsTangent(Lp,dLp_dTstar,Tstar_v,Temperature,state,g,ip,el)
!*********************************************************************
!* calculates plastic velocity gradient and its tangent              *
!* INPUT:                                                            *
!*  - Temperature     : temperature                                  *
!*  - state           : microstructure quantities                    *
!*  - Tstar_v         : 2nd Piola Kirchhoff stress tensor (Mandel)   *
!*  - ipc             : component-ID at current integration point    *
!*  - ip              : current integration point                    *
!*  - el              : current element                              *
!* OUTPUT:                                                           *
!*  - Lp              : plastic velocity gradient                    *
!*  - dLp_dTstar      : derivative of Lp (4th-rank tensor)           *
!*********************************************************************
use prec,     only: pReal,pInt,p_vec
use math,     only: math_Plain3333to99
use mesh,     only: mesh_NcpElems,mesh_maxNips
use material, only: homogenization_maxNgrains,material_phase,phase_constitutionInstance
use lattice,  only: lattice_Sslip,lattice_Sslip_v,lattice_Stwin,lattice_Stwin_v,lattice_maxNslipFamily,lattice_maxNtwinFamily, &
                    lattice_NslipSystem,lattice_NtwinSystem,lattice_shearTwin
implicit none

!* Input-Output variables
integer(pInt), intent(in) :: g,ip,el
real(pReal), intent(in) :: Temperature
real(pReal), dimension(6), intent(in) :: Tstar_v
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(inout) :: state
real(pReal), dimension(3,3), intent(out) :: Lp
real(pReal), dimension(9,9), intent(out) :: dLp_dTstar
!* Local variables
integer(pInt) myInstance,myStructure,ns,nt,f,i,j,k,l,m,n,index_myFamily
real(pReal) sumf,StressRatio_edge_p,StressRatio_edge_pminus1,StressRatio_screw_p,StressRatio_screw_pminus1, &
	StressRatio_r,BoltzmannRatio,DotGamma0
real(pReal), dimension(3,3,3,3) :: dLp_dTstar3333
real(pReal), dimension(constitutive_titanmod_totalNslip(phase_constitutionInstance(material_phase(g,ip,el)))) :: &
   gdot_slip,dgdot_dtauslip,tau_slip
real(pReal), dimension(constitutive_titanmod_totalNtwin(phase_constitutionInstance(material_phase(g,ip,el)))) :: &
   gdot_twin,dgdot_dtautwin,tau_twin

!* Shortened notation
myInstance  = phase_constitutionInstance(material_phase(g,ip,el))
myStructure = constitutive_titanmod_structure(myInstance) 
ns = constitutive_titanmod_totalNslip(myInstance)
nt = constitutive_titanmod_totalNtwin(myInstance)

!* Total twin volume fraction
sumf = sum(state(g,ip,el)%p((2*ns+1):(2*ns+nt))) ! safe for nt == 0

Lp = 0.0_pReal
dLp_dTstar3333 = 0.0_pReal
dLp_dTstar = 0.0_pReal

!* Dislocation glide part
gdot_slip = 0.0_pReal
dgdot_dtauslip = 0.0_pReal
j = 0_pInt
do f = 1,lattice_maxNslipFamily                                 ! loop over all slip families
   index_myFamily = sum(lattice_NslipSystem(1:f-1,myStructure)) ! at which index starts my family
   do i = 1,constitutive_titanmod_Nslip(f,myInstance)          ! process each (active) slip system in family
      j = j+1_pInt

      !* Calculation of Lp
      !* Resolved shear stress on slip system
      tau_slip(j) = dot_product(Tstar_v,lattice_Sslip_v(:,index_myFamily+i,myStructure)) 

!*************************************************
 
     !* Stress ratio for edge
	if((abs(tau_slip(j))-state(g,ip,el)%p(5*ns+3*nt+j))>0.0_pReal) then
	 StressRatio_edge_p = ((abs(tau_slip(j))-state(g,ip,el)%p(5*ns+3*nt+j))/ &
        constitutive_titanmod_tau0e_PerSlipSystem(j,myInstance))**constitutive_titanmod_pe_PerSlipSystem(j,myInstance)
	else
	StressRatio_edge_p=0.0_pReal
	endif
	
     !* Stress ratio for screw
	if((abs(tau_slip(j))-state(g,ip,el)%p(6*ns+3*nt+j))>0.0_pReal) then
      StressRatio_screw_p = ((abs(tau_slip(j))-state(g,ip,el)%p(6*ns+3*nt+j))/ &
        constitutive_titanmod_tau0s_PerSlipSystem(j,myInstance))**constitutive_titanmod_pe_PerSlipSystem(j,myInstance)
	else
	StressRatio_screw_p=0.0_pReal
	endif

     !* Stress ratio for edge p minus1
	if((abs(tau_slip(j))-state(g,ip,el)%p(5*ns+3*nt+j))>0.0_pReal) then
      StressRatio_edge_pminus1 = ((abs(tau_slip(j))-state(g,ip,el)%p(5*ns+3*nt+j))/ &
        constitutive_titanmod_tau0e_PerSlipSystem(j,myInstance))**(constitutive_titanmod_pe_PerSlipSystem(j,myInstance)-1)
	else
	StressRatio_edge_pminus1=0.0_pReal
	endif

     !* Stress ratio for screw p minus1
	if((abs(tau_slip(j))-state(g,ip,el)%p(6*ns+3*nt+j))>0.0_pReal) then
      StressRatio_screw_pminus1 = ((abs(tau_slip(j))-state(g,ip,el)%p(6*ns+3*nt+j))/ &
        constitutive_titanmod_tau0s_PerSlipSystem(j,myInstance))**(constitutive_titanmod_pe_PerSlipSystem(j,myInstance)-1)
	else
	StressRatio_screw_pminus1=0.0_pReal
	endif

      !* Boltzmann ratio
      BoltzmannRatio = constitutive_titanmod_f0_PerSlipSystem(j,myInstance)/(kB*Temperature)

      !* Initial shear rates
      DotGamma0 = &
        constitutive_titanmod_burgersPerSlipSystem(j,myInstance)*2.0_pReal*(state(g,ip,el)%p(j)*&
        + constitutive_titanmod_v0e_PerSlipSystem(j,myInstance)+state(g,ip,el)%p(ns+j)* &
		constitutive_titanmod_v0e_PerSlipSystem(j,myInstance))

      !* Shear rates due to slip
       gdot_slip(j) = constitutive_titanmod_burgersPerSlipSystem(j,myInstance)*2.0_pReal*(state(g,ip,el)%p(j)* &
		constitutive_titanmod_v0e_PerSlipSystem(j,myInstance)*exp(-BoltzmannRatio*(1-StressRatio_edge_p)** &
		constitutive_titanmod_qe_PerSlipSystem(j,myInstance))+state(g,ip,el)%p(ns+j)* &
		constitutive_titanmod_v0s_PerSlipSystem(j,myInstance)*exp(-BoltzmannRatio*(1-StressRatio_screw_p)** &
		constitutive_titanmod_qs_PerSlipSystem(j,myInstance)))* sign(1.0_pReal,tau_slip(j))

      !* Derivatives of shear rates
      dgdot_dtauslip(j) = &
        2.0_pReal* &
		( &
		( &
		( &
		( &
		abs(gdot_slip(j)) &
		*BoltzmannRatio*&
        constitutive_titanmod_pe_PerSlipSystem(j,myInstance)* &
		constitutive_titanmod_qe_PerSlipSystem(j,myInstance) &
		)/ &
		constitutive_titanmod_tau0e_PerSlipSystem(j,myInstance) &
		)*&
        StressRatio_edge_pminus1*(1-StressRatio_edge_p)** &
		(constitutive_titanmod_qe_PerSlipSystem(j,myInstance)-1.0_pReal) &
		) + &
		( &
		( &
		(abs(gdot_slip(j))*BoltzmannRatio*&
        constitutive_titanmod_ps_PerSlipSystem(j,myInstance)* &
		constitutive_titanmod_qs_PerSlipSystem(j,myInstance) &
		)/ &
		constitutive_titanmod_tau0s_PerSlipSystem(j,myInstance) &
		)*&
        StressRatio_screw_pminus1*(1-StressRatio_screw_p)**(constitutive_titanmod_qs_PerSlipSystem(j,myInstance)-1.0_pReal) &
		) &
		)
				
!*************************************************		
      !* Plastic velocity gradient for dislocation glide
      Lp = Lp + (1.0_pReal - sumf)*gdot_slip(j)*lattice_Sslip(:,:,index_myFamily+i,myStructure)

      !* Calculation of the tangent of Lp
      forall (k=1:3,l=1:3,m=1:3,n=1:3) &
        dLp_dTstar3333(k,l,m,n) = &
        dLp_dTstar3333(k,l,m,n) + dgdot_dtauslip(j)*&
                                  lattice_Sslip(k,l,index_myFamily+i,myStructure)*&
                                  lattice_Sslip(m,n,index_myFamily+i,myStructure) 
   enddo
enddo

!* Mechanical twinning part
gdot_twin = 0.0_pReal
dgdot_dtautwin = 0.0_pReal
j = 0_pInt
do f = 1,lattice_maxNtwinFamily                                 ! loop over all slip families
   index_myFamily = sum(lattice_NtwinSystem(1:f-1,myStructure)) ! at which index starts my family
   do i = 1,constitutive_titanmod_Ntwin(f,myInstance)          ! process each (active) slip system in family
      j = j+1_pInt

      !* Calculation of Lp
      !* Resolved shear stress on twin system
      tau_twin(j) = dot_product(Tstar_v,lattice_Stwin_v(:,index_myFamily+i,myStructure))        
     
	  !* Stress ratios
      StressRatio_r = (state(g,ip,el)%p(6*ns+3*nt+j)/tau_twin(j))**constitutive_titanmod_r(myInstance)      
      
	  !* Shear rates and their derivatives due to twin
      if ( tau_twin(j) > 0.0_pReal ) then          
        gdot_twin(j) = &
          (constitutive_titanmod_MaxTwinFraction(myInstance)-sumf)*lattice_shearTwin(index_myFamily+i,myStructure)*&
          state(g,ip,el)%p(6*ns+4*nt+j)*constitutive_titanmod_Ndot0PerTwinSystem(f,myInstance)*exp(-StressRatio_r) 
        dgdot_dtautwin(j) = ((gdot_twin(j)*constitutive_titanmod_r(myInstance))/tau_twin(j))*StressRatio_r
      endif

      !* Plastic velocity gradient for mechanical twinning	   					   
      Lp = Lp + gdot_twin(j)*lattice_Stwin(:,:,index_myFamily+i,myStructure)

      !* Calculation of the tangent of Lp
      forall (k=1:3,l=1:3,m=1:3,n=1:3) &
        dLp_dTstar3333(k,l,m,n) = &
        dLp_dTstar3333(k,l,m,n) + dgdot_dtautwin(j)*&
                                  lattice_Stwin(k,l,index_myFamily+i,myStructure)*&
                                  lattice_Stwin(m,n,index_myFamily+i,myStructure)
   enddo
enddo

dLp_dTstar = math_Plain3333to99(dLp_dTstar3333)

!if ((ip==1).and.(el==1)) then
!   write(6,*) '#LP/TANGENT#'
!   write(6,*)
!   write(6,*) 'Tstar_v', Tstar_v
!   write(6,*) 'tau_slip', tau_slip
!   write(6,'(a10,/,4(3(e20.8,x),/))') 'state',state(1,1,1)%p
!   write(6,'(a,/,3(3(f10.4,x)/))') 'Lp',Lp
!   write(6,'(a,/,9(9(f10.4,x)/))') 'dLp_dTstar',dLp_dTstar
!endif

return
end subroutine


function constitutive_titanmod_dotState(Tstar_v,Temperature,state,g,ip,el)
!*********************************************************************
!* rate of change of microstructure                                  *
!* INPUT:                                                            *
!*  - Temperature     : temperature                                  *
!*  - state           : microstructure quantities                    *
!*  - Tstar_v         : 2nd Piola Kirchhoff stress tensor (Mandel)   *
!*  - ipc             : component-ID at current integration point    *
!*  - ip              : current integration point                    *
!*  - el              : current element                              *
!* OUTPUT:                                                           *
!*  - constitutive_dotState : evolution of state variable            *
!*********************************************************************
use prec,     only: pReal,pInt,p_vec

use math,     only: pi
use mesh,     only: mesh_NcpElems,mesh_maxNips
use material, only: homogenization_maxNgrains,material_phase, phase_constitutionInstance
use lattice,  only: lattice_Sslip,lattice_Sslip_v,lattice_Stwin,lattice_Stwin_v,lattice_maxNslipFamily,lattice_maxNtwinFamily, &
                     lattice_NslipSystem,lattice_NtwinSystem,lattice_shearTwin   
implicit none

!* Input-Output variables
integer(pInt), intent(in) :: g,ip,el
real(pReal), intent(in) :: Temperature
real(pReal), dimension(6), intent(in) :: Tstar_v
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: state
real(pReal), dimension(constitutive_titanmod_sizeDotState(phase_constitutionInstance(material_phase(g,ip,el)))) :: &
constitutive_titanmod_dotState
!* Local variables
integer(pInt) MyInstance,MyStructure,ns,nt,f,i,j,k,index_myFamily,s
real(pReal) sumf,StressRatio_edge_p,StressRatio_pminus1,BoltzmannRatio,DotGamma0,&
            EdgeDipMinDistance,AtomicVolume,VacancyDiffusion,StressRatio_r,StressRatio_screw_p
real(pReal), dimension(constitutive_titanmod_totalNslip(phase_constitutionInstance(material_phase(g,ip,el)))) :: &
gdot_slip,tau_slip,DotRhoEdgeGeneration,EdgeDipDistance,DotRhoEdgeAnnihilation,DotRhoScrewAnnihilation,&
ClimbVelocity,DotRhoScrewGeneration, edge_segment, screw_segment,edge_velocity,screw_velocity
real(pReal), dimension(constitutive_titanmod_totalNtwin(phase_constitutionInstance(material_phase(g,ip,el)))) :: gdot_twin,tau_twin
   
!* Shortened notation
myInstance  = phase_constitutionInstance(material_phase(g,ip,el))
MyStructure = constitutive_titanmod_structure(myInstance) 
ns = constitutive_titanmod_totalNslip(myInstance)
nt = constitutive_titanmod_totalNtwin(myInstance)

!* Total twin volume fraction
sumf = sum(state(g,ip,el)%p((2*ns+1):(2*ns+nt))) ! safe for nt == 0

constitutive_titanmod_dotState = 0.0_pReal

!* average segment length for edge dislocations
forall (s = 1:ns) &
  edge_segment(s) = &
  (constitutive_titanmod_CeLambdaSlipPerSlipSystem(s,myInstance))/(sum(state(g,ip,el)%p(1:2*ns) &
    ))**0.5_pReal

!* average segment length for screw dislocations
forall (s = 1:ns) &
  screw_segment(s) = &
  (constitutive_titanmod_CsLambdaSlipPerSlipSystem(s,myInstance))/(sum(state(g,ip,el)%p(1:2*ns) &
    ))**0.5_pReal
    
 j = 0_pInt
 do f = 1,lattice_maxNslipFamily                                             ! loop over all slip families
   index_myFamily = sum(lattice_NslipSystem(1:f-1,myStructure))                 ! at which index starts my family
   do i = 1,constitutive_titanmod_Nslip(f,myInstance)                        ! process each (active) slip system in family
     j = j+1_pInt

! Resolved shear stress
     tau_slip(j)  = dot_product(Tstar_v,lattice_Sslip_v(:,index_myFamily+i,myStructure)) 

     !* Stress ratio for edge
	if((abs(tau_slip(j))-state(g,ip,el)%p(5*ns+3*nt+j)) > 0.0_pReal) then
	 StressRatio_edge_p = ((abs(tau_slip(j))-state(g,ip,el)%p(5*ns+3*nt+j))/ &
        constitutive_titanmod_tau0e_PerSlipSystem(j,myInstance))** constitutive_titanmod_pe_PerSlipSystem(j,myInstance)
   else
	StressRatio_edge_p=0.0_pReal
	endif
	
     !* Stress ratio for screw
	if((abs(tau_slip(j))-state(g,ip,el)%p(6*ns+3*nt+j)) > 0.0_pReal) then
	 StressRatio_screw_p = ((abs(tau_slip(j))-state(g,ip,el)%p(6*ns+3*nt+j))/ &
        constitutive_titanmod_tau0s_PerSlipSystem(j,myInstance))**constitutive_titanmod_ps_PerSlipSystem(j,myInstance)
   else
	StressRatio_screw_p=0.0_pReal
	endif

		!* Boltzmann ratio
      BoltzmannRatio = constitutive_titanmod_f0_PerSlipSystem(j,myInstance)/(kB*Temperature)

!         if (tau_slip(j) == 0.0_pReal) then
!	     edge_velocity(j) = 0.0_pReal
!	     screw_velocity(j) = 0.0_pReal
!         else	  
	    edge_velocity(j) =constitutive_titanmod_v0e_PerSlipSystem(j,myInstance)*exp(-BoltzmannRatio*(1-StressRatio_edge_p)** &
            constitutive_titanmod_qe_PerSlipSystem(j,myInstance))
	    screw_velocity(j) =constitutive_titanmod_v0s_PerSlipSystem(j,myInstance)*exp(-BoltzmannRatio*(1-StressRatio_screw_p)** &
            constitutive_titanmod_qs_PerSlipSystem(j,myInstance))
!         endif
!	write(6,*) 'edge_segment(j) ',edge_segment(j)
!	write(6,*) 'screw_segment(j) ',screw_segment(j)
!	write(6,*) 'tau_slip(j) ',tau_slip(j)
!	write(6,*) 'Temperature ',Temperature
!	write(6,*) 'kB ',kB 
!	write(6,*) 'constitutive_titanmod_f0_PerSlipSystem(j,myInstance) ',constitutive_titanmod_f0_PerSlipSystem(j,myInstance)
!	write(6,*) 'StressRatio_edge_p',StressRatio_edge_p,j
!	write(6,*) 'StressRatio_screw_p',StressRatio_screw_p,j
!	write(6,*) 'edge_velocity(j)',edge_velocity(j),j
!	write(6,*) 'screw_velocity(j)',screw_velocity(j),j
      !* Multiplication of edge dislocations
      DotRhoEdgeGeneration(j) = 4.0_pReal*(state(g,ip,el)%p(ns+j)*screw_velocity(j)/screw_segment(j))
      !* Multiplication of screw dislocations
      DotRhoScrewGeneration(j) = 4.0_pReal*(state(g,ip,el)%p(j)*edge_velocity(j)/edge_segment(j))

      !* Annihilation of edge dislocations
      DotRhoEdgeAnnihilation(j) = -4.0_pReal*((state(g,ip,el)%p(j))**2)* &
		constitutive_titanmod_capre_PerSlipSystem(j,myInstance)*edge_velocity(j)

      !* Annihilation of screw dislocations
      DotRhoScrewAnnihilation(j) = -4.0_pReal*((state(g,ip,el)%p(ns+j))**2)* &
		constitutive_titanmod_caprs_PerSlipSystem(j,myInstance)*screw_velocity(j)
       
      !* Edge dislocation density rate of change
      constitutive_titanmod_dotState(j) = &
        DotRhoEdgeGeneration(j)+DotRhoEdgeAnnihilation(j)

      !* Screw dislocation density rate of change
      constitutive_titanmod_dotState(ns+j) = &
        DotRhoScrewGeneration(j)+DotRhoScrewAnnihilation(j)

!	write(6,*) 'DotRhoEdgeGeneration(j)',DotRhoEdgeGeneration(j)
!	write(6,*) 'DotRhoScrewGeneration(j)',DotRhoScrewGeneration(j)
!	write(6,*) 'DotRhoEdgeAnnihilation(j)',DotRhoEdgeAnnihilation(j)
!	write(6,*) 'DotRhoScrewAnnihilation(j)',DotRhoScrewAnnihilation(j)
                                  
    enddo
  enddo

!* Twin volume fraction evolution
j = 0_pInt
do f = 1,lattice_maxNtwinFamily                                 ! loop over all twin families
   index_myFamily = sum(lattice_NtwinSystem(1:f-1,MyStructure)) ! at which index starts my family
   do i = 1,constitutive_titanmod_Ntwin(f,myInstance)          ! process each (active) twin system in family
      j = j+1_pInt

      !* Resolved shear stress on twin system
      tau_twin(j) = dot_product(Tstar_v,lattice_Stwin_v(:,index_myFamily+i,myStructure))
      !* Stress ratios
      StressRatio_r = (state(g,ip,el)%p(6*ns+3*nt+j)/tau_twin(j))**constitutive_titanmod_r(myInstance)
      
      !* Shear rates and their derivatives due to twin
      if ( tau_twin(j) > 0.0_pReal ) then
        constitutive_titanmod_dotState(2*ns+j) = &
          (constitutive_titanmod_MaxTwinFraction(myInstance)-sumf)*&
          state(g,ip,el)%p(6*ns+4*nt+j)*constitutive_titanmod_Ndot0PerTwinSystem(f,myInstance)*exp(-StressRatio_r) 
      endif
   enddo
enddo

!write(6,*) '#DOTSTATE#'
!write(6,*)
!write(6,'(a,/,4(3(f30.20,x)/))') 'tau slip',tau_slip
!write(6,'(a,/,4(3(f30.20,x)/))') 'gamma slip',gdot_slip
!write(6,'(a,/,4(3(f30.20,x)/))') 'rho_edge',state(g,ip,el)%p(1:ns)
!write(6,'(a,/,4(3(f30.20,x)/))') 'Threshold Slip Edge', state(g,ip,el)%p(5*ns+3*nt+1:6*ns+3*nt)
!write(6,'(a,/,4(3(f30.20,x)/))') 'Threshold Slip Screw', state(g,ip,el)%p(6*ns+3*nt+1:7*ns+3*nt)
!write(6,'(a,/,4(3(f30.20,x)/))') 'EdgeGeneration',DotRhoEdgeGeneration
!write(6,'(a,/,4(3(f30.20,x)/))') 'ScrewGeneration',DotRhoScrewGeneration
!write(6,'(a,/,4(3(f30.20,x)/))') 'EdgeAnnihilation',DotRhoEdgeAnnihilation
!write(6,'(a,/,4(3(f30.20,x)/))') 'ScrewAnnihilation',DotRhoScrewAnnihilation
!write(6,'(a,/,4(3(f30.20,x)/))') 'DipClimb',DotRhoEdgeDipClimb 

return
end function


pure function constitutive_titanmod_dotTemperature(Tstar_v,Temperature,state,g,ip,el)
!*********************************************************************
!* rate of change of microstructure                                  *
!* INPUT:                                                            *
!*  - Temperature     : temperature                                  *
!*  - Tstar_v         : 2nd Piola Kirchhoff stress tensor (Mandel)   *
!*  - ipc             : component-ID at current integration point    *
!*  - ip              : current integration point                    *
!*  - el              : current element                              *
!* OUTPUT:                                                           *
!*  - constitutive_dotTemperature : evolution of Temperature         *
!*********************************************************************
use prec,     only: pReal,pInt,p_vec
use mesh,     only: mesh_NcpElems,mesh_maxNips
use material, only: homogenization_maxNgrains
implicit none

!* Input-Output variables
integer(pInt), intent(in) :: g,ip,el
real(pReal), intent(in) :: Temperature
real(pReal), dimension(6), intent(in) :: Tstar_v
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: state
real(pReal) constitutive_titanmod_dotTemperature

constitutive_titanmod_dotTemperature = 0.0_pReal
    
return
end function


pure function constitutive_titanmod_postResults(Tstar_v,Temperature,dt,state,g,ip,el)
!*********************************************************************
!* return array of constitutive results                              *
!* INPUT:                                                            *
!*  - Temperature     : temperature                                  *
!*  - Tstar_v         : 2nd Piola Kirchhoff stress tensor (Mandel)   *
!*  - dt              : current time increment                       *
!*  - ipc             : component-ID at current integration point    *
!*  - ip              : current integration point                    *
!*  - el              : current element                              *
!*********************************************************************
use prec,     only: pReal,pInt,p_vec
use math,     only: pi
use mesh,     only: mesh_NcpElems,mesh_maxNips
use material, only: homogenization_maxNgrains,material_phase,phase_constitutionInstance,phase_Noutput
use lattice,  only: lattice_Sslip_v,lattice_Stwin_v,lattice_maxNslipFamily,lattice_maxNtwinFamily, &
                    lattice_NslipSystem,lattice_NtwinSystem,lattice_shearTwin  
implicit none

!* Definition of variables
integer(pInt), intent(in) :: g,ip,el
real(pReal), intent(in) :: dt,Temperature
real(pReal), dimension(6), intent(in) :: Tstar_v
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: state
integer(pInt) myInstance,myStructure,ns,nt,f,o,i,c,j,index_myFamily
real(pReal) sumf,tau,StressRatio_p,StressRatio_pminus1,BoltzmannRatio,DotGamma0,StressRatio_r,gdot_slip,dgdot_dtauslip
real(pReal), dimension(constitutive_titanmod_sizePostResults(phase_constitutionInstance(material_phase(g,ip,el)))) :: &
constitutive_titanmod_postResults

!* Shortened notation
myInstance  = phase_constitutionInstance(material_phase(g,ip,el))
myStructure = constitutive_titanmod_structure(myInstance) 
ns = constitutive_titanmod_totalNslip(myInstance)
nt = constitutive_titanmod_totalNtwin(myInstance)

!* Total twin volume fraction
sumf = sum(state(g,ip,el)%p((2*ns+1):(2*ns+nt))) ! safe for nt == 0

!* Required output 
c = 0_pInt
constitutive_titanmod_postResults = 0.0_pReal

do o = 1,phase_Noutput(material_phase(g,ip,el))
   select case(constitutive_titanmod_output(o,myInstance))

     case ('rhoedge')
       constitutive_titanmod_postResults(c+1:c+ns) = state(g,ip,el)%p(1:ns)
       c = c + ns
     case ('rhoscrew')
       constitutive_titanmod_postResults(c+1:c+ns) = state(g,ip,el)%p(ns+1:2*ns)
       c = c + ns
     case ('shear_rate_slip')
       j = 0_pInt
       do f = 1,lattice_maxNslipFamily                                 ! loop over all slip families
          index_myFamily = sum(lattice_NslipSystem(1:f-1,myStructure)) ! at which index starts my family
          do i = 1,constitutive_titanmod_Nslip(f,myInstance)          ! process each (active) slip system in family
             j = j + 1_pInt

             !* Resolved shear stress on slip system
             tau = dot_product(Tstar_v,lattice_Sslip_v(:,index_myFamily+i,myStructure)) 
             !* Stress ratios
             StressRatio_p = (abs(tau)/state(g,ip,el)%p(5*ns+3*nt+j))**constitutive_titanmod_pe_PerSlipSystem(j,myInstance)
             StressRatio_pminus1 = (abs(tau)/state(g,ip,el)%p(5*ns+3*nt+j))**(constitutive_titanmod_pe_PerSlipSystem(j,myInstance)-1.0_pReal)
             !* Boltzmann ratio
             BoltzmannRatio = constitutive_titanmod_f0_PerSlipSystem(j,myInstance)/(kB*Temperature)
             !* Initial shear rates
             DotGamma0 = &
               state(g,ip,el)%p(j)*constitutive_titanmod_burgersPerSlipSystem(f,myInstance)* &
               constitutive_titanmod_v0e_PerSlipSystem(f,myInstance)
       
             !* Shear rates due to slip
             constitutive_titanmod_postResults(c+j) = &
               DotGamma0*exp(-BoltzmannRatio*(1-StressRatio_p)**constitutive_titanmod_qe_PerSlipSystem(j,myInstance))* &
				sign(1.0_pReal,tau)
       enddo ; enddo
	   
!		invLambdaSlipe', &
!		'invLambdaSlips', &
!		'etauSlipThreshold', &
!        'stauSlipThreshold', &
!        'invLambdaSlipTwin
	   
       c = c + ns
     case ('edgesegment')
       constitutive_titanmod_postResults(c+1:c+ns) = state(g,ip,el)%p((4*ns+2*nt+1):(5*ns+2*nt))
       c = c + ns
     case ('screwsegment')
       j = 0_pInt
       do f = 1,lattice_maxNslipFamily                                 
          index_myFamily = sum(lattice_NslipSystem(1:f-1,myStructure)) 
          do i = 1,constitutive_titanmod_Nslip(f,myInstance)          
             j = j + 1_pInt
             constitutive_titanmod_postResults(c+j) = dot_product(Tstar_v,lattice_Sslip_v(:,index_myFamily+i,myStructure))
       enddo; enddo
       c = c + ns
     case ('edgeresistance')
       constitutive_titanmod_postResults(c+1:c+ns) = state(g,ip,el)%p((5*ns+3*nt+1):(6*ns+3*nt))
       c = c + ns
	 case ('screwresistance')
       constitutive_titanmod_postResults(c+1:c+ns) = state(g,ip,el)%p((6*ns+3*nt+1):(6*ns+3*nt))
       c = c + ns
     case ('twin_fraction')
       constitutive_titanmod_postResults(c+1:c+nt) = state(g,ip,el)%p((2*ns+1):(2*ns+nt))
       c = c + nt
     case ('shear_rate_twin')
       if (nt > 0_pInt) then 
         j = 0_pInt
         do f = 1,lattice_maxNtwinFamily                                 
           index_myFamily = sum(lattice_NtwinSystem(1:f-1,myStructure)) 
           do i = 1,constitutive_titanmod_Ntwin(f,myInstance)          
             j = j + 1_pInt

             !* Resolved shear stress on twin system
             tau = dot_product(Tstar_v,lattice_Stwin_v(:,index_myFamily+i,myStructure))
             !* Stress ratios
             StressRatio_r = (state(g,ip,el)%p(6*ns+3*nt+j)/tau)**constitutive_titanmod_r(myInstance)

             !* Shear rates and their derivatives due to twin
             if ( tau > 0.0_pReal ) then
               constitutive_titanmod_postResults(c+j) = &
                 (constitutive_titanmod_MaxTwinFraction(myInstance)-sumf)*&
                 state(g,ip,el)%p(6*ns+4*nt+j)*constitutive_titanmod_Ndot0PerTwinSystem(f,myInstance)*exp(-StressRatio_r)
             endif

         enddo ; enddo
       endif
       c = c + nt
     case ('mfp_twin')
       constitutive_titanmod_postResults(c+1:c+nt) = state(g,ip,el)%p((5*ns+2*nt+1):(5*ns+3*nt))
       c = c + nt
     case ('resolved_stress_twin')
       if (nt > 0_pInt) then
         j = 0_pInt
         do f = 1,lattice_maxNtwinFamily                                 ! loop over all slip families
           index_myFamily = sum(lattice_NtwinSystem(1:f-1,myStructure)) ! at which index starts my family
           do i = 1,constitutive_titanmod_Ntwin(f,myInstance)          ! process each (active) slip system in family
             j = j + 1_pInt
             constitutive_titanmod_postResults(c+j) = dot_product(Tstar_v,lattice_Stwin_v(:,index_myFamily+i,myStructure))
         enddo; enddo
       endif
       c = c + nt
     case ('threshold_stress_twin')
       constitutive_titanmod_postResults(c+1:c+nt) = state(g,ip,el)%p((6*ns+3*nt+1):(6*ns+4*nt))
       c = c + nt

   end select
enddo

return
end function

END MODULE
