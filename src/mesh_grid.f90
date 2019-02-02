!--------------------------------------------------------------------------------------------------
!> @author Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> @author Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @author Christoph Koords, Max-Planck-Institut für Eisenforschung GmbH
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief Sets up the mesh for the solvers MSC.Marc, Abaqus and the spectral solver
!--------------------------------------------------------------------------------------------------
module mesh
 use, intrinsic :: iso_c_binding
 use prec, only: pReal, pInt
 use mesh_base

 implicit none
 private
 integer(pInt), public, protected :: &
   mesh_NcpElems, &                                                                                 !< total number of CP elements in local mesh
   mesh_Nnodes, &                                                                                   !< total number of nodes in mesh
   mesh_Ncellnodes, &                                                                               !< total number of cell nodes in mesh (including duplicates)
   mesh_Ncells, &                                                                                   !< total number of cells in mesh
   mesh_NcellnodesPerElem, &                                                                        !< number of cell nodes per  element
   mesh_maxNipNeighbors, &                                                                          !< max number of IP neighbors in any CP element
   mesh_maxNsharedElems                                                                             !< max number of CP elements sharing a node
!!!! BEGIN DEPRECATED !!!!!
 integer(pInt), public, protected :: &
   mesh_maxNips, &                                                                                  !< max number of IPs in any CP element
   mesh_maxNcellnodes                                                                               !< max number of cell nodes in any CP element
!!!! BEGIN DEPRECATED !!!!!

 integer(pInt), dimension(:), allocatable, private :: &
   microGlobal
 integer(pInt), dimension(:), allocatable, public, protected :: &
   mesh_homogenizationAt, &                                                                         !< homogenization ID of each element
   mesh_microstructureAt                                                                            !< microstructure ID of each element

 integer(pInt), dimension(:,:), allocatable, public, protected :: &
   mesh_element                                                                                !< entryCount and list of elements containing node

 integer(pInt), dimension(:,:,:,:), allocatable, public, protected :: &
   mesh_ipNeighborhood                                                                              !< 6 or less neighboring IPs as [element_num, IP_index, neighbor_index that points to me]

 real(pReal), public, protected :: &
   mesh_unitlength                                                                                  !< physical length of one unit in mesh

 real(pReal), dimension(:,:), allocatable, public :: &
   mesh_node, &                                                                                     !< node x,y,z coordinates (after deformation! ONLY FOR MARC!!!)
   mesh_cellnode                                                                                    !< cell node x,y,z coordinates (after deformation! ONLY FOR MARC!!!)

 real(pReal), dimension(:,:), allocatable, public, protected :: &
   mesh_ipVolume, &                                                                                 !< volume associated with IP (initially!)
   mesh_node0                                                                                       !< node x,y,z coordinates (initially!)

 real(pReal), dimension(:,:,:), allocatable, public, protected :: &
   mesh_ipArea                                                                                      !< area of interface to neighboring IP (initially!)

 real(pReal), dimension(:,:,:), allocatable, public :: &
   mesh_ipCoordinates                                                                               !< IP x,y,z coordinates (after deformation!)

 real(pReal),dimension(:,:,:,:), allocatable, public, protected :: &
   mesh_ipAreaNormal                                                                                !< area normal of interface to neighboring IP (initially!)

 logical, dimension(3), public, parameter :: mesh_periodicSurface = .true.                          !< flag indicating periodic outer surfaces (used for fluxes)

integer(pInt), dimension(:,:), allocatable, private :: &
   mesh_cellnodeParent                                                                              !< cellnode's parent element ID, cellnode's intra-element ID

 integer(pInt),dimension(:,:,:), allocatable, private :: &
   mesh_cell                                                                                        !< cell connectivity for each element,ip/cell

 integer(pInt), dimension(:,:,:), allocatable, private :: &
   FE_nodesAtIP, &                                                                                  !< map IP index to node indices in a specific type of element
   FE_ipNeighbor, &                                                                                 !< +x,-x,+y,-y,+z,-z list of intra-element IPs and(negative) neighbor faces per own IP in a specific type of element
   FE_cell, &                                                                                       !< list of intra-element cell node IDs that constitute the cells in a specific type of element geometry
   FE_cellface                                                                                      !< list of intra-cell cell node IDs that constitute the cell faces of a specific type of cell

 real(pReal), dimension(:,:,:), allocatable, private :: &
   FE_cellnodeParentnodeWeights                                                                     !< list of node weights for the generation of cell nodes

! These definitions should actually reside in the FE-solver specific part (different for MARC/ABAQUS)
! Hence, I suggest to prefix with "FE_"

 integer(pInt), parameter, public :: &
   FE_Nelemtypes = 13_pInt, &
   FE_Ngeomtypes = 10_pInt, &
   FE_Ncelltypes = 4_pInt, &
   FE_maxNnodes = 20_pInt, &
   FE_maxNips = 27_pInt, &
   FE_maxNipNeighbors = 6_pInt, &
   FE_maxmaxNnodesAtIP = 8_pInt, &                                                                  !< max number of (equivalent) nodes attached to an IP
   FE_maxNmatchingNodesPerFace = 4_pInt, &
   FE_maxNfaces = 6_pInt, &
   FE_maxNcellnodes = 64_pInt, &
   FE_maxNcellnodesPerCell = 8_pInt, &
   FE_maxNcellfaces = 6_pInt, &
   FE_maxNcellnodesPerCellface = 4_pInt

 integer(pInt), dimension(FE_Nelemtypes), parameter, public :: FE_geomtype = &                      !< geometry type of particular element type
 int([ &
      1, & ! element   6 (2D 3node 1ip)
      2, & ! element 125 (2D 6node 3ip)
      3, & ! element  11 (2D 4node 4ip)
      4, & ! element  27 (2D 8node 9ip)
      3, & ! element  54 (2D 8node 4ip)
      5, & ! element 134 (3D 4node 1ip)
      6, & ! element 157 (3D 5node 4ip)
      6, & ! element 127 (3D 10node 4ip)
      7, & ! element 136 (3D 6node 6ip)
      8, & ! element 117 (3D 8node 1ip)
      9, & ! element   7 (3D 8node 8ip)
      9, & ! element  57 (3D 20node 8ip)
     10  & ! element  21 (3D 20node 27ip)
  ],pInt)

 integer(pInt), dimension(FE_Ngeomtypes), parameter, public  :: FE_celltype = &                     !< cell type that is used by each geometry type
 int([ &
      1, & ! element   6 (2D 3node 1ip)
      2, & ! element 125 (2D 6node 3ip)
      2, & ! element  11 (2D 4node 4ip)
      2, & ! element  27 (2D 8node 9ip)
      3, & ! element 134 (3D 4node 1ip)
      4, & ! element 127 (3D 10node 4ip)
      4, & ! element 136 (3D 6node 6ip)
      4, & ! element 117 (3D 8node 1ip)
      4, & ! element   7 (3D 8node 8ip)
      4  & ! element  21 (3D 20node 27ip)
  ],pInt)

 integer(pInt), dimension(FE_Ngeomtypes), parameter, public :: FE_dimension = &                     !< dimension of geometry type
 int([ &
      2, & ! element   6 (2D 3node 1ip)
      2, & ! element 125 (2D 6node 3ip)
      2, & ! element  11 (2D 4node 4ip)
      2, & ! element  27 (2D 8node 9ip)
      3, & ! element 134 (3D 4node 1ip)
      3, & ! element 127 (3D 10node 4ip)
      3, & ! element 136 (3D 6node 6ip)
      3, & ! element 117 (3D 8node 1ip)
      3, & ! element   7 (3D 8node 8ip)
      3  & ! element  21 (3D 20node 27ip)
  ],pInt)

 integer(pInt), dimension(FE_Nelemtypes), parameter, public :: FE_Nnodes = &                        !< number of nodes that constitute a specific type of element
 int([ &
      3, & ! element   6 (2D 3node 1ip)
      6, & ! element 125 (2D 6node 3ip)
      4, & ! element  11 (2D 4node 4ip)
      8, & ! element  27 (2D 8node 9ip)
      8, & ! element  54 (2D 8node 4ip)
      4, & ! element 134 (3D 4node 1ip)
      5, & ! element 157 (3D 5node 4ip)
     10, & ! element 127 (3D 10node 4ip)
      6, & ! element 136 (3D 6node 6ip)
      8, & ! element 117 (3D 8node 1ip)
      8, & ! element   7 (3D 8node 8ip)
     20, & ! element  57 (3D 20node 8ip)
     20  & ! element  21 (3D 20node 27ip)
  ],pInt)

 integer(pInt), dimension(FE_Ngeomtypes), parameter, public :: FE_Nfaces = &                        !< number of faces of a specific type of element geometry
 int([ &
      3, & ! element   6 (2D 3node 1ip)
      3, & ! element 125 (2D 6node 3ip)
      4, & ! element  11 (2D 4node 4ip)
      4, & ! element  27 (2D 8node 9ip)
      4, & ! element 134 (3D 4node 1ip)
      4, & ! element 127 (3D 10node 4ip)
      5, & ! element 136 (3D 6node 6ip)
      6, & ! element 117 (3D 8node 1ip)
      6, & ! element   7 (3D 8node 8ip)
      6  & ! element  21 (3D 20node 27ip)
  ],pInt)

 integer(pInt), dimension(FE_Ngeomtypes), parameter, private :: FE_NmatchingNodes = &               !< number of nodes that are needed for face matching in a specific type of element geometry
 int([ &
      3, & ! element   6 (2D 3node 1ip)
      3, & ! element 125 (2D 6node 3ip)
      4, & ! element  11 (2D 4node 4ip)
      4, & ! element  27 (2D 8node 9ip)
      4, & ! element 134 (3D 4node 1ip)
      4, & ! element 127 (3D 10node 4ip)
      6, & ! element 136 (3D 6node 6ip)
      8, & ! element 117 (3D 8node 1ip)
      8, & ! element   7 (3D 8node 8ip)
      8  & ! element  21 (3D 20node 27ip)
  ],pInt)

 integer(pInt), dimension(FE_Ngeomtypes), parameter, private :: FE_Ncellnodes = &                   !< number of cell nodes in a specific geometry type
 int([ &
      3, & ! element   6 (2D 3node 1ip)
      7, & ! element 125 (2D 6node 3ip)
      9, & ! element  11 (2D 4node 4ip)
     16, & ! element  27 (2D 8node 9ip)
      4, & ! element 134 (3D 4node 1ip)
     15, & ! element 127 (3D 10node 4ip)
     21, & ! element 136 (3D 6node 6ip)
      8, & ! element 117 (3D 8node 1ip)
     27, & ! element   7 (3D 8node 8ip)
     64  & ! element  21 (3D 20node 27ip)
  ],pInt)

 integer(pInt), dimension(FE_Ncelltypes), parameter, private :: FE_NcellnodesPerCell = &             !< number of cell nodes in a specific cell type
 int([ &
      3, & ! (2D 3node)
      4, & ! (2D 4node)
      4, & ! (3D 4node)
      8  & ! (3D 8node)
  ],pInt)

 integer(pInt), dimension(FE_Ncelltypes), parameter, private :: FE_NcellnodesPerCellface = &        !< number of cell nodes per cell face in a specific cell type
 int([&
      2, & ! (2D 3node)
      2, & ! (2D 4node)
      3, & ! (3D 4node)
      4  & ! (3D 8node)
  ],pInt)

 integer(pInt), dimension(FE_Ngeomtypes), parameter, public :: FE_Nips = &                          !< number of IPs in a specific type of element
 int([ &
      1, & ! element   6 (2D 3node 1ip)
      3, & ! element 125 (2D 6node 3ip)
      4, & ! element  11 (2D 4node 4ip)
      9, & ! element  27 (2D 8node 9ip)
      1, & ! element 134 (3D 4node 1ip)
      4, & ! element 127 (3D 10node 4ip)
      6, & ! element 136 (3D 6node 6ip)
      1, & ! element 117 (3D 8node 1ip)
      8, & ! element   7 (3D 8node 8ip)
     27  & ! element  21 (3D 20node 27ip)
  ],pInt)

 integer(pInt), dimension(FE_Ncelltypes), parameter, public :: FE_NipNeighbors = &                  !< number of ip neighbors / cell faces in a specific cell type
 int([&
      3, & ! (2D 3node)
      4, & ! (2D 4node)
      4, & ! (3D 4node)
      6  & ! (3D 8node)
  ],pInt)


 integer(pInt), dimension(FE_Ngeomtypes), parameter, private :: FE_maxNnodesAtIP = &                !< maximum number of parent nodes that belong to an IP for a specific type of element
 int([ &
      3, & ! element   6 (2D 3node 1ip)
      1, & ! element 125 (2D 6node 3ip)
      1, & ! element  11 (2D 4node 4ip)
      2, & ! element  27 (2D 8node 9ip)
      4, & ! element 134 (3D 4node 1ip)
      1, & ! element 127 (3D 10node 4ip)
      1, & ! element 136 (3D 6node 6ip)
      8, & ! element 117 (3D 8node 1ip)
      1, & ! element   7 (3D 8node 8ip)
      4  & ! element  21 (3D 20node 27ip)
  ],pInt)


 integer(pInt), dimension(3), public, protected :: &
   grid                                                                                             !< (global) grid
 integer(pInt), public, protected :: &
   mesh_NcpElemsGlobal, &                                                                           !< total number of CP elements in global mesh
   grid3, &                                                                                         !< (local) grid in 3rd direction
   grid3Offset                                                                                      !< (local) grid offset in 3rd direction
 real(pReal), dimension(3), public, protected :: &
   geomSize
 real(pReal), public, protected :: &
   size3, &                                                                                         !< (local) size in 3rd direction
   size3offset                                                                                      !< (local) size offset in 3rd direction

 public :: &
   mesh_init, &
   mesh_cellCenterCoordinates

 private :: &
   mesh_build_cellconnectivity, &
   mesh_build_ipAreas, &
   mesh_build_FEdata, &
   mesh_spectral_getHomogenization, &
   mesh_spectral_build_nodes, &
   mesh_spectral_build_elements, &
   mesh_spectral_build_ipNeighborhood, &
   mesh_build_cellnodes, &
   mesh_build_ipVolumes, &
   mesh_build_ipCoordinates

 type, public, extends(tMesh) :: tMesh_grid
 
  integer(pInt), dimension(3), public :: &
   grid                                                                                             !< (global) grid
 integer(pInt), public :: &
   mesh_NcpElemsGlobal, &                                                                           !< total number of CP elements in global mesh
   grid3, &                                                                                         !< (local) grid in 3rd direction
   grid3Offset                                                                                      !< (local) grid offset in 3rd direction
 real(pReal), dimension(3), public :: &
   geomSize
 real(pReal), public :: &
   size3, &                                                                                         !< (local) size in 3rd direction
   size3offset
   
   contains
   procedure, pass(self) :: tMesh_grid_init
   generic, public :: init => tMesh_grid_init
 end type tMesh_grid
 
 type(tMesh_grid), public, protected :: theMesh
 
