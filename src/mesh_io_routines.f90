!> \file
!> $Id$
!> \author Chris Bradley
!> \brief This module handles all Hamilton-Jacobi equations routines.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is OpenCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand and University of Oxford, Oxford, United
!> Kingdom. Portions created by the University of Auckland and University
!> of Oxford are Copyright (C) 2007 by the University of Auckland and
!> the University of Oxford. All Rights Reserved.
!>
!> Contributor(s):
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!>This module handles all Hamilton-Jacobi equations routines.
MODULE MESH_IO_ROUTINES

  USE BASE_ROUTINES
  USE BASIS_ROUTINES
  USE CONSTANTS
  USE COMP_ENVIRONMENT
  USE CONTROL_LOOP_ROUTINES
  USE COORDINATE_ROUTINES
  USE DISTRIBUTED_MATRIX_VECTOR
  USE DOMAIN_MAPPINGS
  USE EQUATIONS_SET_CONSTANTS
  USE FIELD_ROUTINES
  USE INPUT_OUTPUT
  USE ISO_VARYING_STRING
  USE KINDS
  USE MATRIX_VECTOR
  USE MATHS
  USE MESH_ROUTINES
  USE NODE_ROUTINES
  USE PROBLEM_CONSTANTS
  USE REGION_ROUTINES
  USE STRINGS
  USE SOLVER_ROUTINES
  USE TIMER
  USE TYPES

  IMPLICIT NONE

  PRIVATE

  !Module parameters

  !Module types

  !Module variables

  !Interfaces
  
  PUBLIC READ_TETGEN_MESH,WRITE_VTK_MESH

