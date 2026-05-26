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
! *  Adjoint of the Blatter-Pattyn problem for the slip coefficient.
! *  Provides the derivative of the cost function w.r.t. the basal
! *  friction parameter (slip coefficient / Weertman friction coefficient).
! *
! *  Adapted from AdjointStokes_GradientBetaSolver.F90 for the
! *  Blatter-Pattyn (HydrostaticNS) solver which has 2 DOFs (u,v).
! *
! *  This is a boundary solver to be executed on the bed boundary.
! *
! *  Requires:
! *    - Forward BP solution (HorizontalVelocity)
! *    - Adjoint solution
! *    - Gradient variable to store dJ/dBeta
! *
! *  SIF keywords:
! *    In Solver section:
! *      Flow Solution Name = String (default "HorizontalVelocity")
! *      Adjoint Solution Name = String (default "Adjoint")
! *      Gradient Variable Name = String (default "DJDBeta")
! *      Reset Gradient Variable = Logical (default True)
! *
! *    In Boundary Condition section (optional, for Weertman friction):
! *      Weertman Friction Coefficient
! *      Weertman Exponent
! *      Friction Linear Velocity
! *      Slip Coefficient derivative (for change of variable)
! *
! *****************************************************************************
SUBROUTINE AdjointBP_GradientBetaSolver_init0(Model,Solver,dt,TransientSimulation)
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

END SUBROUTINE AdjointBP_GradientBetaSolver_init0
! *****************************************************************************
SUBROUTINE AdjointBP_GradientBetaSolver( Model, Solver, dt, TransientSimulation )
!------------------------------------------------------------------------------
  USE DefUtils
  IMPLICIT NONE
!------------------------------------------------------------------------------
  TYPE(Solver_t) :: Solver
  TYPE(Model_t) :: Model
  REAL(KIND=dp) :: dt
  LOGICAL :: TransientSimulation