contains

subroutine tMesh_grid_init(self,nodes)
 
 implicit none
 class(tMesh_grid) :: self
 real(pReal), dimension(:,:), intent(in) :: nodes
 
 call self%tMesh%init('grid',10_pInt,nodes)
 
end subroutine tMesh_grid_init

!--------------------------------------------------------------------------------------------------
!> @brief initializes the mesh by calling all necessary private routines the mesh module
!! Order and routines strongly depend on type of solver
!--------------------------------------------------------------------------------------------------
subroutine mesh_init(ip,el)
#if defined(__GFORTRAN__) || __INTEL_COMPILER >= 1800
 use, intrinsic :: iso_fortran_env, only: &
   compiler_version, &
   compiler_options
#endif

#include <petsc/finclude/petscsys.h>
 use PETScsys

 use DAMASK_interface
 use IO, only: &
   IO_open_file, &
   IO_error, &
   IO_timeStamp, &
   IO_error, &
   IO_write_jobFile
 use debug, only: &
   debug_e, &
   debug_i, &
   debug_level, &
   debug_mesh, &
   debug_levelBasic
 use numerics, only: &
   numerics_unitlength
 use FEsolving, only: &
   FEsolving_execElem, &
   FEsolving_execIP

 implicit none
 include 'fftw3-mpi.f03'
 integer(C_INTPTR_T) :: devNull, local_K, local_K_offset
 integer :: ierr, worldsize
 integer(pInt), intent(in), optional :: el, ip
 integer(pInt) :: j
 logical :: myDebug

 write(6,'(/,a)')   ' <<<+-  mesh init  -+>>>'
 write(6,'(a15,a)') ' Current time: ',IO_timeStamp()
#include "compilation_info.f90"

 
 call mesh_build_FEdata                                                                             ! get properties of the different types of elements
 mesh_unitlength = numerics_unitlength                                                              ! set physical extent of a length unit in mesh

 myDebug = (iand(debug_level(debug_mesh),debug_levelBasic) /= 0_pInt)

 call fftw_mpi_init()
 call mesh_spectral_read_grid()


 call MPI_comm_size(PETSC_COMM_WORLD, worldsize, ierr)
 if(ierr /=0_pInt) call IO_error(894_pInt, ext_msg='MPI_comm_size')
 if(worldsize>grid(3)) call IO_error(894_pInt, ext_msg='number of processes exceeds grid(3)')


 devNull = fftw_mpi_local_size_3d(int(grid(3),C_INTPTR_T), &
                                  int(grid(2),C_INTPTR_T), &
                                  int(grid(1),C_INTPTR_T)/2+1, &
                                  PETSC_COMM_WORLD, &
                                  local_K, &                                                        ! domain grid size along z
                                  local_K_offset)                                                   ! domain grid offset along z
 grid3       = int(local_K,pInt)
 grid3Offset = int(local_K_offset,pInt)
 size3       = geomSize(3)*real(grid3,pReal)      /real(grid(3),pReal)
 size3Offset = geomSize(3)*real(grid3Offset,pReal)/real(grid(3),pReal)
 mesh_NcpElems= product(grid(1:2))*grid3
 mesh_NcpElemsGlobal = product(grid)

 mesh_Nnodes  = product(grid(1:2) + 1_pInt)*(grid3 + 1_pInt)

 call mesh_spectral_build_nodes()
 if (myDebug) write(6,'(a)') ' Built nodes'; flush(6)

 call theMesh%init(mesh_node)

 ! For compatibility
 mesh_maxNips =         theMesh%elem%nIPs
 mesh_maxNipNeighbors = theMesh%elem%nIPneighbors
 mesh_maxNcellnodes =   theMesh%elem%Ncellnodes

 
 call mesh_spectral_build_elements()

 if (myDebug) write(6,'(a)') ' Built elements'; flush(6)

 call mesh_build_cellconnectivity
 if (myDebug) write(6,'(a)') ' Built cell connectivity'; flush(6)
 mesh_cellnode = mesh_build_cellnodes(mesh_node,mesh_Ncellnodes)
 if (myDebug) write(6,'(a)') ' Built cell nodes'; flush(6)
 call mesh_build_ipCoordinates
 if (myDebug) write(6,'(a)') ' Built IP coordinates'; flush(6)
 call mesh_build_ipVolumes
 if (myDebug) write(6,'(a)') ' Built IP volumes'; flush(6)
 call mesh_build_ipAreas
 if (myDebug) write(6,'(a)') ' Built IP areas'; flush(6)

 call mesh_spectral_build_ipNeighborhood

 if (myDebug) write(6,'(a)') ' Built IP neighborhood'; flush(6)

 if (debug_e < 1 .or. debug_e > mesh_NcpElems) &
   call IO_error(602_pInt,ext_msg='element')                                                        ! selected element does not exist
 if (debug_i < 1 .or. debug_i > FE_Nips(FE_geomtype(mesh_element(2_pInt,debug_e)))) &
   call IO_error(602_pInt,ext_msg='IP')                                                             ! selected element does not have requested IP

 FEsolving_execElem = [ 1_pInt,mesh_NcpElems ]                                                      ! parallel loop bounds set to comprise all DAMASK elements
 allocate(FEsolving_execIP(2_pInt,mesh_NcpElems), source=1_pInt)                                    ! parallel loop bounds set to comprise from first IP...
 forall (j = 1_pInt:mesh_NcpElems) FEsolving_execIP(2,j) = FE_Nips(FE_geomtype(mesh_element(2,j)))  ! ...up to own IP count for each element


!!!! COMPATIBILITY HACK !!!!
! for a homogeneous mesh, all elements have the same number of IPs and and cell nodes.
! hence, xxPerElem instead of maxXX
 mesh_NcellnodesPerElem = mesh_maxNcellnodes
! better name
 mesh_homogenizationAt  = mesh_element(3,:)
 mesh_microstructureAt  = mesh_element(4,:)
!!!!!!!!!!!!!!!!!!!!!!!!
 call theMesh%setNelems(mesh_NcpElems)
end subroutine mesh_init

!--------------------------------------------------------------------------------------------------
!> @brief Split CP elements into cells.
!> @details Build a mapping between cells and the corresponding cell nodes ('mesh_cell').
!> Cell nodes that are also matching nodes are unique in the list of cell nodes,
!> all others (currently) might be stored more than once.
!> Also allocates the 'mesh_node' array.
!--------------------------------------------------------------------------------------------------
subroutine mesh_build_cellconnectivity

 implicit none
 integer(pInt), dimension(:), allocatable :: &
   matchingNode2cellnode
 integer(pInt), dimension(:,:), allocatable :: &
   cellnodeParent
 integer(pInt), dimension(mesh_maxNcellnodes) :: &
   localCellnode2globalCellnode
 integer(pInt) :: &
   e,t,g,c,n,i, &
   matchingNodeID, &
   localCellnodeID

 allocate(mesh_cell(FE_maxNcellnodesPerCell,mesh_maxNips,mesh_NcpElems), source=0_pInt)
 allocate(matchingNode2cellnode(mesh_Nnodes),                            source=0_pInt)
 allocate(cellnodeParent(2_pInt,mesh_maxNcellnodes*mesh_NcpElems),       source=0_pInt)

