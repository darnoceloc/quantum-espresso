!
! Copyright (C) 2001-2005 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
#include "f_defs.h"
!
!-----------------------------------------------------------------------
PROGRAM postproc
  !-----------------------------------------------------------------------
  !
  !    Program for data analysis and plotting. The two basic steps are:
  !    1) read the output file produced by pw.x, extract and calculate
  !       the desired quantity (rho, V, ...)
  !    2) write the desired quantity to file in a suitable format for
  !       various types of plotting and various plotting programs
  !    The two steps can be performed independently. Intermediate data
  !    can be saved to file in step 1 and read from file in step 2.
  !
  !    DESCRIPTION of the INPUT : see file Docs/INPUT_PP
  !
  USE io_files,  ONLY : nd_nmbr
  USE io_global, ONLY : ionode
  !
  IMPLICIT NONE
  CHARACTER(len=256) :: filplot
  !
  ! initialise parallel environment
  !
  CALL start_postproc (nd_nmbr)
  IF ( ionode )  CALL input_from_file ( )
  !
  call extract (filplot) 
  !
  call clean_pw( .TRUE. )
  !
  ! chdens should be called on just one processor
  !
  IF ( ionode ) call chdens (filplot)
  !
  call stop_pp()
  !
END PROGRAM postproc
!
!-----------------------------------------------------------------------
SUBROUTINE extract (filplot)
  !-----------------------------------------------------------------------
  !
  !    This subroutine reads the data for the output file produced by pw.x
  !    extracts and calculates the desired quantity (rho, V, ...)
  !    writes it to a file for further processing or plotting
  !
  !    DESCRIPTION of the INPUT: see file Docs/INPUT_PP
  !
  USE kinds,     ONLY : DP
  USE cell_base, ONLY : bg
  USE ener,      ONLY : ef
  USE ions_base, ONLY : nat, ntyp=>nsp, ityp, tau
  USE gvect
  USE vlocal,    ONLY : strf
  USE io_files,  ONLY : tmp_dir, prefix, trimcheck
  USE io_global, ONLY : ionode, ionode_id
  USE mp,        ONLY : mp_bcast

  IMPLICIT NONE
  CHARACTER(len=256), INTENT(out) :: filplot

  INTEGER :: plot_num, kpoint, kband, spin_component, ios, flen
  LOGICAL :: stm_wfc_matching, lsign

  REAL(DP) :: emin, emax, sample_bias, z, dz, epsilon
  ! directory for temporary files
  CHARACTER(len=256) :: outdir

  NAMELIST / inputpp / outdir, prefix, plot_num, stm_wfc_matching, &
       sample_bias, spin_component, z, dz, emin, emax, kpoint, kband,&
       filplot, lsign, epsilon

  !
  !   set default values for variables in namelist
  !
  prefix = 'pwscf'
  CALL get_env( 'ESPRESSO_TMPDIR', outdir )
  IF ( TRIM( outdir ) == ' ' ) outdir = './'
  filplot = 'tmp.pp' 
  plot_num = -1
  spin_component = 0
  sample_bias = 0.01d0
  z = 1.d0
  dz = 0.05d0
  stm_wfc_matching = .TRUE.
  lsign=.FALSE.
  emin = -999.0d0
  emax = +999.0d0
  epsilon=1.d0
  !
  IF ( ionode )  THEN
     !
     !     reading the namelist inputpp
     !
     READ (5, inputpp, err = 200, iostat = ios)
200  CALL errore ('postproc', 'reading inputpp namelist', ABS (ios) )
     !
     tmp_dir = trimcheck ( outdir )
     !
  END IF
  !
  ! ... Broadcast variables
  !
  CALL mp_bcast( tmp_dir, ionode_id )
  CALL mp_bcast( prefix, ionode_id )
  CALL mp_bcast( plot_num, ionode_id )
  CALL mp_bcast( stm_wfc_matching, ionode_id )
  CALL mp_bcast( sample_bias, ionode_id )
  CALL mp_bcast( spin_component, ionode_id )
  CALL mp_bcast( z, ionode_id )
  CALL mp_bcast( dz, ionode_id )
  CALL mp_bcast( emin, ionode_id )
  CALL mp_bcast( emax, ionode_id )
  CALL mp_bcast( kband, ionode_id )
  CALL mp_bcast( kpoint, ionode_id )
  CALL mp_bcast( filplot, ionode_id )
  CALL mp_bcast( lsign, ionode_id )
  CALL mp_bcast( epsilon, ionode_id )
  !
  ! no task specified: do nothing and return
  !
  IF (plot_num == -1) return
  !
  IF (plot_num < 0 .OR. plot_num > 16) CALL errore ('postproc', &
          'Wrong plot_num', ABS (plot_num) )

  IF (plot_num == 13) THEN
     IF  (spin_component < 0 .OR. spin_component > 3) CALL errore &
          ('postproc', 'wrong spin_component', 1)
  ELSE
     IF (spin_component < 0 ) CALL errore &
         ('postproc', 'wrong value of spin_component', 1)
  END IF
  !
  !   Now allocate space for pwscf variables, read and check them.
  !
  CALL read_file ( )
  CALL openfil_pp ( )
  CALL struc_fact (nat, tau, ntyp, ityp, ngm, g, bg, nr1, nr2, nr3, &
       strf, eigts1, eigts2, eigts3)
  CALL init_us_1 ( )
  !
  ! The following line sets emax to its default value if not set
  ! It is done here because Ef must be read from file
  !
  IF (emax == +999.0d0) emax = ef
  IF (plot_num == 10) THEN
     emin = emin / 13.6058d0
     emax = emax / 13.6058d0
  END IF
  !
  !
  !   Now do whatever you want
  !
  CALL punch_plot (filplot, plot_num, sample_bias, z, dz, &
       stm_wfc_matching, emin, emax, kpoint, kband, spin_component, &
       lsign, epsilon)
  !
END SUBROUTINE extract