!
  TYPE(ValueList_t), POINTER :: SolverParams
  TYPE(ValueList_t), POINTER :: BC

  CHARACTER(LEN=MAX_NAME_LEN) :: SolverName = "AdjointBP_GradientBeta"

  INTEGER, SAVE :: DOFs  ! Should be 2 for BP

  CHARACTER(LEN=MAX_NAME_LEN), SAVE :: FlowSolName, AdjointSolName
  TYPE(Variable_t), POINTER :: FlowSol, AdjointSol
  REAL(KIND=dp), POINTER :: FlowValues(:), AdjointValues(:)
  INTEGER, POINTER :: FlowPerm(:), AdjointPerm(:)

  CHARACTER(LEN=MAX_NAME_LEN), SAVE :: GradSolName
  TYPE(Variable_t), POINTER :: GradVariable
  REAL(KIND=dp), POINTER :: GradValues(:)
  INTEGER, POINTER :: GradPerm(:)

  TYPE(Element_t), POINTER :: Element
  TYPE(Nodes_t), SAVE :: ElementNodes
  INTEGER, POINTER :: NodeIndexes(:)
  TYPE(GaussIntegrationPoints_t) :: IntegStuff
  REAL(KIND=dp) :: u, v, w, SqrtElementMetric, s
  REAL(KIND=dp), ALLOCATABLE, SAVE :: Basis(:), dBasisdx(:,:)
  INTEGER :: n

  REAL(KIND=dp) :: betab
  REAL(KIND=dp), ALLOCATABLE, SAVE :: NodalDer(:), NodalGrad(:)
  LOGICAL :: HaveDer

  INTEGER :: NMAX

  INTEGER :: i, j, p, q, e, t

  LOGICAL :: Found, stat
  LOGICAL :: Reset
  LOGICAL, SAVE :: Firsttime = .TRUE.
  LOGICAL, PARAMETER :: UnFoundFatal = .TRUE.

  TYPE(ValueHandle_t), SAVE :: WeertmanCoeff_h, WeertmanExp_h, FrictionUt0_h
  TYPE(VariableHandle_t), SAVE :: Velo_v
  LOGICAL :: HaveFrictionW
  REAL(KIND=dp) :: wut0, wexp, wcoeff
  REAL(KIND=dp) :: Velo(3), ut, TanFrictionCoeff


  SolverParams => GetSolverParams()

  IF (Firsttime) THEN

    DOFs = 2  ! BP always has 2 DOFs (u,v horizontal velocities)

    NMAX = Model % MaxElementNodes
    ALLOCATE( Basis(NMAX), dBasisdx(NMAX,3) )
    ALLOCATE( NodalDer(NMAX), NodalGrad(NMAX) )

    ! Get solver variable names
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
      CALL WARN(SolverName, 'Taking default value >DJDBeta<')
      WRITE(GradSolName,'(A)') 'DJDBeta'
    END IF

    ! Initialize handles for Weertman friction
    CALL ListInitElementKeyword( WeertmanCoeff_h, 'Boundary Condition', 'Weertman Friction Coefficient' )
    CALL ListInitElementKeyword( WeertmanExp_h, 'Boundary Condition', 'Weertman Exponent' )
    CALL ListInitElementKeyword( FrictionUt0_h, 'Boundary Condition', 'Friction Linear Velocity' )
    CALL ListInitElementVariable( Velo_v, FlowSolName, Found=Found )
    IF (.NOT. Found) &
      CALL FATAL(SolverName, TRIM(FlowSolName)//' Variable not found')

    Firsttime = .FALSE.
  END IF

  ! Get gradient variable
  GradVariable => VariableGet( Model % Mesh % Variables, GradSolName, UnFoundFatal=UnFoundFatal )
  GradValues => GradVariable % Values
  GradPerm => GradVariable % Perm
  Reset = ListGetLogical( SolverParams, 'Reset Gradient Variable', Found )
  IF (Reset .OR. (.NOT. Found)) GradValues = 0._dp

  ! Get forward flow solution
  FlowSol => VariableGet( Model % Mesh % Variables, FlowSolName, UnFoundFatal=UnFoundFatal )
  FlowValues => FlowSol % Values
  FlowPerm => FlowSol % Perm

  ! Get adjoint solution
  AdjointSol => VariableGet( Model % Mesh % Variables, AdjointSolName, UnFoundFatal=UnFoundFatal )
  AdjointValues => AdjointSol % Values
  AdjointPerm => AdjointSol % Perm

  ! Loop over boundary elements
  DO e = 1, Solver % NumberOfActiveElements
    Element => GetActiveElement(e)
    CALL GetElementNodes( ElementNodes )
    n = GetElementNOFNodes(Element)
    NodeIndexes => Element % NodeIndexes

    ! Verify this is a boundary element
    BC => GetBC(Element)
    IF (.NOT. ASSOCIATED(BC)) &
      CALL FATAL(SolverName, 'This solver is intended to be executed on a BC')

    ! Check for Weertman friction law
    HaveFrictionW = ListCheckPresent( BC, 'Weertman Friction Coefficient' )
    IF (HaveFrictionW) THEN
      wut0 = ListGetElementReal( FrictionUt0_h, Element = Element )
    END IF

    ! Get change-of-variable derivative if provided
    NodalDer(1:n) = ListGetReal( BC, 'Slip Coefficient derivative', n, NodeIndexes, Found=HaveDer )

    ! Numerical integration over boundary element
    IntegStuff = GaussPoints( Element )
    DO t = 1, IntegStuff % n
      u = IntegStuff % u(t)
      v = IntegStuff % v(t)
      w = IntegStuff % w(t)
      stat = ElementInfo( Element, ElementNodes, u, v, w, SqrtElementMetric, &
           Basis, dBasisdx )

      s = SqrtElementMetric * IntegStuff % s(t)

      ! Compute gradient contribution at this integration point.
      ! For BP, friction is always in the horizontal (x,y) plane.
      ! The slip contribution to the stiffness matrix is:
      !   STIFF((p-1)*2+i, (q-1)*2+i) += s * SlipCoeff(i) * Basis(q) * Basis(p)
      ! where i = 1,2 (u,v components), and SlipCoeff is the same for both.
      !
      ! The adjoint gradient is:
      !   dJ/dBeta = - sum_{p,q,i} s * Basis(q) * Basis(p) * u_forward(q,i) * lambda(p,i)
      !
      betab = 0.0_dp
      DO p = 1, n
        DO q = 1, n
          DO i = 1, DOFs  ! i = 1 (u), 2 (v)
            betab = betab + s * Basis(q) * Basis(p) * &
                 (- FlowValues( DOFs*(FlowPerm(NodeIndexes(q))-1) + i ) * &
                    AdjointValues( DOFs*(AdjointPerm(NodeIndexes(p))-1) + i ) )
          END DO
        END DO
      END DO

      ! Apply change-of-variable derivative if present
      IF (HaveDer) THEN
        NodalGrad(1:n) = Basis(1:n) * NodalDer(1:n)
      ELSE
        NodalGrad(1:n) = Basis(1:n)
      END IF

      ! Apply Weertman nonlinearity if present
      IF (HaveFrictionW) THEN
        ! Get velocity at integration point
        Velo = ListGetElementVectorSolution( Velo_v, Basis, Element, dofs = DOFs )
        ut = MAX(wut0, SQRT(SUM(Velo(1:DOFs)**2)))

        wcoeff = ListGetElementReal( WeertmanCoeff_h, Basis, Element, GaussPoint = t )
        wexp = ListGetElementReal( WeertmanExp_h, Basis, Element, GaussPoint = t )
        TanFrictionCoeff = wcoeff * ut**(wexp-1.0_dp)
        IF (TanFrictionCoeff .GE. 1.0e20) THEN
          betab = 0._dp
        ELSE
          betab = betab * ut**(wexp-1.0_dp)
        END IF
      END IF

      ! Accumulate gradient at nodes
      GradValues(GradPerm(NodeIndexes(1:n))) = GradValues(GradPerm(NodeIndexes(1:n))) &
           + betab * NodalGrad(1:n)

    END DO  ! integration points

  END DO  ! elements

  RETURN

!------------------------------------------------------------------------------
END SUBROUTINE AdjointBP_GradientBetaSolver
!------------------------------------------------------------------------------