!--------------------------------------------------------------------------------------------------
! Count cell nodes (including duplicates) and generate cell connectivity list
 mesh_Ncellnodes = 0_pInt
 mesh_Ncells = 0_pInt
 do e = 1_pInt,mesh_NcpElems                                                                        ! loop over cpElems
   t = mesh_element(2_pInt,e)                                                                       ! get element type
   g = FE_geomtype(t)                                                                               ! get geometry type
   c = FE_celltype(g)                                                                               ! get cell type
   localCellnode2globalCellnode = 0_pInt
   mesh_Ncells = mesh_Ncells + FE_Nips(g)
   do i = 1_pInt,FE_Nips(g)                                                                         ! loop over ips=cells in this element
     do n = 1_pInt,FE_NcellnodesPerCell(c)                                                          ! loop over cell nodes in this cell
       localCellnodeID = FE_cell(n,i,g)
       if (localCellnodeID <= FE_NmatchingNodes(g)) then                                            ! this cell node is a matching node
         matchingNodeID = mesh_element(4_pInt+localCellnodeID,e)
         if (matchingNode2cellnode(matchingNodeID) == 0_pInt) then                                  ! if this matching node does not yet exist in the glbal cell node list ...
           mesh_Ncellnodes = mesh_Ncellnodes + 1_pInt                                               ! ... count it as cell node ...
           matchingNode2cellnode(matchingNodeID) = mesh_Ncellnodes                                  ! ... and remember its global ID
           cellnodeParent(1_pInt,mesh_Ncellnodes) = e                                               ! ... and where it belongs to
           cellnodeParent(2_pInt,mesh_Ncellnodes) = localCellnodeID
         endif
         mesh_cell(n,i,e) = matchingNode2cellnode(matchingNodeID)
       else                                                                                         ! this cell node is no matching node
         if (localCellnode2globalCellnode(localCellnodeID) == 0_pInt) then                          ! if this local cell node does not yet exist in the  global cell node list ...
           mesh_Ncellnodes = mesh_Ncellnodes + 1_pInt                                               ! ... count it as cell node ...
           localCellnode2globalCellnode(localCellnodeID) = mesh_Ncellnodes                          ! ... and remember its global ID ...
           cellnodeParent(1_pInt,mesh_Ncellnodes) = e                                               ! ... and it belongs to
           cellnodeParent(2_pInt,mesh_Ncellnodes) = localCellnodeID
         endif
         mesh_cell(n,i,e) = localCellnode2globalCellnode(localCellnodeID)
       endif
     enddo
   enddo
 enddo

 allocate(mesh_cellnodeParent(2_pInt,mesh_Ncellnodes))
 allocate(mesh_cellnode(3_pInt,mesh_Ncellnodes))
 forall(n = 1_pInt:mesh_Ncellnodes)
   mesh_cellnodeParent(1,n) = cellnodeParent(1,n)
   mesh_cellnodeParent(2,n) = cellnodeParent(2,n)
 endforall

end subroutine mesh_build_cellconnectivity


!--------------------------------------------------------------------------------------------------
!> @brief Calculate position of cellnodes from the given position of nodes
!> Build list of cellnodes' coordinates.
!> Cellnode coordinates are calculated from a weighted sum of node coordinates.
!--------------------------------------------------------------------------------------------------
function mesh_build_cellnodes(nodes,Ncellnodes)

 implicit none
 integer(pInt),                         intent(in) :: Ncellnodes                                    !< requested number of cellnodes
 real(pReal), dimension(3,mesh_Nnodes), intent(in) :: nodes
 real(pReal), dimension(3,Ncellnodes) :: mesh_build_cellnodes

 integer(pInt) :: &
   e,t,n,m, &
   localCellnodeID
 real(pReal), dimension(3) :: &
   myCoords

 mesh_build_cellnodes = 0.0_pReal
!$OMP PARALLEL DO PRIVATE(e,localCellnodeID,t,myCoords)
 do n = 1_pInt,Ncellnodes                                                                           ! loop over cell nodes
   e = mesh_cellnodeParent(1,n)
   localCellnodeID = mesh_cellnodeParent(2,n)
   t = mesh_element(2,e)                                                                            ! get element type
   myCoords = 0.0_pReal
   do m = 1_pInt,FE_Nnodes(t)
     myCoords = myCoords + nodes(1:3,mesh_element(4_pInt+m,e)) &
                         * FE_cellnodeParentnodeWeights(m,localCellnodeID,t)
   enddo
   mesh_build_cellnodes(1:3,n) = myCoords / sum(FE_cellnodeParentnodeWeights(:,localCellnodeID,t))
 enddo
!$OMP END PARALLEL DO

end function mesh_build_cellnodes


!--------------------------------------------------------------------------------------------------
!> @brief Calculates IP volume. Allocates global array 'mesh_ipVolume'
!> @details The IP volume is calculated differently depending on the cell type.
!> 2D cells assume an element depth of one in order to calculate the volume.
!> For the hexahedral cell we subdivide the cell into subvolumes of pyramidal
!> shape with a cell face as basis and the central ip at the tip. This subvolume is
!> calculated as an average of four tetrahedals with three corners on the cell face
!> and one corner at the central ip.
!--------------------------------------------------------------------------------------------------
subroutine mesh_build_ipVolumes
 use math, only: &
   math_volTetrahedron, &
   math_areaTriangle

 implicit none
 integer(pInt) ::                                e,t,g,c,i,m,f,n
 real(pReal), dimension(FE_maxNcellnodesPerCellface,FE_maxNcellfaces) :: subvolume


 allocate(mesh_ipVolume(mesh_maxNips,mesh_NcpElems),source=0.0_pReal)


 !$OMP PARALLEL DO PRIVATE(t,g,c,m,subvolume)
   do e = 1_pInt,mesh_NcpElems                                                                      ! loop over cpElems
     t = mesh_element(2_pInt,e)                                                                     ! get element type
     g = FE_geomtype(t)                                                                             ! get geometry type
     c = FE_celltype(g)                                                                             ! get cell type
     select case (c)

       case (1_pInt)                                                                                ! 2D 3node
         forall (i = 1_pInt:FE_Nips(g)) &                                                           ! loop over ips=cells in this element
           mesh_ipVolume(i,e) = math_areaTriangle(mesh_cellnode(1:3,mesh_cell(1,i,e)), &
                                                  mesh_cellnode(1:3,mesh_cell(2,i,e)), &
                                                  mesh_cellnode(1:3,mesh_cell(3,i,e)))

       case (2_pInt)                                                                                ! 2D 4node
         forall (i = 1_pInt:FE_Nips(g)) &                                                           ! loop over ips=cells in this element
           mesh_ipVolume(i,e) = math_areaTriangle(mesh_cellnode(1:3,mesh_cell(1,i,e)), &            ! here we assume a planar shape, so division in two triangles suffices
                                                  mesh_cellnode(1:3,mesh_cell(2,i,e)), &
                                                  mesh_cellnode(1:3,mesh_cell(3,i,e))) &
                              + math_areaTriangle(mesh_cellnode(1:3,mesh_cell(3,i,e)), &
                                                  mesh_cellnode(1:3,mesh_cell(4,i,e)), &
                                                  mesh_cellnode(1:3,mesh_cell(1,i,e)))

       case (3_pInt)                                                                                ! 3D 4node
         forall (i = 1_pInt:FE_Nips(g)) &                                                           ! loop over ips=cells in this element
           mesh_ipVolume(i,e) = math_volTetrahedron(mesh_cellnode(1:3,mesh_cell(1,i,e)), &
                                                    mesh_cellnode(1:3,mesh_cell(2,i,e)), &
                                                    mesh_cellnode(1:3,mesh_cell(3,i,e)), &
                                                    mesh_cellnode(1:3,mesh_cell(4,i,e)))

       case (4_pInt)                                                                                ! 3D 8node
         m = FE_NcellnodesPerCellface(c)
         do i = 1_pInt,FE_Nips(g)                                                                   ! loop over ips=cells in this element
           subvolume = 0.0_pReal
           forall(f = 1_pInt:FE_NipNeighbors(c), n = 1_pInt:FE_NcellnodesPerCellface(c)) &
             subvolume(n,f) = math_volTetrahedron(&
                                mesh_cellnode(1:3,mesh_cell(FE_cellface(      n     ,f,c),i,e)), &
                                mesh_cellnode(1:3,mesh_cell(FE_cellface(1+mod(n  ,m),f,c),i,e)), &
                                mesh_cellnode(1:3,mesh_cell(FE_cellface(1+mod(n+1,m),f,c),i,e)), &
                                mesh_ipCoordinates(1:3,i,e))
           mesh_ipVolume(i,e) = 0.5_pReal * sum(subvolume)                                         ! each subvolume is based on four tetrahedrons, altough the face consists of only two triangles -> averaging factor two
         enddo

     end select
   enddo
 !$OMP END PARALLEL DO

end subroutine mesh_build_ipVolumes


!--------------------------------------------------------------------------------------------------
!> @brief Calculates IP Coordinates. Allocates global array 'mesh_ipCoordinates'
! Called by all solvers in mesh_init in order to initialize the ip coordinates.
! Later on the current ip coordinates are directly prvided by the spectral solver and by Abaqus,
! so no need to use this subroutine anymore; Marc however only provides nodal displacements,
! so in this case the ip coordinates are always calculated on the basis of this subroutine.
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! FOR THE MOMENT THIS SUBROUTINE ACTUALLY CALCULATES THE CELL CENTER AND NOT THE IP COORDINATES,
! AS THE IP IS NOT (ALWAYS) LOCATED IN THE CENTER OF THE IP VOLUME.
! HAS TO BE CHANGED IN A LATER VERSION.
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!--------------------------------------------------------------------------------------------------
subroutine mesh_build_ipCoordinates

 implicit none
 integer(pInt) :: e,t,g,c,i,n
 real(pReal), dimension(3) :: myCoords

 if (.not. allocated(mesh_ipCoordinates)) &
   allocate(mesh_ipCoordinates(3,mesh_maxNips,mesh_NcpElems),source=0.0_pReal)

 !$OMP PARALLEL DO PRIVATE(t,g,c,myCoords)
 do e = 1_pInt,mesh_NcpElems                                                                        ! loop over cpElems
   t = mesh_element(2_pInt,e)                                                                       ! get element type
   g = FE_geomtype(t)                                                                               ! get geometry type
   c = FE_celltype(g)                                                                               ! get cell type
   do i = 1_pInt,FE_Nips(g)                                                                         ! loop over ips=cells in this element
     myCoords = 0.0_pReal
     do n = 1_pInt,FE_NcellnodesPerCell(c)                                                          ! loop over cell nodes in this cell
       myCoords = myCoords + mesh_cellnode(1:3,mesh_cell(n,i,e))
     enddo
     mesh_ipCoordinates(1:3,i,e) = myCoords / real(FE_NcellnodesPerCell(c),pReal)
   enddo
 enddo
 !$OMP END PARALLEL DO

