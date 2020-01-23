!--------------------------------------------------------------------------------------------------
!> @author Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @brief holds some global variables and gets extra information for commercial FEM
!--------------------------------------------------------------------------------------------------
module FEsolving
  use prec
  use IO
  use DAMASK_interface
   
  implicit none
  private
 
  logical, public :: &
    terminallyIll     = .false.                                                                     !< at least one material point is terminally ill

  integer, dimension(:,:), allocatable, public :: &
    FEsolving_execIP                                                                                !< for ping-pong scheme always range to max IP, otherwise one specific IP
  integer, dimension(2),                public :: &
    FEsolving_execElem                                                                              !< for ping-pong scheme always whole range, otherwise one specific element
    
#if defined(Marc4DAMASK) || defined(Abaqus)
  logical, public, protected :: & 
    symmetricSolver   = .false.                                                                     !< use a symmetric FEM solver
  logical, dimension(:,:), allocatable, public :: &
    calcMode                                                                                        !< do calculation or simply collect when using ping pong scheme

  public :: FE_init
#endif

contains

#if defined(Marc4DAMASK) || defined(Abaqus)
!--------------------------------------------------------------------------------------------------
!> @brief determine whether a symmetric solver is used
!--------------------------------------------------------------------------------------------------
subroutine FE_init

  write(6,'(/,a)')   ' <<<+-  FEsolving init  -+>>>'
  
#if defined(Marc4DAMASK)
  block
    character(len=pStringLen) :: line
    integer :: myStat,fileUnit
    integer, allocatable, dimension(:) :: chunkPos
    open(newunit=fileUnit, file=getSolverJobName()//INPUTFILEEXTENSION, &
         status='old', position='rewind', action='read',iostat=myStat)
    do
      read (fileUnit,'(A)',END=100) line
      if(index(trim(lc(line)),'solver') == 1) then
        read (fileUnit,'(A)',END=100) line                                                          ! next line
        chunkPos = IO_stringPos(line)
        symmetricSolver = (IO_intValue(line,chunkPos,2) /= 1)
      endif
    enddo
100 close(fileUnit)
  end block
  contains

  !--------------------------------------------------------------------------------------------------
  !> @brief changes characters in string to lower case
  !> @details copied from IO_lc
  !--------------------------------------------------------------------------------------------------
  function lc(string)

    character(len=*), intent(in) :: string                                                            !< string to convert
    character(len=len(string))   :: lc

    character(26), parameter :: LOWER = 'abcdefghijklmnopqrstuvwxyz'
    character(26), parameter :: UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

    integer                  :: i,n

    do i=1,len(string)
      lc(i:i) = string(i:i)
      n = index(UPPER,lc(i:i))
      if (n/=0) lc(i:i) = LOWER(n:n)
    enddo
  end function lc

#endif

end subroutine FE_init
#endif


end module FEsolving