CONTAINS

  !
  !================================================================================================================================
  !

  SUBROUTINE READ_TETGEN_MESH(INPUT_FILE_NAME,WORLD_REGION,MESH,GEOMETRIC_FIELD,ERR,ERROR,*)
    !subroutine parameters
    TYPE(VARYING_STRING), INTENT(IN) :: INPUT_FILE_NAME
    TYPE(REGION_TYPE), INTENT(IN), POINTER :: WORLD_REGION
    TYPE(MESH_TYPE), INTENT(INOUT), POINTER :: MESH
    TYPE(FIELD_TYPE), INTENT(INOUT), POINTER :: GEOMETRIC_FIELD
    INTEGER(INTG), INTENT(OUT) :: ERR
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    
    !local variables
    !CHARACTER (LEN=300) :: TEMP_STRING
    INTEGER(INTG) :: TEXT_LENGTH, NUMBER_OF_NODES, NUMBER_OF_ELEMENTS, NUMBER_OF_NODE_COMPONENTS, &
        & NUMBER_OF_ELEMENT_COMPONENTS, ELEMENT_ID, NODE_ID, NUMBER_OF_PROCESSORS, TEMP_INT, i, j
    INTEGER(INTG), ALLOCATABLE :: ELEMENT_NODES(:)
    REAL(DP), ALLOCATABLE :: NODE_COORDINATES(:)
    TYPE(VARYING_STRING) :: INPUT_FILE_NAME_NODES
    TYPE(COORDINATE_SYSTEM_TYPE), POINTER :: COORDINATE_SYSTEM
    TYPE(NODES_TYPE), POINTER :: NODES
    TYPE(MESH_ELEMENTS_TYPE), POINTER :: ELEMENTS
    TYPE(REGION_TYPE), POINTER :: REGION
    TYPE(BASIS_TYPE), POINTER :: BASIS
    TYPE(DECOMPOSITION_TYPE), POINTER :: DECOMPOSITION
    
    CALL ENTERS("READ_TETGEN_MESH",ERR,ERROR,*999)
    
    OPEN (11,FILE=CHAR(INPUT_FILE_NAME//".node"))
    READ (11,*) NUMBER_OF_NODES, NUMBER_OF_NODE_COMPONENTS, TEMP_INT, TEMP_INT
    !PRINT *,"Read Tetgen Mesh - #Nodes: ",NUMBER_OF_NODES
    !PRINT *,"Read Tetgen Mesh - Dimension: ",NUMBER_OF_NODE_COMPONENTS
    
    OPEN (12,FILE=CHAR(INPUT_FILE_NAME//".ele"))
    READ (12,*) NUMBER_OF_ELEMENTS, NUMBER_OF_ELEMENT_COMPONENTS, TEMP_INT
    !PRINT *,"Read Tetgen Mesh - #Elements: ",NUMBER_OF_ELEMENTS
    !PRINT *,"Read Tetgen Mesh - Element components: ",NUMBER_OF_ELEMENT_COMPONENTS
    
    ! Create coordinate system
    NULLIFY(COORDINATE_SYSTEM)
    CALL COORDINATE_SYSTEM_CREATE_START(77000,COORDINATE_SYSTEM,ERR,ERROR,*999)
    CALL COORDINATE_SYSTEM_CREATE_FINISH(COORDINATE_SYSTEM,ERR,ERROR,*999)
    
    ! Create region and assign coordinate system to it
    NULLIFY(REGION)
    CALL REGION_CREATE_START(77000,WORLD_REGION,REGION,ERR,ERROR,*999)
    CALL REGION_COORDINATE_SYSTEM_SET(REGION,COORDINATE_SYSTEM,ERR,ERROR,*999)
    CALL REGION_CREATE_FINISH(REGION,ERR,ERROR,*999)
    
    ! Create linear basis
    NULLIFY(BASIS)
    CALL BASIS_CREATE_START(77000,BASIS,ERR,ERROR,*999)
    CALL BASIS_TYPE_SET(BASIS,BASIS_SIMPLEX_TYPE,ERR,ERROR,*999)
    CALL BASIS_INTERPOLATION_XI_SET(BASIS,(/BASIS_LINEAR_SIMPLEX_INTERPOLATION,BASIS_LINEAR_SIMPLEX_INTERPOLATION, &
        & BASIS_LINEAR_SIMPLEX_INTERPOLATION/),ERR,ERROR,*999)
    CALL BASIS_CREATE_FINISH(BASIS,ERR,ERROR,*999)
    
    !Create mesh
    NULLIFY(MESH)
    CALL MESH_CREATE_START(77000,REGION,NUMBER_OF_NODE_COMPONENTS,MESH,ERR,ERROR,*999)
    
    ! Create nodes
    NULLIFY(NODES)
    CALL NODES_CREATE_START(REGION,NUMBER_OF_NODES,NODES,ERR,ERROR,*999)
    CALL NODES_CREATE_FINISH(NODES,ERR,ERROR,*999)
    
    ! Create elements
    CALL MESH_NUMBER_OF_COMPONENTS_SET(MESH,1,ERR,ERROR,*999)
    CALL MESH_NUMBER_OF_ELEMENTS_SET(MESH,NUMBER_OF_ELEMENTS,ERR,ERROR,*999)
    NULLIFY(ELEMENTS)
    CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,1,BASIS,ELEMENTS,ERR,ERROR,*999)
    ALLOCATE(ELEMENT_NODES(NUMBER_OF_ELEMENT_COMPONENTS),STAT=ERR)
    DO i=1,NUMBER_OF_ELEMENTS
      READ (12,*) ELEMENT_ID,ELEMENT_NODES
      CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(ELEMENT_ID,ELEMENTS,ELEMENT_NODES,Err,ERROR,*999)
    ENDDO
    DEALLOCATE(ELEMENT_NODES)
    CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(ELEMENTS,ERR,ERROR,*999)
    
    CALL MESH_CREATE_FINISH(MESH,ERR,ERROR,*999)
    
    !Calculate decomposition
    NULLIFY(DECOMPOSITION)
    NUMBER_OF_PROCESSORS = COMPUTATIONAL_NODES_NUMBER_GET(ERR,ERROR)
    CALL DECOMPOSITION_CREATE_START(77000,MESH,DECOMPOSITION,ERR,ERROR,*999)
    CALL DECOMPOSITION_TYPE_SET(DECOMPOSITION,DECOMPOSITION_CALCULATED_TYPE,ERR,ERROR,*999)
    CALL DECOMPOSITION_NUMBER_OF_DOMAINS_SET(DECOMPOSITION,NUMBER_OF_PROCESSORS,ERR,ERROR,*999)
    CALL DECOMPOSITION_CREATE_FINISH(DECOMPOSITION,ERR,ERROR,*999)

    !Create a field to put the geometry
    NULLIFY(GEOMETRIC_FIELD)
    CALL FIELD_CREATE_START(77000,REGION,GEOMETRIC_FIELD,ERR,ERROR,*999)
    CALL FIELD_MESH_DECOMPOSITION_SET(GEOMETRIC_FIELD,DECOMPOSITION,ERR,ERROR,*999)
    CALL FIELD_TYPE_SET(GEOMETRIC_FIELD,FIELD_GEOMETRIC_TYPE,ERR,ERROR,*999)
    CALL FIELD_NUMBER_OF_VARIABLES_SET(GEOMETRIC_FIELD,1,ERR,ERROR,*999)
    CALL FIELD_NUMBER_OF_COMPONENTS_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,NUMBER_OF_NODE_COMPONENTS,Err,ERROR,*999)
    DO i=1,NUMBER_OF_NODE_COMPONENTS
      CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,i,1,ERR,ERROR,*999)
    ENDDO
    CALL FIELD_CREATE_FINISH(GEOMETRIC_FIELD,ERR,ERROR,*999)

    !Set node positions
    ALLOCATE(NODE_COORDINATES(NUMBER_OF_NODE_COMPONENTS),STAT=ERR)
    DO i=1,NUMBER_OF_NODES
      READ (11,*) NODE_ID,NODE_COORDINATES
      DO j=1,NUMBER_OF_NODE_COMPONENTS
        CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,i,j, &
          & NODE_COORDINATES(j),ERR,ERROR,*999)
      ENDDO
    ENDDO
    DEALLOCATE(NODE_COORDINATES)
    
    CLOSE(11)
    CLOSE(12)
    
    CALL EXITS("READ_TETGEN_MESH")
    RETURN