end subroutine mesh_build_ipCoordinates


!--------------------------------------------------------------------------------------------------
!> @brief Calculates cell center coordinates.
!--------------------------------------------------------------------------------------------------
pure function mesh_cellCenterCoordinates(ip,el)

 implicit none
 integer(pInt), intent(in) :: el, &                                                                  !< element number
                              ip                                                                     !< integration point number
 real(pReal), dimension(3) :: mesh_cellCenterCoordinates                                             !< x,y,z coordinates of the cell center of the requested IP cell
 integer(pInt) :: t,g,c,n

 t = mesh_element(2_pInt,el)                                                                         ! get element type
 g = FE_geomtype(t)                                                                                  ! get geometry type
 c = FE_celltype(g)                                                                                  ! get cell type
 mesh_cellCenterCoordinates = 0.0_pReal
 do n = 1_pInt,FE_NcellnodesPerCell(c)                                                               ! loop over cell nodes in this cell
   mesh_cellCenterCoordinates = mesh_cellCenterCoordinates + mesh_cellnode(1:3,mesh_cell(n,ip,el))
 enddo
 mesh_cellCenterCoordinates = mesh_cellCenterCoordinates / real(FE_NcellnodesPerCell(c),pReal)

end function mesh_cellCenterCoordinates


!--------------------------------------------------------------------------------------------------
!> @brief Parses geometry file
!> @details important variables have an implicit "save" attribute. Therefore, this function is 
! supposed to be called only once!
!--------------------------------------------------------------------------------------------------
subroutine mesh_spectral_read_grid()
 use IO, only: &
   IO_stringPos, &
   IO_lc, &
   IO_stringValue, &
   IO_intValue, &
   IO_floatValue, &
   IO_error
 use DAMASK_interface, only: &
   geometryFile

  implicit none
  character(len=:),            allocatable :: rawData
  character(len=65536)                     :: line
  integer(pInt), allocatable, dimension(:) :: chunkPos
  integer(pInt), dimension(3) :: g = -1_pInt
  real(pReal), dimension(3) :: s = -1_pInt
  integer(pInt) :: h =- 1_pInt
  integer(pInt) ::  &
    headerLength = -1_pInt, &                                                                       !< length of header (in lines)
    fileLength, &                                                                                   !< lenght of the geom file (in characters)
    fileUnit, &
    startPos, endPos, &
    myStat, &
    l, &                                                                                            !< line counter
    c, &                                                                                            !< counter for # microstructures in line
    o, &                                                                                            !< order of "to" packing
    e, &                                                                                            !< "element", i.e. spectral collocation point 
    i, j
  logical :: &
    gotGrid = .false., &
    gotSize = .false., &
    gotHomogenization = .false.

!--------------------------------------------------------------------------------------------------
! read data as stream
  inquire(file = trim(geometryFile), size=fileLength)
  open(newunit=fileUnit, file=trim(geometryFile), access='stream',&
       status='old', position='rewind', action='read',iostat=myStat)
  if(myStat /= 0_pInt) call IO_error(100_pInt,ext_msg=trim(geometryFile))
  allocate(character(len=fileLength)::rawData)
  read(fileUnit) rawData
  close(fileUnit)
  
!--------------------------------------------------------------------------------------------------
! get header length
  endPos = index(rawData,new_line(''))
  if(endPos <= index(rawData,'head')) then
    call IO_error(error_ID=841_pInt, ext_msg='mesh_spectral_read_grid')
  else
    chunkPos = IO_stringPos(rawData(1:endPos))
    if (chunkPos(1) < 2_pInt) call IO_error(error_ID=841_pInt, ext_msg='mesh_spectral_read_grid')
    headerLength = IO_intValue(rawData(1:endPos),chunkPos,1_pInt)
    startPos = endPos + 1_pInt
  endif

!--------------------------------------------------------------------------------------------------
! read and interprete header
  l = 0
  do while (l < headerLength .and. startPos < len(rawData))
    endPos = startPos + index(rawData(startPos:),new_line('')) - 1_pInt
    line = rawData(startPos:endPos)
    startPos = endPos + 1_pInt
    l = l + 1_pInt

   ! cycle empty lines
    chunkPos = IO_stringPos(trim(line))
    select case ( IO_lc(IO_StringValue(trim(line),chunkPos,1_pInt,.true.)) )
    
      case ('grid')
        if (chunkPos(1) > 6) gotGrid = .true.
        do j = 2_pInt,6_pInt,2_pInt
          select case (IO_lc(IO_stringValue(line,chunkPos,j)))
            case('a')
              g(1) = IO_intValue(line,chunkPos,j+1_pInt)
            case('b')
              g(2) = IO_intValue(line,chunkPos,j+1_pInt)
            case('c')
              g(3) = IO_intValue(line,chunkPos,j+1_pInt)
          end select
        enddo
        
      case ('size')
        if (chunkPos(1) > 6) gotSize = .true.
        do j = 2_pInt,6_pInt,2_pInt
          select case (IO_lc(IO_stringValue(line,chunkPos,j)))
            case('x')
              s(1) = IO_floatValue(line,chunkPos,j+1_pInt)
            case('y')
              s(2) = IO_floatValue(line,chunkPos,j+1_pInt)
            case('z')
              s(3) = IO_floatValue(line,chunkPos,j+1_pInt)
          end select
        enddo
        
      case ('homogenization')
        if (chunkPos(1) > 1) gotHomogenization = .true.
        h = IO_intValue(line,chunkPos,2_pInt)

    end select

  enddo

!--------------------------------------------------------------------------------------------------
! global data
  grid = g
  geomSize = s
  allocate(microGlobal(product(grid)), source = -1_pInt)
     
!--------------------------------------------------------------------------------------------------
! read and interprete content
  e = 1_pInt
  do while (startPos < len(rawData))
    endPos = startPos + index(rawData(startPos:),new_line('')) - 1_pInt
    line = rawData(startPos:endPos)
    startPos = endPos + 1_pInt
    l = l + 1_pInt

    chunkPos = IO_stringPos(trim(line))
    if (chunkPos(1) == 3) then
      if (IO_lc(IO_stringValue(line,chunkPos,2))  == 'of') then
        c = IO_intValue(line,chunkPos,1)
        microGlobal(e:e+c-1_pInt) = [(IO_intValue(line,chunkPos,3),i = 1_pInt,IO_intValue(line,chunkPos,1))]
      else if (IO_lc(IO_stringValue(line,chunkPos,2))  == 'to') then
        c = abs(IO_intValue(line,chunkPos,3) - IO_intValue(line,chunkPos,1)) + 1_pInt
        o = merge(+1_pInt, -1_pInt, IO_intValue(line,chunkPos,3) > IO_intValue(line,chunkPos,1))
        microGlobal(e:e+c-1_pInt) = [(i, i = IO_intValue(line,chunkPos,1),IO_intValue(line,chunkPos,3),o)]
      else
        c = chunkPos(1)
        do i = 0_pInt, c - 1_pInt
          microGlobal(e+i) =  IO_intValue(line,chunkPos,i+1_pInt)
        enddo
      endif
    else
      c = chunkPos(1)
      do i = 0_pInt, c - 1_pInt
        microGlobal(e+i) =  IO_intValue(line,chunkPos,i+1_pInt)
      enddo

    endif
    e = e+c
  end do

  if (e-1 /= product(grid)) print*, 'mist', e

! if (.not. gotGrid) &
!   call IO_error(error_ID = 845_pInt, ext_msg='grid')
! if(any(mesh_spectral_getGrid < 1_pInt)) &
!   call IO_error(error_ID = 843_pInt, ext_msg='mesh_spectral_getGrid')
   
!    if (.not. gotSize) &
!   call IO_error(error_ID = 845_pInt, ext_msg='size')
! if (any(mesh_spectral_getSize<=0.0_pReal)) &
!   call IO_error(error_ID = 844_pInt, ext_msg='mesh_spectral_getSize')
   
!    if (.not. gotHomogenization ) &
!   call IO_error(error_ID = 845_pInt, ext_msg='homogenization')
! if (mesh_spectral_getHomogenization<1_pInt) &
!   call IO_error(error_ID = 842_pInt, ext_msg='mesh_spectral_getHomogenization')
   
end subroutine mesh_spectral_read_grid


!--------------------------------------------------------------------------------------------------
!> @brief Reads homogenization information from geometry file.
!--------------------------------------------------------------------------------------------------
integer(pInt) function mesh_spectral_getHomogenization()
 use IO, only: &
   IO_checkAndRewind, &
   IO_open_file, &
   IO_stringPos, &
   IO_lc, &
   IO_stringValue, &
   IO_intValue, &
   IO_error
 use DAMASK_interface, only: &
   geometryFile

 implicit none
 integer(pInt), allocatable, dimension(:)         :: chunkPos
 integer(pInt)                                    :: headerLength = 0_pInt
 character(len=1024) :: line, &
                        keyword
 integer(pInt) :: i, myFileUnit
 logical :: gotHomogenization = .false.


   myFileUnit = 289_pInt
   call IO_open_file(myFileUnit,trim(geometryFile))


 call IO_checkAndRewind(myFileUnit)

 read(myFileUnit,'(a1024)') line
 chunkPos = IO_stringPos(line)
 keyword = IO_lc(IO_StringValue(line,chunkPos,2_pInt,.true.))
 if (keyword(1:4) == 'head') then
   headerLength = IO_intValue(line,chunkPos,1_pInt) + 1_pInt
 else
   call IO_error(error_ID=841_pInt, ext_msg='mesh_spectral_getHomogenization')
 endif
 rewind(myFileUnit)
 do i = 1_pInt, headerLength
   read(myFileUnit,'(a1024)') line
   chunkPos = IO_stringPos(line)
   select case ( IO_lc(IO_StringValue(line,chunkPos,1,.true.)) )
     case ('homogenization')
       gotHomogenization = .true.
       mesh_spectral_getHomogenization = IO_intValue(line,chunkPos,2_pInt)
   end select
 enddo

 close(myFileUnit)

 if (.not. gotHomogenization ) &
   call IO_error(error_ID = 845_pInt, ext_msg='homogenization')
 if (mesh_spectral_getHomogenization<1_pInt) &
   call IO_error(error_ID = 842_pInt, ext_msg='mesh_spectral_getHomogenization')

end function mesh_spectral_getHomogenization


