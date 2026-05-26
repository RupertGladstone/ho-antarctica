!/*****************************************************************************/
! *
! *  Elmer/Ice, a glaciological add-on to Elmer
! *  http://elmerice.elmerfem.org
! *
! *  This program is free software; you can redistribute it and/or
! *  modify it under the terms of the GNU General Public License
! *  as published by the Free Software Foundation; either version 2
! *  of the License, or (at your option) any later version.
! *
! *  This program is distributed in the hope that it will be useful,
! *  but WITHOUT ANY WARRANTY; without even the implied warranty of
! *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! *  GNU General Public License for more details.
! *
! *  You should have received a copy of the GNU General Public License
! *  along with this program (in file fem/GPL-2); if not, write to the
! *  Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
! *  Boston, MA 02110-1301, USA.
! *
! *****************************************************************************/
! *****************************************************************************
! *
! *  Compute the nodal gradient of the cost function w.r.t. the ice viscosity
! *  pre-factor for the Blatter-Pattyn (HydrostaticNS) inverse method.
! *
! *  Adapted from AdjointStokes_GradientMu.F90 for the Blatter-Pattyn solver
! *  which has 2 DOFs (u,v) and uses a different stiffness matrix structure
! *  (hydrostatic 1st-order approximation).
! *
! *  This is a bulk solver executed on the ice body.
! *
! *  SIF keywords:
! *    In Solver section:
! *      Flow Solution Name = String (default "HorizontalVelocity")
! *      Adjoint Solution Name = String (default "Adjoint")
! *      Gradient Variable Name = String (default "DJDMu")
! *      Reset Gradient Variable = Logical (default True)
! *
! *    In Material section:
! *      Viscosity Model = String "power law" (required)
! *      Viscosity Exponent = Real (1/n for Glen's law, e.g. 1/3)
! *      Critical Shear Rate = Real (optional, regularization)
! *      Viscosity derivative = Real/Variable (for change of variable)
! *
! *****************************************************************************
SUBROUTINE AdjointBP_GradientMuSolver_init0(Model,Solver,dt,TransientSimulation)
!------------------------------------------------------------------------------
  USE DefUtils
  IMPLICIT NONE
!------------------------------------------------------------------------------
  TYPE(Solver_t), TARGET :: Solver
  TYPE(Model_t) :: Model
  REAL(KIND=dp) :: dt
  LOGICAL :: TransientSimulation
!------------------------------------------------------------------------------
  CHARACTER(LEN=MAX_NAME_LEN) :: Name

  Name = ListGetString( Solver % Values, 'Equation', UnFoundFatal=.TRUE. )
  CALL ListAddNewString( Solver % Values, 'Variable', &
       '-nooutput '//TRIM(Name)//'_var' )
  CALL ListAddLogical( Solver % Values, 'Optimize Bandwidth', .FALSE. )

END SUBROUTINE AdjointBP_GradientMuSolver_init0
! *****************************************************************************
SUBROUTINE AdjointBP_GradientMuSolver( Model, Solver, dt, TransientSimulation )
!------------------------------------------------------------------------------
  USE DefUtils
  IMPLICIT NONE
!------------------------------------------------------------------------------
  TYPE(Solver_t) :: Solver
  TYPE(Model_t) :: Model
  REAL(KIND=dp) :: dt
  LOGICAL :: TransientSimulation
!
  TYPE(Element_t), POINTER :: Element
  TYPE(Nodes_t) :: ElementNodes
  TYPE(GaussIntegrationPoints_t) :: IntegStuff
  TYPE(ValueList_t), POINTER :: SolverParams, Material

  REAL(KIND=dp), ALLOCATABLE :: Basis(:), dBasisdx(:,:)
  REAL(KIND=dp) :: u, v, w, SqrtElementMetric
  INTEGER, POINTER :: NodeIndexes(:)
  CHARACTER(LEN=MAX_NAME_LEN) :: SolverName

  ! Flow and adjoint variables
  TYPE(Variable_t), POINTER :: GradVariable, FlowSol, AdjointSol
  REAL(KIND=dp), POINTER :: GradValues(:), FlowValues(:), AdjointValues(:)
  INTEGER, POINTER :: GradPerm(:), FlowPerm(:), AdjointPerm(:)
  CHARACTER(LEN=MAX_NAME_LEN) :: GradSolName, FlowSolName, AdjointSolName

  ! Local work arrays
  REAL(KIND=dp), ALLOCATABLE :: VisitedNode(:), db(:)
  REAL(KIND=dp), ALLOCATABLE, DIMENSION(:) :: Ux, Uy
  REAL(KIND=dp) :: dVelodx(2,3)
  REAL(KIND=dp) :: s, ss, c2, c3
  REAL(KIND=dp) :: mub, Viscosityb
  REAL(KIND=dp), ALLOCATABLE, DIMENSION(:) :: c2n, c3n
  REAL(KIND=dp), ALLOCATABLE, DIMENSION(:) :: NodalViscosityb
  REAL(KIND=dp), ALLOCATABLE, SAVE :: NodalDer(:)
  LOGICAL :: HaveDer
  LOGICAL :: Reset

  INTEGER :: i, j, t, n, NMAX, NpN, e, p, q
  INTEGER, SAVE :: DOFs

  CHARACTER(LEN=MAX_NAME_LEN) :: ViscosityFlag

  LOGICAL :: Firsttime = .TRUE., Found, stat, GotIt
  LOGICAL, PARAMETER :: UnFoundFatal = .TRUE.


  SAVE Firsttime, DOFs
  SAVE ElementNodes
  SAVE SolverName
  SAVE FlowSolName, AdjointSolName, GradSolName
  SAVE VisitedNode, db, Basis, dBasisdx
  SAVE Ux, Uy
  SAVE c2n, c3n
  SAVE NodalViscosityb

  ! First visit: allocations and initialization
  IF (Firsttime) THEN

    DOFs = 2  ! BP always has 2 DOFs
    WRITE(SolverName, '(A)') 'AdjointBP_GradientMu'

    NMAX = Solver % Mesh % NumberOfNodes
    NpN = Model % MaxElementNodes

    ALLOCATE( VisitedNode(NMAX), db(NMAX), &
         Basis(NpN), dBasisdx(NpN,3), &
         Ux(NpN), Uy(NpN), &
         c2n(NpN), c3n(NpN), &
         NodalViscosityb(NpN) )

    ALLOCATE( NodalDer(NMAX) )

    ! Get solver variable names
    SolverParams => GetSolverParams()

    FlowSolName = GetString( SolverParams, 'Flow Solution Name', Found )
    IF (.NOT. Found) THEN
      CALL WARN(SolverName, 'Keyword >Flow Solution Name< not found in section >Solver<')
      CALL WARN(SolverName, 'Taking default value >HorizontalVelocity<')
      WRITE(FlowSolName,'(A)') 'HorizontalVelocity'
    END IF

    AdjointSolName = GetString( SolverParams, 'Adjoint Solution Name', Found )
    IF (.NOT. Found) THEN
      CALL WARN(SolverName, 'Keyword >Adjoint Solution Name< not found in section >Solver<')
      CALL WARN(SolverName, 'Taking default value >Adjoint<')
      WRITE(AdjointSolName,'(A)') 'Adjoint'
    END IF

    GradSolName = GetString( SolverParams, 'Gradient Variable Name', Found )
    IF (.NOT. Found) THEN
      CALL WARN(SolverName, 'Keyword >Gradient Variable Name< not found in section >Solver<')
      CALL WARN(SolverName, 'Taking default value >DJDMu<')
      WRITE(GradSolName,'(A)') 'DJDMu'
    END IF

    Firsttime = .FALSE.
  END IF

  SolverParams => GetSolverParams()

  ! Get gradient variable
  GradVariable => VariableGet( Solver % Mesh % Variables, GradSolName, UnFoundFatal=UnFoundFatal )
  GradValues => GradVariable % Values
  GradPerm => GradVariable % Perm
  Reset = ListGetLogical( SolverParams, 'Reset Gradient Variable', Found )
  IF (Reset .OR. (.NOT. Found)) GradValues = 0._dp

  ! Get forward flow solution
  FlowSol => VariableGet( Solver % Mesh % Variables, FlowSolName, UnFoundFatal=UnFoundFatal )
  FlowValues => FlowSol % Values
  FlowPerm => FlowSol % Perm

  ! Get adjoint solution
  AdjointSol => VariableGet( Solver % Mesh % Variables, AdjointSolName, UnFoundFatal=UnFoundFatal )
  AdjointValues => AdjointSol % Values
  AdjointPerm => AdjointSol % Perm

  VisitedNode = 0.0_dp
  db = 0.0_dp

  ! Loop over bulk elements
  Elements: DO e = 1, Solver % NumberOfActiveElements

    Element => GetActiveElement(e)
    Material => GetMaterial()
    CALL GetElementNodes( ElementNodes )
    n = GetElementNOFNodes()
    NodeIndexes => Element % NodeIndexes

    ! Get change-of-variable derivative for viscosity
    NodalDer(1:n) = ListGetReal( Material, 'Viscosity derivative', n, NodeIndexes, Found=HaveDer )

    VisitedNode(NodeIndexes(1:n)) = VisitedNode(NodeIndexes(1:n)) + 1.0_dp

    ! Extract nodal velocities from the flow solution
    Ux = 0.0_dp
    Uy = 0.0_dp
    Ux(1:n) = FlowValues( DOFs*(FlowPerm(NodeIndexes(1:n))-1) + 1 )
    Uy(1:n) = FlowValues( DOFs*(FlowPerm(NodeIndexes(1:n))-1) + 2 )

    NodalViscosityb = 0.0_dp

    IntegStuff = GaussPoints( Element )

    IPs: DO t = 1, IntegStuff % n

      u = IntegStuff % u(t)
      v = IntegStuff % v(t)
      w = IntegStuff % w(t)

      stat = ElementInfo( Element, ElementNodes, u, v, w, SqrtElementMetric, &
           Basis, dBasisdx )

      s = SqrtElementMetric * IntegStuff % s(t)

      ! Compute mub: sensitivity of the bilinear form w.r.t. viscosity.
      ! The BP stiffness matrix (divided by mu) has the structure:
      !
      !   K_11(p,q)/mu = 4*dN_p/dx*dN_q/dx + dN_p/dy*dN_q/dy + dN_p/dz*dN_q/dz
      !   K_12(p,q)/mu = 2*dN_p/dx*dN_q/dy + dN_p/dy*dN_q/dx
      !   K_21(p,q)/mu = 2*dN_p/dy*dN_q/dx + dN_p/dx*dN_q/dy
      !   K_22(p,q)/mu = dN_p/dx*dN_q/dx + 4*dN_p/dy*dN_q/dy + dN_p/dz*dN_q/dz
      !
      ! The gradient is: mub = - sum_{p,q,i,j} (K_ij(p,q)/mu) * u_forward(q,j) * lambda(p,i)
      !
      mub = 0.0_dp
      DO p = 1, n
        DO q = 1, n

          ! Block (1,1): forward u * adjoint u
          mub = mub + s * ( &
               4.0_dp * dBasisdx(p,1) * dBasisdx(q,1) + &
               dBasisdx(p,2) * dBasisdx(q,2) + &
               dBasisdx(p,3) * dBasisdx(q,3) ) * &
               (- Ux(q) * AdjointValues( DOFs*(AdjointPerm(NodeIndexes(p))-1) + 1 ) )

          ! Block (1,2): forward v * adjoint u
          mub = mub + s * ( &
               2.0_dp * dBasisdx(p,1) * dBasisdx(q,2) + &
               dBasisdx(p,2) * dBasisdx(q,1) ) * &
               (- Uy(q) * AdjointValues( DOFs*(AdjointPerm(NodeIndexes(p))-1) + 1 ) )

          ! Block (2,1): forward u * adjoint v
          mub = mub + s * ( &
               2.0_dp * dBasisdx(p,2) * dBasisdx(q,1) + &
               dBasisdx(p,1) * dBasisdx(q,2) ) * &
               (- Ux(q) * AdjointValues( DOFs*(AdjointPerm(NodeIndexes(p))-1) + 2 ) )

          ! Block (2,2): forward v * adjoint v
          mub = mub + s * ( &
               dBasisdx(p,1) * dBasisdx(q,1) + &
               4.0_dp * dBasisdx(p,2) * dBasisdx(q,2) + &
               dBasisdx(p,3) * dBasisdx(q,3) ) * &
               (- Uy(q) * AdjointValues( DOFs*(AdjointPerm(NodeIndexes(p))-1) + 2 ) )

        END DO
      END DO

      ! Apply power-law viscosity chain rule
      ViscosityFlag = ListGetString( Material, 'Viscosity Model', GotIt, UnFoundFatal )

      SELECT CASE( ViscosityFlag )
      CASE('power law')
        ! Compute velocity gradients at integration point (2 velocity components, 3 spatial dims)
        DO j = 1, 3
          dVelodx(1,j) = SUM( Ux(1:n) * dBasisdx(1:n,j) )
          dVelodx(2,j) = SUM( Uy(1:n) * dBasisdx(1:n,j) )
        END DO

        ! Compute second invariant using the BP-specific formula
        ! (from HydrostaticNSVec.F90 EffectiveViscosityVec, lines 252-254)
        ! ss = 4 * (du/dx^2 + dv/dy^2 + du/dx*dv/dy
        !        + 0.5*du/dy*dv/dx
        !        + 0.25*(du/dy^2 + du/dz^2 + dv/dx^2 + dv/dz^2))
        ! s_inv = ss / 4  (to normalize, compatible with IncompressibleNS convention)
        ss = 4.0_dp * ( &
             dVelodx(1,1)**2 + dVelodx(2,2)**2 + &
             dVelodx(1,1) * dVelodx(2,2) + &
             0.5_dp * dVelodx(1,2) * dVelodx(2,1) + &
             0.25_dp * (dVelodx(1,2)**2 + dVelodx(1,3)**2 + &
                        dVelodx(2,1)**2 + dVelodx(2,3)**2) )

        ! The second invariant of the strain rate for the power-law model
        ! (same normalization as used in EffectiveViscosityVec for Glen model)
        ss = ss / 4.0_dp

        ! Get viscosity exponent (c2 = 1/n for Glen, typically 1/3)
        c2n = ListGetReal( Material, 'Viscosity Exponent', n, NodeIndexes )
        c2 = SUM( Basis(1:n) * c2n(1:n) )

        ! Apply critical shear rate regularization if present
        c3n = ListGetReal( Material, 'Critical Shear Rate', n, NodeIndexes, GotIt )
        IF (GotIt) THEN
          c3 = SUM( Basis(1:n) * c3n(1:n) )
          IF (ss < c3**2) THEN
            ss = c3**2
          END IF
        END IF

        ! Apply the power-law chain rule factor
        ! mu_eff = mu0 * ss^((c2-1)/2), so dmu_eff/dmu0 = ss^((c2-1)/2)
        Viscosityb = mub * ss**((c2 - 1.0_dp) / 2.0_dp)

      CASE('glen')
        ! Glen's law: mu = 0.5 * A^(-1/n) * (strain_rate_invariant)^((1/n-1)/2)
        ! For this model the second invariant computation is different.
        ! We follow the BP EffectiveViscosityVec for Glen model.
        DO j = 1, 3
          dVelodx(1,j) = SUM( Ux(1:n) * dBasisdx(1:n,j) )
          dVelodx(2,j) = SUM( Uy(1:n) * dBasisdx(1:n,j) )
        END DO

        ss = 4.0_dp * ( &
             dVelodx(1,1)**2 + dVelodx(2,2)**2 + &
             dVelodx(1,1) * dVelodx(2,2) + &
             0.5_dp * dVelodx(1,2) * dVelodx(2,1) + &
             0.25_dp * (dVelodx(1,2)**2 + dVelodx(1,3)**2 + &
                        dVelodx(2,1)**2 + dVelodx(2,3)**2) )
        ss = ss / 4.0_dp

        c2n = ListGetReal( Material, 'Glen Exponent', n, NodeIndexes )
        c2 = SUM( Basis(1:n) * c2n(1:n) )
        ! For Glen: exponent is 1/n, so the power-law factor is ss^((1/n-1)/2)
        c2 = 1.0_dp / c2

        c3n = ListGetReal( Material, 'Critical Shear Rate', n, NodeIndexes, GotIt )
        IF (GotIt) THEN
          c3 = SUM( Basis(1:n) * c3n(1:n) )
          IF (ss < c3**2) THEN
            ss = c3**2
          END IF
        END IF

        Viscosityb = mub * ss**((c2 - 1.0_dp) / 2.0_dp)

      CASE DEFAULT
        CALL FATAL(SolverName, 'Viscosity Model must be "power law" or "glen"')
      END SELECT

      NodalViscosityb(1:n) = NodalViscosityb(1:n) + Viscosityb * Basis(1:n)
    END DO IPs

    ! Apply change-of-variable derivative if present
    IF (HaveDer) THEN
      NodalViscosityb(1:n) = NodalViscosityb(1:n) * NodalDer(1:n)
    END IF

    db(NodeIndexes(1:n)) = db(NodeIndexes(1:n)) + NodalViscosityb(1:n)
  END DO Elements

  ! Assemble nodal gradient values
  DO t = 1, Solver % Mesh % NumberOfNodes
    IF (VisitedNode(t) < 1.0_dp) CYCLE
    GradValues(GradPerm(t)) = db(t)
  END DO

  RETURN

!------------------------------------------------------------------------------
END SUBROUTINE AdjointBP_GradientMuSolver
!------------------------------------------------------------------------------