999 CALL ERRORS("READ_TETGEN_MESH",ERR,ERROR)
    CALL EXITS("READ_TETGEN_MESH")
    RETURN 1
    
  END SUBROUTINE READ_TETGEN_MESH

  !
  !================================================================================================================================
  !

  SUBROUTINE WRITE_VTK_MESH(OUTPUT_FILE_NAME,MESH,GEOMETRIC_FIELD,ERR,ERROR,*)
    !subroutine parameters
    TYPE(VARYING_STRING), INTENT(IN) :: OUTPUT_FILE_NAME
    TYPE(MESH_TYPE), INTENT(IN), POINTER :: MESH
    TYPE(FIELD_TYPE), INTENT(IN), POINTER :: GEOMETRIC_FIELD
    INTEGER(INTG), INTENT(OUT) :: ERR
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    
    !local variables
    INTEGER(INTG) :: NUMBER_OF_DIMENSIONS, NUMBER_OF_NODES, node_idx, dim_idx, local_ny, ne, &
            & NUMBER_OF_NODES_PER_ELEMENT, i
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: GEOMETRIC_VARIABLE
    REAL(DP), POINTER :: GEOMETRIC_PARAMETERS(:)
    TYPE(DOMAIN_ELEMENTS_TYPE), POINTER :: ELEMENTS
    
    CALL ENTERS("WRITE_VTK_MESH",ERR,ERROR,*999)
    
    OPEN (12,FILE=CHAR(OUTPUT_FILE_NAME // ".vtk"))
    
    WRITE(12,'(A)')"# vtk DataFile Version 3.0"
    WRITE(12,'(A)')"vtk output"
    WRITE(12,'(A)')"ASCII"
    WRITE(12,'(A)')"DATASET UNSTRUCTURED_GRID"
    
    CALL FIELD_NUMBER_OF_COMPONENTS_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
    NULLIFY(GEOMETRIC_VARIABLE)
    CALL FIELD_VARIABLE_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,GEOMETRIC_VARIABLE,ERR,ERROR,*999)
    CALL FIELD_PARAMETER_SET_DATA_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,GEOMETRIC_PARAMETERS, &
            & ERR,ERROR,*999)
    
    NUMBER_OF_NODES=GEOMETRIC_VARIABLE%COMPONENTS(1)%DOMAIN%TOPOLOGY%NODES%NUMBER_OF_NODES
    WRITE(12,'(A,I8,A6)')"POINTS",NUMBER_OF_NODES,"float"
    
    DO node_idx=1,NUMBER_OF_NODES
      DO dim_idx=1,NUMBER_OF_DIMENSIONS
        local_ny=GEOMETRIC_VARIABLE%COMPONENTS(dim_idx)%PARAM_TO_DOF_MAP%NODE_PARAM2DOF_MAP(1,node_idx)
        WRITE(12,*) GEOMETRIC_PARAMETERS(local_ny)
      ENDDO
    ENDDO
    
    ELEMENTS=>GEOMETRIC_FIELD%DECOMPOSITION%DOMAIN(GEOMETRIC_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
            & TOPOLOGY%ELEMENTS
    NUMBER_OF_NODES_PER_ELEMENT=size(ELEMENTS%ELEMENTS(1)%ELEMENT_NODES,1)
    WRITE(12,'(A,I8,I8)')"CELLS ",ELEMENTS%TOTAL_NUMBER_OF_ELEMENTS,ELEMENTS% &
            & TOTAL_NUMBER_OF_ELEMENTS*(NUMBER_OF_NODES_PER_ELEMENT+1)
    DO ne=1,ELEMENTS%TOTAL_NUMBER_OF_ELEMENTS
      WRITE(12,*) NUMBER_OF_NODES_PER_ELEMENT, &
            & ((ELEMENTS%ELEMENTS(ne)%ELEMENT_NODES(i)-1),i=1,size(ELEMENTS%ELEMENTS(ne)%ELEMENT_NODES,1))
    ENDDO
    
    WRITE(12,'(A,I8)')"CELL_TYPES",ELEMENTS%TOTAL_NUMBER_OF_ELEMENTS
    DO ne=1,ELEMENTS%TOTAL_NUMBER_OF_ELEMENTS
      WRITE(12,'(A)') "10"
    ENDDO
    
    WRITE(12,'(A,I8)')"CELL_DATA",ELEMENTS%TOTAL_NUMBER_OF_ELEMENTS
    WRITE(12,'(A,I8)')"POINT_DATA",NUMBER_OF_NODES
    
    !      export FIELD information
    !WRITE(12,'(A,A)')"FIELD number"," 1"
    !WRITE(12,'(A,I3,I8,A6)')OUTPUT_FILE_FIELD_TITLE,1,TOTAL_NUMBER_OF_NODES,"float"
    !DO I=1,TOTAL_NUMBER_OF_NODES
    !WRITE(12,'(F15.10)') SEED_VALUE(I)
    !ENDDO
    
    !      export VECTORS information
    !WRITE(12,'(A,A,A6)') "VECTORS ","fiber_vector","float"
    !DO I=1,TOTAL_NUMBER_OF_NODES
    !WRITE(12,'(3F8.5)') (CONDUCTIVITY_TENSOR(I,J),J=1,3)
    !ENDDO
    
    CLOSE(12)
    
    CALL EXITS("WRITE_VTK_MESH")
    RETURN
999 CALL ERRORS("WRITE_VTK_MESH",ERR,ERROR)
    CALL EXITS("WRITE_VTK_MESH")
    RETURN 1
    
  END SUBROUTINE WRITE_VTK_MESH
  
  
  
END MODULE MESH_IO_ROUTINES