!--------------------------------------------------------------------------------------------------
!> @brief Store x,y,z coordinates of all nodes in mesh.
!! Allocates global arrays 'mesh_node0' and 'mesh_node'
!--------------------------------------------------------------------------------------------------
subroutine mesh_spectral_build_nodes()

 implicit none
 integer(pInt) :: n

 allocate (mesh_node0 (3,mesh_Nnodes), source = 0.0_pReal)

 forall (n = 0_pInt:mesh_Nnodes-1_pInt)
   mesh_node0(1,n+1_pInt) = mesh_unitlength * &
           geomSize(1)*real(mod(n,(grid(1)+1_pInt) ),pReal) &
                                                  / real(grid(1),pReal)
   mesh_node0(2,n+1_pInt) = mesh_unitlength * &
           geomSize(2)*real(mod(n/(grid(1)+1_pInt),(grid(2)+1_pInt)),pReal) &
                                                  / real(grid(2),pReal)
   mesh_node0(3,n+1_pInt) = mesh_unitlength * &
           size3*real(mod(n/(grid(1)+1_pInt)/(grid(2)+1_pInt),(grid3+1_pInt)),pReal) &
                                                  / real(grid3,pReal) + &
           size3offset
 end forall

 mesh_node = mesh_node0

end subroutine mesh_spectral_build_nodes


!--------------------------------------------------------------------------------------------------
!> @brief Store FEid, type, material, texture, and node list per element.
!! Allocates global array 'mesh_element'
!> @todo does the IO_error makes sense?
!--------------------------------------------------------------------------------------------------
subroutine mesh_spectral_build_elements()
 use IO, only: &
   IO_error
 implicit none
 integer(pInt) :: &
   e, i, &

   homog, &
   elemOffset


 homog = mesh_spectral_getHomogenization()


 allocate(mesh_element    (4_pInt+8_pInt,mesh_NcpElems), source = 0_pInt)


 elemOffset = product(grid(1:2))*grid3Offset
 e = 0_pInt
 do while (e < mesh_NcpElems)                                                                       ! fill expected number of elements, stop at end of data (or blank line!)
   e = e+1_pInt                                                                                     ! valid element entry
   mesh_element( 1,e) = -1_pInt                                                                     ! DEPRECATED
   mesh_element( 2,e) = 10_pInt
   mesh_element( 3,e) = homog                                                                       ! homogenization
   mesh_element( 4,e) = microGlobal(e+elemOffset)                                                   ! microstructure
   mesh_element( 5,e) = e + (e-1_pInt)/grid(1) + &
                                     ((e-1_pInt)/(grid(1)*grid(2)))*(grid(1)+1_pInt)                ! base node
   mesh_element( 6,e) = mesh_element(5,e) + 1_pInt
   mesh_element( 7,e) = mesh_element(5,e) + grid(1) + 2_pInt
   mesh_element( 8,e) = mesh_element(5,e) + grid(1) + 1_pInt
   mesh_element( 9,e) = mesh_element(5,e) +(grid(1) + 1_pInt) * (grid(2) + 1_pInt)                  ! second floor base node
   mesh_element(10,e) = mesh_element(9,e) + 1_pInt
   mesh_element(11,e) = mesh_element(9,e) + grid(1) + 2_pInt
   mesh_element(12,e) = mesh_element(9,e) + grid(1) + 1_pInt
 enddo

 if (e /= mesh_NcpElems) call IO_error(880_pInt,e)

end subroutine mesh_spectral_build_elements


!--------------------------------------------------------------------------------------------------
!> @brief build neighborhood relations for spectral
!> @details assign globals: mesh_ipNeighborhood
!--------------------------------------------------------------------------------------------------
subroutine mesh_spectral_build_ipNeighborhood

 implicit none
 integer(pInt) :: &
  x,y,z, &
  e
 allocate(mesh_ipNeighborhood(3,mesh_maxNipNeighbors,mesh_maxNips,mesh_NcpElems),source=0_pInt)

 e = 0_pInt
 do z = 0_pInt,grid3-1_pInt
   do y = 0_pInt,grid(2)-1_pInt
     do x = 0_pInt,grid(1)-1_pInt
       e = e + 1_pInt
         mesh_ipNeighborhood(1,1,1,e) = z * grid(1) * grid(2) &
                                      + y * grid(1) &
                                      + modulo(x+1_pInt,grid(1)) &
                                      + 1_pInt
         mesh_ipNeighborhood(1,2,1,e) = z * grid(1) * grid(2) &
                                      + y * grid(1) &
                                      + modulo(x-1_pInt,grid(1)) &
                                      + 1_pInt
         mesh_ipNeighborhood(1,3,1,e) = z * grid(1) * grid(2) &
                                      + modulo(y+1_pInt,grid(2)) * grid(1) &
                                      + x &
                                      + 1_pInt
         mesh_ipNeighborhood(1,4,1,e) = z * grid(1) * grid(2) &
                                      + modulo(y-1_pInt,grid(2)) * grid(1) &
                                      + x &
                                      + 1_pInt
         mesh_ipNeighborhood(1,5,1,e) = modulo(z+1_pInt,grid3) * grid(1) * grid(2) &
                                      + y * grid(1) &
                                      + x &
                                      + 1_pInt
         mesh_ipNeighborhood(1,6,1,e) = modulo(z-1_pInt,grid3) * grid(1) * grid(2) &
                                      + y * grid(1) &
                                      + x &
                                      + 1_pInt
         mesh_ipNeighborhood(2,1:6,1,e) = 1_pInt
         mesh_ipNeighborhood(3,1,1,e) = 2_pInt
         mesh_ipNeighborhood(3,2,1,e) = 1_pInt
         mesh_ipNeighborhood(3,3,1,e) = 4_pInt
         mesh_ipNeighborhood(3,4,1,e) = 3_pInt
         mesh_ipNeighborhood(3,5,1,e) = 6_pInt
         mesh_ipNeighborhood(3,6,1,e) = 5_pInt
     enddo
   enddo
 enddo

end subroutine mesh_spectral_build_ipNeighborhood


!--------------------------------------------------------------------------------------------------
!> @brief builds mesh of (distorted) cubes for given coordinates (= center of the cubes)
!--------------------------------------------------------------------------------------------------
function mesh_nodesAroundCentres(gDim,Favg,centres) result(nodes)
 use debug, only: &
   debug_mesh, &
   debug_level, &
   debug_levelBasic
 use math, only: &
   math_mul33x3

 implicit none
 real(pReal), intent(in), dimension(:,:,:,:) :: &
   centres
 real(pReal),             dimension(3,size(centres,2)+1,size(centres,3)+1,size(centres,4)+1) :: &
   nodes
 real(pReal), intent(in), dimension(3) :: &
   gDim
 real(pReal), intent(in), dimension(3,3) :: &
   Favg
 real(pReal),             dimension(3,size(centres,2)+2,size(centres,3)+2,size(centres,4)+2) :: &
   wrappedCentres

 integer(pInt) :: &
   i,j,k,n
 integer(pInt),           dimension(3), parameter :: &
   diag = 1_pInt
 integer(pInt),           dimension(3) :: &
   shift = 0_pInt, &
   lookup = 0_pInt, &
   me = 0_pInt, &
   iRes = 0_pInt
 integer(pInt),           dimension(3,8) :: &
   neighbor = reshape([ &
                       0_pInt, 0_pInt, 0_pInt, &
                       1_pInt, 0_pInt, 0_pInt, &
                       1_pInt, 1_pInt, 0_pInt, &
                       0_pInt, 1_pInt, 0_pInt, &
                       0_pInt, 0_pInt, 1_pInt, &
                       1_pInt, 0_pInt, 1_pInt, &
                       1_pInt, 1_pInt, 1_pInt, &
                       0_pInt, 1_pInt, 1_pInt  ], [3,8])

!--------------------------------------------------------------------------------------------------
! initializing variables
 iRes =  [size(centres,2),size(centres,3),size(centres,4)]
 nodes = 0.0_pReal
 wrappedCentres = 0.0_pReal

!--------------------------------------------------------------------------------------------------
! report
 if (iand(debug_level(debug_mesh),debug_levelBasic) /= 0_pInt) then
   write(6,'(a)')          ' Meshing cubes around centroids'
   write(6,'(a,3(e12.5))') ' Dimension: ', gDim
   write(6,'(a,3(i5))')    ' Resolution:', iRes
 endif

!--------------------------------------------------------------------------------------------------
! building wrappedCentres = centroids + ghosts
 wrappedCentres(1:3,2_pInt:iRes(1)+1_pInt,2_pInt:iRes(2)+1_pInt,2_pInt:iRes(3)+1_pInt) = centres
 do k = 0_pInt,iRes(3)+1_pInt
   do j = 0_pInt,iRes(2)+1_pInt
     do i = 0_pInt,iRes(1)+1_pInt
       if (k==0_pInt .or. k==iRes(3)+1_pInt .or. &                                                  ! z skin
           j==0_pInt .or. j==iRes(2)+1_pInt .or. &                                                  ! y skin
           i==0_pInt .or. i==iRes(1)+1_pInt      ) then                                             ! x skin
         me = [i,j,k]                                                                               ! me on skin
         shift = sign(abs(iRes+diag-2_pInt*me)/(iRes+diag),iRes+diag-2_pInt*me)
         lookup = me-diag+shift*iRes
         wrappedCentres(1:3,i+1_pInt,        j+1_pInt,        k+1_pInt) = &
                centres(1:3,lookup(1)+1_pInt,lookup(2)+1_pInt,lookup(3)+1_pInt) &
                - math_mul33x3(Favg, real(shift,pReal)*gDim)
       endif
 enddo; enddo; enddo

!--------------------------------------------------------------------------------------------------
! averaging
 do k = 0_pInt,iRes(3); do j = 0_pInt,iRes(2); do i = 0_pInt,iRes(1)
   do n = 1_pInt,8_pInt
    nodes(1:3,i+1_pInt,j+1_pInt,k+1_pInt) = &
    nodes(1:3,i+1_pInt,j+1_pInt,k+1_pInt) + wrappedCentres(1:3,i+1_pInt+neighbor(1,n), &
                                                               j+1_pInt+neighbor(2,n), &
                                                               k+1_pInt+neighbor(3,n) )
   enddo
 enddo; enddo; enddo
 nodes = nodes/8.0_pReal

end function mesh_nodesAroundCentres


