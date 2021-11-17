submodule(phase:mechanical) elastic

  type :: tParameters
    real(pReal), dimension(6,6) :: &
      C66 = 0.0_pReal                                                                               !< Elastic constants in Voigt notation
    real(pReal) :: &
      mu, &
      nu
  end type tParameters

  type(tParameters), allocatable, dimension(:) :: param

contains


module subroutine elastic_init(phases)

  class(tNode), pointer :: &
    phases

  integer :: &
    ph
  class(tNode), pointer :: &
    phase, &
    mech, &
    elastic


  print'(/,1x,a)', '<<<+-  phase:mechanical:elastic init  -+>>>'
  print'(/,1x,a)', '<<<+-  phase:mechanical:elastic:Hooke init  -+>>>'

  print'(/,a,i0)', ' # phases: ',phases%length; flush(IO_STDOUT)

  allocate(param(phases%length))

  do ph = 1, phases%length
    phase   => phases%get(ph)
    mech    => phase%get('mechanical')
    elastic => mech%get('elastic')
    if (elastic%get_asString('type') /= 'Hooke') call IO_error(200,ext_msg=elastic%get_asString('type'))

    associate(prm => param(ph))

      prm%C66(1,1) = elastic%get_asFloat('C_11')
      prm%C66(1,2) = elastic%get_asFloat('C_12')
      prm%C66(4,4) = elastic%get_asFloat('C_44')

      if (any(phase_lattice(ph) == ['hP','tI'])) then
        prm%C66(1,3) = elastic%get_asFloat('C_13')
        prm%C66(3,3) = elastic%get_asFloat('C_33')
      end if
      if (phase_lattice(ph) == 'tI') prm%C66(6,6) = elastic%get_asFloat('C_66')

      prm%C66 = lattice_symmetrize_C66(prm%C66,phase_lattice(ph))

      prm%nu = lattice_equivalent_nu(prm%C66,'voigt')
      prm%mu = lattice_equivalent_mu(prm%C66,'voigt')

      prm%C66 = math_sym3333to66(math_Voigt66to3333(prm%C66))                                       ! Literature data is in Voigt notation

    end associate
  end do

end subroutine elastic_init


!--------------------------------------------------------------------------------------------------
!> @brief returns the 2nd Piola-Kirchhoff stress tensor and its tangent with respect to
!> the elastic and intermediate deformation gradients using Hooke's law
!--------------------------------------------------------------------------------------------------
module subroutine phase_hooke_SandItsTangents(S, dS_dFe, dS_dFi, &
                                              Fe, Fi, ph, en)

  integer, intent(in) :: &
    ph, &
    en
  real(pReal),   intent(in),  dimension(3,3) :: &
    Fe, &                                                                                           !< elastic deformation gradient
    Fi                                                                                              !< intermediate deformation gradient
  real(pReal),   intent(out), dimension(3,3) :: &
    S                                                                                               !< 2nd Piola-Kirchhoff stress tensor in lattice configuration
  real(pReal),   intent(out), dimension(3,3,3,3) :: &
    dS_dFe, &                                                                                       !< derivative of 2nd P-K stress with respect to elastic deformation gradient
    dS_dFi                                                                                          !< derivative of 2nd P-K stress with respect to intermediate deformation gradient

  real(pReal), dimension(3,3) :: E
  real(pReal), dimension(3,3,3,3) :: C
  integer :: &
    i, j


  C = math_66toSym3333(phase_homogenizedC(ph,en))
  C = phase_damage_C(C,ph,en)

  E = 0.5_pReal*(matmul(transpose(Fe),Fe)-math_I3)                                                  !< Green-Lagrange strain in unloaded configuration
  S = math_mul3333xx33(C,matmul(matmul(transpose(Fi),E),Fi))                                        !< 2PK stress in lattice configuration in work conjugate with GL strain pulled back to lattice configuration

  do i =1, 3;do j=1,3
    dS_dFe(i,j,1:3,1:3) = matmul(Fe,matmul(matmul(Fi,C(i,j,1:3,1:3)),transpose(Fi)))                !< dS_ij/dFe_kl = C_ijmn * Fi_lm * Fi_on * Fe_ko
    dS_dFi(i,j,1:3,1:3) = 2.0_pReal*matmul(matmul(E,Fi),C(i,j,1:3,1:3))                             !< dS_ij/dFi_kl = C_ijln * E_km * Fe_mn
  end do; end do

end subroutine phase_hooke_SandItsTangents


!--------------------------------------------------------------------------------------------------
!> @brief returns the homogenized elasticity matrix
!> ToDo: homogenizedC66 would be more consistent
!--------------------------------------------------------------------------------------------------
module function phase_homogenizedC(ph,en) result(C)

  real(pReal), dimension(6,6) :: C
  integer,      intent(in)    :: ph, en

  plasticType: select case (phase_plasticity(ph))
    case (PLASTICITY_DISLOTWIN_ID) plasticType
     C = plastic_dislotwin_homogenizedC(ph,en)
    case default plasticType
     C = param(ph)%C66
  end select plasticType

end function phase_homogenizedC

module function elastic_C66(ph) result(C66)
  real(pReal), dimension(6,6) :: C66
  integer,     intent(in) :: ph


  C66 = param(ph)%C66

end function elastic_C66

module function elastic_mu(ph) result(mu)

  real(pReal) :: mu
  integer, intent(in) :: ph


  mu = param(ph)%mu

end function elastic_mu

module function elastic_nu(ph) result(nu)

  real(pReal) :: nu
  integer, intent(in) :: ph


  nu = param(ph)%nu

end function elastic_nu

end submodule elastic