!--------------------------------------------------------------------------------------------------
!> @brief calculation of IP interface areas, allocate globals '_ipArea', and '_ipAreaNormal'
!--------------------------------------------------------------------------------------------------
subroutine mesh_build_ipAreas
 use math, only: &
   math_crossproduct

 implicit none
 integer(pInt) :: e,t,g,c,i,f,n,m
 real(pReal), dimension (3,FE_maxNcellnodesPerCellface) :: nodePos, normals
 real(pReal), dimension(3) :: normal

 allocate(mesh_ipArea(mesh_maxNipNeighbors,mesh_maxNips,mesh_NcpElems), source=0.0_pReal)
 allocate(mesh_ipAreaNormal(3_pInt,mesh_maxNipNeighbors,mesh_maxNips,mesh_NcpElems), source=0.0_pReal)

 !$OMP PARALLEL DO PRIVATE(t,g,c,nodePos,normal,normals)
   do e = 1_pInt,mesh_NcpElems                                                                      ! loop over cpElems
     t = mesh_element(2_pInt,e)                                                                     ! get element type
     g = FE_geomtype(t)                                                                             ! get geometry type
     c = FE_celltype(g)                                                                             ! get cell type
     select case (c)

       case (1_pInt,2_pInt)                                                                         ! 2D 3 or 4 node
         do i = 1_pInt,FE_Nips(g)                                                                   ! loop over ips=cells in this element
           do f = 1_pInt,FE_NipNeighbors(c)                                                         ! loop over cell faces
             forall(n = 1_pInt:FE_NcellnodesPerCellface(c)) &
               nodePos(1:3,n) = mesh_cellnode(1:3,mesh_cell(FE_cellface(n,f,c),i,e))
             normal(1) =   nodePos(2,2) - nodePos(2,1)                                              ! x_normal =  y_connectingVector
             normal(2) = -(nodePos(1,2) - nodePos(1,1))                                             ! y_normal = -x_connectingVector
             normal(3) = 0.0_pReal
             mesh_ipArea(f,i,e) = norm2(normal)
             mesh_ipAreaNormal(1:3,f,i,e) = normal / norm2(normal)                             ! ensure unit length of area normal
           enddo
         enddo

       case (3_pInt)                                                                                ! 3D 4node
         do i = 1_pInt,FE_Nips(g)                                                                   ! loop over ips=cells in this element
           do f = 1_pInt,FE_NipNeighbors(c)                                                         ! loop over cell faces
             forall(n = 1_pInt:FE_NcellnodesPerCellface(c)) &
               nodePos(1:3,n) = mesh_cellnode(1:3,mesh_cell(FE_cellface(n,f,c),i,e))
             normal = math_crossproduct(nodePos(1:3,2) - nodePos(1:3,1), &
                                         nodePos(1:3,3) - nodePos(1:3,1))
             mesh_ipArea(f,i,e) = norm2(normal)
             mesh_ipAreaNormal(1:3,f,i,e) = normal / norm2(normal)                             ! ensure unit length of area normal
           enddo
         enddo

       case (4_pInt)                                                                                ! 3D 8node
         ! for this cell type we get the normal of the quadrilateral face as an average of
         ! four normals of triangular subfaces; since the face consists only of two triangles,
         ! the sum has to be divided by two; this whole prcedure tries to compensate for
         ! probable non-planar cell surfaces
         m = FE_NcellnodesPerCellface(c)
         do i = 1_pInt,FE_Nips(g)                                                                   ! loop over ips=cells in this element
           do f = 1_pInt,FE_NipNeighbors(c)                                                         ! loop over cell faces
             forall(n = 1_pInt:FE_NcellnodesPerCellface(c)) &
               nodePos(1:3,n) = mesh_cellnode(1:3,mesh_cell(FE_cellface(n,f,c),i,e))
             forall(n = 1_pInt:FE_NcellnodesPerCellface(c)) &
               normals(1:3,n) = 0.5_pReal &
                              * math_crossproduct(nodePos(1:3,1+mod(n  ,m)) - nodePos(1:3,n), &
                                                   nodePos(1:3,1+mod(n+1,m)) - nodePos(1:3,n))
             normal = 0.5_pReal * sum(normals,2)
             mesh_ipArea(f,i,e) = norm2(normal)
             mesh_ipAreaNormal(1:3,f,i,e) = normal / norm2(normal)
           enddo
         enddo

     end select
   enddo
 !$OMP END PARALLEL DO

end subroutine mesh_build_ipAreas


!--------------------------------------------------------------------------------------------------
!> @brief get properties of different types of finite elements
!> @details assign globals: FE_nodesAtIP, FE_ipNeighbor, FE_cellnodeParentnodeWeights, FE_subNodeOnIPFace
!--------------------------------------------------------------------------------------------------
subroutine mesh_build_FEdata

 implicit none
 integer(pInt) :: me
 allocate(FE_nodesAtIP(FE_maxmaxNnodesAtIP,FE_maxNips,FE_Ngeomtypes), source=0_pInt)
 allocate(FE_ipNeighbor(FE_maxNipNeighbors,FE_maxNips,FE_Ngeomtypes), source=0_pInt)
 allocate(FE_cell(FE_maxNcellnodesPerCell,FE_maxNips,FE_Ngeomtypes),  source=0_pInt)
 allocate(FE_cellnodeParentnodeWeights(FE_maxNnodes,FE_maxNcellnodes,FE_Nelemtypes), source=0.0_pReal)
 allocate(FE_cellface(FE_maxNcellnodesPerCellface,FE_maxNcellfaces,FE_Ncelltypes),  source=0_pInt)


 !*** fill FE_nodesAtIP with data ***

 me = 0_pInt

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element   6 (2D 3node 1ip)
    reshape(int([&
    1,2,3   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element 125 (2D 6node 3ip)
    reshape(int([&
    1,  &
    2,  &
    3   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element  11 (2D 4node 4ip)
    reshape(int([&
    1,  &
    2,  &
    4,  &
    3   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element  27 (2D 8node 9ip)
    reshape(int([&
    1,0,  &
    1,2,  &
    2,0,  &
    1,4,  &
    0,0,  &
    2,3,  &
    4,0,  &
    3,4,  &
    3,0   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element 134 (3D 4node 1ip)
    reshape(int([&
    1,2,3,4   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element 127 (3D 10node 4ip)
    reshape(int([&
    1,  &
    2,  &
    3,  &
    4   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element 136 (3D 6node 6ip)
    reshape(int([&
    1,  &
    2,  &
    3,  &
    4,  &
    5,  &
    6   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element 117 (3D 8node 1ip)
    reshape(int([&
    1,2,3,4,5,6,7,8   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element   7 (3D 8node 8ip)
    reshape(int([&
    1,  &
    2,  &
    4,  &
    3,  &
    5,  &
    6,  &
    8,  &
    7   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])

 me = me + 1_pInt
 FE_nodesAtIP(1:FE_maxNnodesAtIP(me),1:FE_Nips(me),me) = &  ! element  21 (3D 20node 27ip)
    reshape(int([&
    1,0, 0,0,  &
    1,2, 0,0,  &
    2,0, 0,0,  &
    1,4, 0,0,  &
    1,3, 2,4,  &
    2,3, 0,0,  &
    4,0, 0,0,  &
    3,4, 0,0,  &
    3,0, 0,0,  &
    1,5, 0,0,  &
    1,6, 2,5,  &
    2,6, 0,0,  &
    1,8, 4,5,  &
    0,0, 0,0,  &
    2,7, 3,6,  &
    4,8, 0,0,  &
    3,8, 4,7,  &
    3,7, 0,0,  &
    5,0, 0,0,  &
    5,6, 0,0,  &
    6,0, 0,0,  &
    5,8, 0,0,  &
    5,7, 6,8,  &
    6,7, 0,0,  &
    8,0, 0,0,  &
    7,8, 0,0,  &
    7,0, 0,0   &
    ],pInt),[FE_maxNnodesAtIP(me),FE_Nips(me)])


 ! *** FE_ipNeighbor ***
 ! is a list of the neighborhood of each IP.
 ! It is sorted in (local) +x,-x, +y,-y, +z,-z direction.
 ! Positive integers denote an intra-FE IP identifier.
 ! Negative integers denote the interface behind which the neighboring (extra-FE) IP will be located.
 me = 0_pInt

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   6 (2D 3node 1ip)
    reshape(int([&
    -2,-3,-1   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element 125 (2D 6node 3ip)
    reshape(int([&
     2,-3, 3,-1,  &
    -2, 1, 3,-1,  &
     2,-3,-2, 1   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element  11 (2D 4node 4ip)
    reshape(int([&
     2,-4, 3,-1,  &
    -2, 1, 4,-1,  &
     4,-4,-3, 1,  &
    -2, 3,-3, 2   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element  27 (2D 8node 9ip)
    reshape(int([&
     2,-4, 4,-1,  &
     3, 1, 5,-1,  &
    -2, 2, 6,-1,  &
     5,-4, 7, 1,  &
     6, 4, 8, 2,  &
    -2, 5, 9, 3,  &
     8,-4,-3, 4,  &
     9, 7,-3, 5,  &
    -2, 8,-3, 6   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element 134 (3D 4node 1ip)
    reshape(int([&
    -1,-2,-3,-4   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element 127 (3D 10node 4ip)
    reshape(int([&
     2,-4, 3,-2, 4,-1,  &
    -2, 1, 3,-2, 4,-1,  &
     2,-4,-3, 1, 4,-1,  &
     2,-4, 3,-2,-3, 1   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element 136 (3D 6node 6ip)
    reshape(int([&
     2,-4, 3,-2, 4,-1,  &
    -3, 1, 3,-2, 5,-1,  &
     2,-4,-3, 1, 6,-1,  &
     5,-4, 6,-2,-5, 1,  &
    -3, 4, 6,-2,-5, 2,  &
     5,-4,-3, 4,-5, 3   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element 117 (3D 8node 1ip)
    reshape(int([&
    -3,-5,-4,-2,-6,-1   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   7 (3D 8node 8ip)
    reshape(int([&
     2,-5, 3,-2, 5,-1,  &
    -3, 1, 4,-2, 6,-1,  &
     4,-5,-4, 1, 7,-1,  &
    -3, 3,-4, 2, 8,-1,  &
     6,-5, 7,-2,-6, 1,  &
    -3, 5, 8,-2,-6, 2,  &
     8,-5,-4, 5,-6, 3,  &
    -3, 7,-4, 6,-6, 4   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_ipNeighbor(1:FE_NipNeighbors(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element  21 (3D 20node 27ip)
    reshape(int([&
     2,-5, 4,-2,10,-1,  &
     3, 1, 5,-2,11,-1,  &
    -3, 2, 6,-2,12,-1,  &
     5,-5, 7, 1,13,-1,  &
     6, 4, 8, 2,14,-1,  &
    -3, 5, 9, 3,15,-1,  &
     8,-5,-4, 4,16,-1,  &
     9, 7,-4, 5,17,-1,  &
    -3, 8,-4, 6,18,-1,  &
    11,-5,13,-2,19, 1,  &
    12,10,14,-2,20, 2,  &
    -3,11,15,-2,21, 3,  &
    14,-5,16,10,22, 4,  &
    15,13,17,11,23, 5,  &
    -3,14,18,12,24, 6,  &
    17,-5,-4,13,25, 7,  &
    18,16,-4,14,26, 8,  &
    -3,17,-4,15,27, 9,  &
    20,-5,22,-2,-6,10,  &
    21,19,23,-2,-6,11,  &
    -3,20,24,-2,-6,12,  &
    23,-5,25,19,-6,13,  &
    24,22,26,20,-6,14,  &
    -3,23,27,21,-6,15,  &
    26,-5,-4,22,-6,16,  &
    27,25,-4,23,-6,17,  &
    -3,26,-4,24,-6,18   &
    ],pInt),[FE_NipNeighbors(FE_celltype(me)),FE_Nips(me)])


 ! *** FE_cell ***
 me = 0_pInt

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   6 (2D 3node 1ip)
    reshape(int([&
    1,2,3   &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   125 (2D 6node 3ip)
    reshape(int([&
    1, 4, 7, 6,   &
    2, 5, 7, 4,   &
    3, 6, 7, 5    &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   11 (2D 4node 4ip)
    reshape(int([&
    1, 5, 9, 8,   &
    5, 2, 6, 9,   &
    8, 9, 7, 4,   &
    9, 6, 3, 7    &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   27 (2D 8node 9ip)
    reshape(int([&
    1, 5,13,12,   &
    5, 6,14,13,   &
    6, 2, 7,14,   &
   12,13,16,11,   &
   13,14,15,16,   &
   14, 7, 8,15,   &
   11,16,10, 4,   &
   16,15, 9,10,   &
   15, 8, 3, 9    &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   134 (3D 4node 1ip)
    reshape(int([&
    1, 2, 3, 4   &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   127 (3D 10node 4ip)
    reshape(int([&
    1, 5,11, 7, 8,12,15,14,  &
    5, 2, 6,11,12, 9,13,15,  &
    7,11, 6, 3,14,15,13,10,  &
    8,12,15, 4, 4, 9,13,10   &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   136 (3D 6node 6ip)
    reshape(int([&
    1, 7,16, 9,10,17,21,19,  &
    7, 2, 8,16,17,11,18,21,  &
    9,16, 8, 3,19,21,18,12,  &
   10,17,21,19, 4,13,20,15,  &
   17,11,18,21,13, 5,14,20,  &
   19,21,18,12,15,20,14, 6   &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   117 (3D 8node 1ip)
    reshape(int([&
    1, 2, 3, 4, 5, 6, 7, 8   &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   7 (3D 8node 8ip)
    reshape(int([&
    1, 9,21,12,13,22,27,25,  &
    9, 2,10,21,22,14,23,27,  &
   12,21,11, 4,25,27,24,16,  &
   21,10, 3,11,27,23,15,24,  &
   13,22,27,25, 5,17,26,20,  &
   22,14,23,27,17, 6,18,26,  &
   25,27,24,16,20,26,19, 8,  &
   27,23,15,24,26,18, 7,19   &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])

 me = me + 1_pInt
 FE_cell(1:FE_NcellnodesPerCell(FE_celltype(me)),1:FE_Nips(me),me) = &  ! element   21 (3D 20node 27ip)
    reshape(int([&
    1, 9,33,16,17,37,57,44,  &
    9,10,34,33,37,38,58,57,  &
   10, 2,11,34,38,18,39,58,  &
   16,33,36,15,44,57,60,43,  &
   33,34,35,36,57,58,59,60,  &
   34,11,12,35,58,39,40,59,  &
   15,36,14, 4,43,60,42,20,  &
   36,35,13,14,60,59,41,42,  &
   35,12, 3,13,59,40,19,41,  &
   17,37,57,44,21,45,61,52,  &
   37,38,58,57,45,46,62,61,  &
   38,18,39,58,46,22,47,62,  &
   44,57,60,43,52,61,64,51,  &
   57,58,59,60,61,62,63,64,  &
   58,39,40,59,62,47,48,63,  &
   43,60,42,20,51,64,50,24,  &
   60,59,41,42,64,63,49,50,  &
   59,40,19,41,63,48,23,49,  &
   21,45,61,52, 5,25,53,32,  &
   45,46,62,61,25,26,54,53,  &
   46,22,47,62,26, 6,27,54,  &
   52,61,64,51,32,53,56,31,  &
   61,62,63,64,53,54,55,56,  &
   62,47,48,63,54,27,28,55,  &
   51,64,50,24,31,56,30, 8,  &
   64,63,49,50,56,55,29,30,  &
   63,48,23,49,55,28, 7,29   &
    ],pInt),[FE_NcellnodesPerCell(FE_celltype(me)),FE_Nips(me)])


 ! *** FE_cellnodeParentnodeWeights ***
 ! center of gravity of the weighted nodes gives the position of the cell node.
 ! fill with 0.
 ! example: face-centered cell node with face nodes 1,2,5,6 to be used in,
 !          e.g., an 8 node element, would be encoded:
 !          1, 1, 0, 0, 1, 1, 0, 0
 me = 0_pInt

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element   6 (2D 3node 1ip)
    reshape(real([&
    1, 0, 0,  &
    0, 1, 0,  &
    0, 0, 1   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element 125 (2D 6node 3ip)
    reshape(real([&
    1, 0, 0, 0, 0, 0,  &
    0, 1, 0, 0, 0, 0,  &
    0, 0, 1, 0, 0, 0,  &
    0, 0, 0, 1, 0, 0,  &
    0, 0, 0, 0, 1, 0,  &
    0, 0, 0, 0, 0, 1,  &
    1, 1, 1, 2, 2, 2   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element  11 (2D 4node 4ip)
    reshape(real([&
    1, 0, 0, 0,  &
    0, 1, 0, 0,  &
    0, 0, 1, 0,  &
    0, 0, 0, 1,  &
    1, 1, 0, 0,  &
    0, 1, 1, 0,  &
    0, 0, 1, 1,  &
    1, 0, 0, 1,  &
    1, 1, 1, 1   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element  27 (2D 8node 9ip)
    reshape(real([&
    1, 0, 0, 0, 0, 0, 0, 0,  &
    0, 1, 0, 0, 0, 0, 0, 0,  &
    0, 0, 1, 0, 0, 0, 0, 0,  &
    0, 0, 0, 1, 0, 0, 0, 0,  &
    1, 0, 0, 0, 2, 0, 0, 0,  &
    0, 1, 0, 0, 2, 0, 0, 0,  &
    0, 1, 0, 0, 0, 2, 0, 0,  &
    0, 0, 1, 0, 0, 2, 0, 0,  &
    0, 0, 1, 0, 0, 0, 2, 0,  &
    0, 0, 0, 1, 0, 0, 2, 0,  &
    0, 0, 0, 1, 0, 0, 0, 2,  &
    1, 0, 0, 0, 0, 0, 0, 2,  &
    4, 1, 1, 1, 8, 2, 2, 8,  &
    1, 4, 1, 1, 8, 8, 2, 2,  &
    1, 1, 4, 1, 2, 8, 8, 2,  &
    1, 1, 1, 4, 2, 2, 8, 8   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element  54 (2D 8node 4ip)
    reshape(real([&
    1, 0, 0, 0, 0, 0, 0, 0,  &
    0, 1, 0, 0, 0, 0, 0, 0,  &
    0, 0, 1, 0, 0, 0, 0, 0,  &
    0, 0, 0, 1, 0, 0, 0, 0,  &
    0, 0, 0, 0, 1, 0, 0, 0,  &
    0, 0, 0, 0, 0, 1, 0, 0,  &
    0, 0, 0, 0, 0, 0, 1, 0,  &
    0, 0, 0, 0, 0, 0, 0, 1,  &
    1, 1, 1, 1, 2, 2, 2, 2   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element 134 (3D 4node 1ip)
    reshape(real([&
    1, 0, 0, 0,  &
    0, 1, 0, 0,  &
    0, 0, 1, 0,  &
    0, 0, 0, 1   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element 157 (3D 5node 4ip)
    reshape(real([&
    1, 0, 0, 0, 0,  &
    0, 1, 0, 0, 0,  &
    0, 0, 1, 0, 0,  &
    0, 0, 0, 1, 0,  &
    1, 1, 0, 0, 0,  &
    0, 1, 1, 0, 0,  &
    1, 0, 1, 0, 0,  &
    1, 0, 0, 1, 0,  &
    0, 1, 0, 1, 0,  &
    0, 0, 1, 1, 0,  &
    1, 1, 1, 0, 0,  &
    1, 1, 0, 1, 0,  &
    0, 1, 1, 1, 0,  &
    1, 0, 1, 1, 0,  &
    0, 0, 0, 0, 1   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element 127 (3D 10node 4ip)
    reshape(real([&
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0,  &
    0, 1, 0, 0, 0, 0, 0, 0, 0, 0,  &
    0, 0, 1, 0, 0, 0, 0, 0, 0, 0,  &
    0, 0, 0, 1, 0, 0, 0, 0, 0, 0,  &
    0, 0, 0, 0, 1, 0, 0, 0, 0, 0,  &
    0, 0, 0, 0, 0, 1, 0, 0, 0, 0,  &
    0, 0, 0, 0, 0, 0, 1, 0, 0, 0,  &
    0, 0, 0, 0, 0, 0, 0, 1, 0, 0,  &
    0, 0, 0, 0, 0, 0, 0, 0, 1, 0,  &
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1,  &
    1, 1, 1, 0, 2, 2, 2, 0, 0, 0,  &
    1, 1, 0, 1, 2, 0, 0, 2, 2, 0,  &
    0, 1, 1, 1, 0, 2, 0, 0, 2, 2,  &
    1, 0, 1, 1, 0, 0, 2, 2, 0, 2,  &
    3, 3, 3, 3, 4, 4, 4, 4, 4, 4   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element 136 (3D 6node 6ip)
    reshape(real([&
    1, 0, 0, 0, 0, 0,  &
    0, 1, 0, 0, 0, 0,  &
    0, 0, 1, 0, 0, 0,  &
    0, 0, 0, 1, 0, 0,  &
    0, 0, 0, 0, 1, 0,  &
    0, 0, 0, 0, 0, 1,  &
    1, 1, 0, 0, 0, 0,  &
    0, 1, 1, 0, 0, 0,  &
    1, 0, 1, 0, 0, 0,  &
    1, 0, 0, 1, 0, 0,  &
    0, 1, 0, 0, 1, 0,  &
    0, 0, 1, 0, 0, 1,  &
    0, 0, 0, 1, 1, 0,  &
    0, 0, 0, 0, 1, 1,  &
    0, 0, 0, 1, 0, 1,  &
    1, 1, 1, 0, 0, 0,  &
    1, 1, 0, 1, 1, 0,  &
    0, 1, 1, 0, 1, 1,  &
    1, 0, 1, 1, 0, 1,  &
    0, 0, 0, 1, 1, 1,  &
    1, 1, 1, 1, 1, 1   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element 117 (3D 8node 1ip)
    reshape(real([&
    1, 0, 0, 0, 0, 0, 0, 0,  &
    0, 1, 0, 0, 0, 0, 0, 0,  &
    0, 0, 1, 0, 0, 0, 0, 0,  &
    0, 0, 0, 1, 0, 0, 0, 0,  &
    0, 0, 0, 0, 1, 0, 0, 0,  &
    0, 0, 0, 0, 0, 1, 0, 0,  &
    0, 0, 0, 0, 0, 0, 1, 0,  &
    0, 0, 0, 0, 0, 0, 0, 1   &
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element   7 (3D 8node 8ip)
    reshape(real([&
    1, 0, 0, 0,  0, 0, 0, 0,  &   !
    0, 1, 0, 0,  0, 0, 0, 0,  &   !
    0, 0, 1, 0,  0, 0, 0, 0,  &   !
    0, 0, 0, 1,  0, 0, 0, 0,  &   !
    0, 0, 0, 0,  1, 0, 0, 0,  &   !  5
    0, 0, 0, 0,  0, 1, 0, 0,  &   !
    0, 0, 0, 0,  0, 0, 1, 0,  &   !
    0, 0, 0, 0,  0, 0, 0, 1,  &   !
    1, 1, 0, 0,  0, 0, 0, 0,  &   !
    0, 1, 1, 0,  0, 0, 0, 0,  &   ! 10
    0, 0, 1, 1,  0, 0, 0, 0,  &   !
    1, 0, 0, 1,  0, 0, 0, 0,  &   !
    1, 0, 0, 0,  1, 0, 0, 0,  &   !
    0, 1, 0, 0,  0, 1, 0, 0,  &   !
    0, 0, 1, 0,  0, 0, 1, 0,  &   ! 15
    0, 0, 0, 1,  0, 0, 0, 1,  &   !
    0, 0, 0, 0,  1, 1, 0, 0,  &   !
    0, 0, 0, 0,  0, 1, 1, 0,  &   !
    0, 0, 0, 0,  0, 0, 1, 1,  &   !
    0, 0, 0, 0,  1, 0, 0, 1,  &   ! 20
    1, 1, 1, 1,  0, 0, 0, 0,  &   !
    1, 1, 0, 0,  1, 1, 0, 0,  &   !
    0, 1, 1, 0,  0, 1, 1, 0,  &   !
    0, 0, 1, 1,  0, 0, 1, 1,  &   !
    1, 0, 0, 1,  1, 0, 0, 1,  &   ! 25
    0, 0, 0, 0,  1, 1, 1, 1,  &   !
    1, 1, 1, 1,  1, 1, 1, 1   &   !
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element  57 (3D 20node 8ip)
    reshape(real([&
    1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 1, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !  5
    0, 0, 0, 0,  0, 1, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 1, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   ! 10
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 1, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 1, 0, &   ! 15
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 1, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 1, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 1,  0, 0, 0, 0, &   ! 20
    1, 1, 1, 1,  0, 0, 0, 0,  2, 2, 2, 2,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    1, 1, 0, 0,  1, 1, 0, 0,  2, 0, 0, 0,  2, 0, 0, 0,  2, 2, 0, 0, &   !
    0, 1, 1, 0,  0, 1, 1, 0,  0, 2, 0, 0,  0, 2, 0, 0,  0, 2, 2, 0, &   !
    0, 0, 1, 1,  0, 0, 1, 1,  0, 0, 2, 0,  0, 0, 2, 0,  0, 0, 2, 2, &   !
    1, 0, 0, 1,  1, 0, 0, 1,  0, 0, 0, 2,  0, 0, 0, 2,  2, 0, 0, 2, &   ! 25
    0, 0, 0, 0,  1, 1, 1, 1,  0, 0, 0, 0,  2, 2, 2, 2,  0, 0, 0, 0, &   !
    3, 3, 3, 3,  3, 3, 3, 3,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4  &   !
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])

 me = me + 1_pInt
 FE_cellnodeParentnodeWeights(1:FE_Nnodes(me),1:FE_Ncellnodes(FE_geomtype(me)),me) = &  ! element  21 (3D 20node 27ip)
    reshape(real([&
    1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 1, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !  5
    0, 0, 0, 0,  0, 1, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    1, 0, 0, 0,  0, 0, 0, 0,  2, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 1, 0, 0,  0, 0, 0, 0,  2, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   ! 10
    0, 1, 0, 0,  0, 0, 0, 0,  0, 2, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 1, 0,  0, 0, 0, 0,  0, 2, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 2, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 2, 0,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 2,  0, 0, 0, 0,  0, 0, 0, 0, &   ! 15
    1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 2,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  2, 0, 0, 0, &   !
    0, 1, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 2, 0, 0, &   !
    0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 2, 0, &   !
    0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 2, &   ! 20
    0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  2, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 1, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 2, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 2, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 2, &   !
    0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,  2, 0, 0, 0,  0, 0, 0, 0, &   ! 25
    0, 0, 0, 0,  0, 1, 0, 0,  0, 0, 0, 0,  2, 0, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 1, 0, 0,  0, 0, 0, 0,  0, 2, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0,  0, 2, 0, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 2, 0,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 2, 0,  0, 0, 0, 0, &   ! 30
    0, 0, 0, 0,  0, 0, 0, 1,  0, 0, 0, 0,  0, 0, 0, 2,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 2,  0, 0, 0, 0, &   !
    4, 1, 1, 1,  0, 0, 0, 0,  8, 2, 2, 8,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    1, 4, 1, 1,  0, 0, 0, 0,  8, 8, 2, 2,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    1, 1, 4, 1,  0, 0, 0, 0,  2, 8, 8, 2,  0, 0, 0, 0,  0, 0, 0, 0, &   ! 35
    1, 1, 1, 4,  0, 0, 0, 0,  2, 2, 8, 8,  0, 0, 0, 0,  0, 0, 0, 0, &   !
    4, 1, 0, 0,  1, 1, 0, 0,  8, 0, 0, 0,  2, 0, 0, 0,  8, 2, 0, 0, &   !
    1, 4, 0, 0,  1, 1, 0, 0,  8, 0, 0, 0,  2, 0, 0, 0,  2, 8, 0, 0, &   !
    0, 4, 1, 0,  0, 1, 1, 0,  0, 8, 0, 0,  0, 2, 0, 0,  0, 8, 2, 0, &   !
    0, 1, 4, 0,  0, 1, 1, 0,  0, 8, 0, 0,  0, 2, 0, 0,  0, 2, 8, 0, &   ! 40
    0, 0, 4, 1,  0, 0, 1, 1,  0, 0, 8, 0,  0, 0, 2, 0,  0, 0, 8, 2, &   !
    0, 0, 1, 4,  0, 0, 1, 1,  0, 0, 8, 0,  0, 0, 2, 0,  0, 0, 2, 8, &   !
    1, 0, 0, 4,  1, 0, 0, 1,  0, 0, 0, 8,  0, 0, 0, 2,  2, 0, 0, 8, &   !
    4, 0, 0, 1,  1, 0, 0, 1,  0, 0, 0, 8,  0, 0, 0, 2,  8, 0, 0, 2, &   !
    1, 1, 0, 0,  4, 1, 0, 0,  2, 0, 0, 0,  8, 0, 0, 0,  8, 2, 0, 0, &   ! 45
    1, 1, 0, 0,  1, 4, 0, 0,  2, 0, 0, 0,  8, 0, 0, 0,  2, 8, 0, 0, &   !
    0, 1, 1, 0,  0, 4, 1, 0,  0, 2, 0, 0,  0, 8, 0, 0,  0, 8, 2, 0, &   !
    0, 1, 1, 0,  0, 1, 4, 0,  0, 2, 0, 0,  0, 8, 0, 0,  0, 2, 8, 0, &   !
    0, 0, 1, 1,  0, 0, 4, 1,  0, 0, 2, 0,  0, 0, 8, 0,  0, 0, 8, 2, &   !
    0, 0, 1, 1,  0, 0, 1, 4,  0, 0, 2, 0,  0, 0, 8, 0,  0, 0, 2, 8, &   ! 50
    1, 0, 0, 1,  1, 0, 0, 4,  0, 0, 0, 2,  0, 0, 0, 8,  2, 0, 0, 8, &   !
    1, 0, 0, 1,  4, 0, 0, 1,  0, 0, 0, 2,  0, 0, 0, 8,  8, 0, 0, 2, &   !
    0, 0, 0, 0,  4, 1, 1, 1,  0, 0, 0, 0,  8, 2, 2, 8,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  1, 4, 1, 1,  0, 0, 0, 0,  8, 8, 2, 2,  0, 0, 0, 0, &   !
    0, 0, 0, 0,  1, 1, 4, 1,  0, 0, 0, 0,  2, 8, 8, 2,  0, 0, 0, 0, &   ! 55
    0, 0, 0, 0,  1, 1, 1, 4,  0, 0, 0, 0,  2, 2, 8, 8,  0, 0, 0, 0, &   !
   24, 8, 4, 8,  8, 4, 3, 4, 32,12,12,32, 12, 4, 4,12, 32,12, 4,12, &   !
    8,24, 8, 4,  4, 8, 4, 3, 32,32,12,12, 12,12, 4, 4, 12,32,12, 4, &   !
    4, 8,24, 8,  3, 4, 8, 4, 12,32,32,12,  4,12,12, 4,  4,12,32,12, &   !
    8, 4, 8,24,  4, 3, 4, 8, 12,12,32,32,  4, 4,12,12, 12, 4,12,32, &   ! 60
    8, 4, 3, 4, 24, 8, 4, 8, 12, 4, 4,12, 32,12,12,32, 32,12, 4,12, &   !
    4, 8, 4, 3,  8,24, 8, 4, 12,12, 4, 4, 32,32,12,12, 12,32,12, 4, &   !
    3, 4, 8, 4,  4, 8,24, 8,  4,12,12, 4, 12,32,32,12,  4,12,32,12, &   !
    4, 3, 4, 8,  8, 4, 8,24,  4, 4,12,12, 12,12,32,32, 12, 4,12,32  &   !
    ],pReal),[FE_Nnodes(me),FE_Ncellnodes(FE_geomtype(me))])



 ! *** FE_cellface ***
 me = 0_pInt

 me = me + 1_pInt
 FE_cellface(1:FE_NcellnodesPerCellface(me),1:FE_NipNeighbors(me),me) = &                           ! 2D 3node, VTK_TRIANGLE (5)
    reshape(int([&
    2,3,  &
    3,1,  &
    1,2   &
    ],pInt),[FE_NcellnodesPerCellface(me),FE_NipNeighbors(me)])

 me = me + 1_pInt
 FE_cellface(1:FE_NcellnodesPerCellface(me),1:FE_NipNeighbors(me),me) = &                           ! 2D 4node, VTK_QUAD (9)
    reshape(int([&
    2,3,  &
    4,1,  &
    3,4,  &
    1,2   &
    ],pInt),[FE_NcellnodesPerCellface(me),FE_NipNeighbors(me)])

 me = me + 1_pInt
 FE_cellface(1:FE_NcellnodesPerCellface(me),1:FE_NipNeighbors(me),me) = &                           ! 3D 4node, VTK_TETRA (10)
    reshape(int([&
    1,3,2,  &
    1,2,4,  &
    2,3,4,  &
    1,4,3   &
    ],pInt),[FE_NcellnodesPerCellface(me),FE_NipNeighbors(me)])

 me = me + 1_pInt
 FE_cellface(1:FE_NcellnodesPerCellface(me),1:FE_NipNeighbors(me),me) = &                           ! 3D 8node, VTK_HEXAHEDRON (12)
    reshape(int([&
    2,3,7,6,  &
    4,1,5,8,  &
    3,4,8,7,  &
    1,2,6,5,  &
    5,6,7,8,  &
    1,4,3,2   &
    ],pInt),[FE_NcellnodesPerCellface(me),FE_NipNeighbors(me)])
  

end subroutine mesh_build_FEdata


end module mesh
