!  Program Name:
!  Author(s)/Contact(s):
!  Abstract:
!  History Log:
!
!  Usage:
!  Parameters: <Specify typical arguments passed>
!  Input Files:
!        <list file names and briefly describe the data they include>
!  Output Files:
!        <list file names and briefly describe the information they include>
!
!  Condition codes:
!        <list exit condition or error codes returned >
!        If appropriate, descriptive troubleshooting instructions or
!        likely causes for failures could be mentioned here with the
!        appropriate error code
!
!  User controllable options: <if applicable>

!-----------------------------------------------------------------------
!       Choice of computers
!-----------------------------------------------------------------------
!
!                 CRAY XMP,YMP/UNICOS       (#define CRAY)
!                 VAX/VMS                   (#define VAX)
!                 Stardent 1500/3000/UNIX   (#define STARDENT)
!                 IBM RS/6000-AIX           (#define IBM)
!                 SUN Sparcstation          (#define SUN)
!                 SGI Silicon Graphics      (#define SGI)
!                 HP 7xx                    (#define HP)
!                 DEC ALPHA                 (#define ALPHA)
! +------------------------------------------------------------------+
! _                     SYSTEM DEPENDENT ROUTINES                    _
! _                                                                  _
! _    This module contains short utility routines that are not      _
! _ of the FORTRAN 77 standard and may differ from system to system. _
! _ These include bit manipulation, I/O, JCL calls, and vector       _
! _ functions.                                                       _
! +------------------------------------------------------------------+
! +------------------------------------------------------------------+
!
!          DATA SET UTILITY    AT LEVEL 003 AS OF 02/25/92
SUBROUTINE GBYTE(IN,IOUT,ISKIP,NBYTE)
!
! THIS PROGRAM WRITTEN BY.....
!             DR. ROBERT C. GAMMILL, CONSULTANT
!             NATIONAL CENTER FOR ATMOSPHERIC RESEARCH
!             MAY 1972
!
!             CHANGES FOR CRAY Y-MP8/832
!             CRAY CFT77 FORTRAN
!             JULY 1992, RUSSELL E. JONES
!             NATIONAL WEATHER SERVICE
!
! THIS IS THE FORTRAN VERSION OF GBYTE
!
  INTEGER    IN(*)
  INTEGER    IOUT
#if defined (CRAY) || defined (BIT64)

  INTEGER    MASKS(64)
!
  DATA  NBITSW/64/
!
!     MASKS TABLE PUT IN DECIMAL SO IT WILL COMPILE ON ANY 64 BIT
!     COMPUTER
!
  DATA  MASKS / 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047,  &
       4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287,      &
       1048575, 2097151, 4194303, 8388607, 16777215, 33554431,       &
       67108863, 134217727, 268435455, 536870911, 1073741823,        &
       2147483647, 4294967295, 8589934591, 17179869183,              &
       34359738367, 68719476735, 137438953471, 274877906943,         &
       549755813887, 1099511627775, 2199023255551, 4398046511103,    &
       8796093022207, 17592186044415, 35184372088831,                &
       70368744177663, 140737488355327, 281474976710655,             &
       562949953421311, 1125899906842623, 2251799813685247,          &
       4503599627370495, 9007199254740991, 18014398509481983,        &
       36028797018963967, 72057594037927935, 144115188075855871,     &
       288230376151711743, 576460752303423487, 1152921504606846975,  &
       2305843009213693951, 4611686018427387903, 9223372036854775807, &
       -1/
#else
  INTEGER    MASKS(32)
!
  DATA  NBITSW/32/
!
!     MASKS TABLE PUT IN DECIMAL SO IT WILL COMPILE ON ANY 32 BIT
!     COMPUTER
!
  DATA  MASKS / 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047, &
       4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287,     &
       1048575, 2097151, 4194303, 8388607, 16777215, 33554431,      &
       67108863, 134217727, 268435455, 536870911, 1073741823,       &
       2147483647, -1/
#endif
!
! NBYTE MUST BE LESS THAN OR EQUAL TO NBITSW
!
  ICON   = NBITSW - NBYTE
  IF (ICON.LT.0) RETURN
  MASK   = MASKS(NBYTE)
!
! INDEX TELLS HOW MANY WORDS INTO THE ARRAY 'IN' THE NEXT BYTE APPEARS.
!
  INDEX  = ISKIP / NBITSW
!
! II TELLS HOW MANY BITS THE BYTE IS FROM THE LEFT SIDE OF THE WORD.
!
  II     = MOD(ISKIP,NBITSW)
!
! MOVER SPECIFIES HOW FAR TO THE RIGHT NBYTE MUST BE MOVED IN ORDER
!    TO BE RIGHT ADJUSTED.
!
  MOVER = ICON - II
!
  IF (MOVER.GT.0) THEN
     IOUT  = IAND(ISHFT(IN(INDEX+1),-MOVER),MASK)
!
! THE BYTE IS SPLIT ACROSS A WORD BREAK.
!
  ELSE IF (MOVER.LT.0) THEN
     MOVEL = - MOVER
     MOVER = NBITSW - MOVEL
     IOUT  = IAND(IOR(ISHFT(IN(INDEX+1),MOVEL),    &
          &          ISHFT(IN(INDEX+2),-MOVER)),MASK)
!
! THE BYTE IS ALREADY RIGHT ADJUSTED.
!
  ELSE
     IOUT  = IAND(IN(INDEX+1),MASK)
  ENDIF
!
END SUBROUTINE GBYTE
!
! +------------------------------------------------------------------+
SUBROUTINE GBYTES(IN,IOUT,ISKIP,NBYTE,NSKIP,N)
!
! THIS PROGRAM WRITTEN BY.....
!             DR. ROBERT C. GAMMILL, CONSULTANT
!             NATIONAL CENTER FOR ATMOSPHERIC RESEARCH
!             MAY 1972
!
!             CHANGES FOR CRAY Y-MP8/832
!             CRAY CFT77 FORTRAN
!             JULY 1992, RUSSELL E. JONES
!             NATIONAL WEATHER SERVICE
!
! THIS IS THE FORTRAN VERSION OF GBYTES.
!
  INTEGER    IN(*)
  INTEGER    IOUT(*)
#if defined (CRAY) || defined (BIT64)
!CDIR$ INTEGER=64
  INTEGER    MASKS(64)
!
  DATA  NBITSW/64/
!
!     MASKS TABLE PUT IN DECIMAL SO IT WILL COMPILE ON ANY 64 BIT
!     COMPUTER
!
  DATA  MASKS / 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047, &
       & 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287,     &
       & 1048575, 2097151, 4194303, 8388607, 16777215, 33554431,      &
       & 67108863, 134217727, 268435455, 536870911, 1073741823,       &
       & 2147483647, 4294967295, 8589934591, 17179869183,             &
       & 34359738367, 68719476735, 137438953471, 274877906943,        &
       & 549755813887, 1099511627775, 2199023255551, 4398046511103,   &
       & 8796093022207, 17592186044415, 35184372088831,               &
       & 70368744177663, 140737488355327, 281474976710655,            &
       & 562949953421311, 1125899906842623, 2251799813685247,         &
       & 4503599627370495, 9007199254740991, 18014398509481983,       &
       & 36028797018963967, 72057594037927935, 144115188075855871,    &
       & 288230376151711743, 576460752303423487, 1152921504606846975, &
       & 2305843009213693951, 4611686018427387903, 9223372036854775807, &
       & -1/
#else
  INTEGER    MASKS(32)
!
  DATA  NBITSW/32/
!
!     MASKS TABLE PUT IN DECIMAL SO IT WILL COMPILE ON ANY 32 BIT
!     COMPUTER
!
  DATA  MASKS / 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047,   &
       & 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287,       &
       & 1048575, 2097151, 4194303, 8388607, 16777215, 33554431,        &
       & 67108863, 134217727, 268435455, 536870911, 1073741823,         &
       & 2147483647, -1/
#endif
!
! NBYTE MUST BE LESS THAN OR EQUAL TO NBITSW
!
  ICON   = NBITSW - NBYTE
  IF (ICON.LT.0) RETURN
  MASK   = MASKS(NBYTE)
!
! INDEX TELLS HOW MANY WORDS INTO THE ARRAY 'IN' THE NEXT BYTE APPEARS.
!
  INDEX  = ISKIP / NBITSW
!
! II TELLS HOW MANY BITS THE BYTE IS FROM THE LEFT SIDE OF THE WORD.
!
  II     = MOD(ISKIP,NBITSW)
!
! ISTEP IS THE DISTANCE IN BITS FROM THE START OF ONE BYTE TO THE NEXT.
!
  ISTEP  = NBYTE + NSKIP
!
! IWORDS TELLS HOW MANY WORDS TO SKIP FROM ONE BYTE TO THE NEXT.
!
  IWORDS = ISTEP / NBITSW
!
! IBITS TELLS HOW MANY BITS TO SKIP AFTER SKIPPING IWORDS.
!
  IBITS  = MOD(ISTEP,NBITSW)
!
  DO I = 1,N
!
! MOVER SPECIFIES HOW FAR TO THE RIGHT A BYTE MUST BE MOVED IN ORDER
!
!    TO BE RIGHT ADJUSTED.
!    TO BE RIGHT ADJUSTED.
!
     MOVER = ICON - II
!
! THE BYTE IS SPLIT ACROSS A WORD BREAK.
!
     IF (MOVER.LT.0) THEN
        MOVEL   = - MOVER
        MOVER   = NBITSW - MOVEL
        IOUT(I) = IAND(IOR(ISHFT(IN(INDEX+1),MOVEL),   &
             &            ISHFT(IN(INDEX+2),-MOVER)),MASK)
!
! RIGHT ADJUST THE BYTE.
!
     ELSE IF (MOVER.GT.0) THEN
        IOUT(I) = IAND(ISHFT(IN(INDEX+1),-MOVER),MASK)
!
! THE BYTE IS ALREADY RIGHT ADJUSTED.
!
     ELSE
        IOUT(I) = IAND(IN(INDEX+1),MASK)
     ENDIF
!
! INCREMENT II AND INDEX.
!
     II    = II + IBITS
     INDEX = INDEX + IWORDS
     IF (II.GE.NBITSW) THEN
        II    = II - NBITSW
        INDEX = INDEX + 1
     ENDIF
!
  END DO
END SUBROUTINE GBYTES
!
! +------------------------------------------------------------------+
SUBROUTINE SBYTE(IOUT,IN,ISKIP,NBYTE)
! THIS PROGRAM WRITTEN BY.....
!             DR. ROBERT C. GAMMILL, CONSULTANT
!             NATIONAL CENTER FOR ATMOSPHERIC RESEARCH
!             JULY 1972
! THIS IS THE FORTRAN VERSIONS OF SBYTE.
!             FORTRAN 90
!             AUGUST 1990  RUSSELL E. JONES
!             NATIONAL WEATHER SERVICE
!
! USAGE:    CALL SBYTE (PCKD,UNPK,INOFST,NBIT)
!
!   INPUT ARGUMENT LIST:
!     UNPK     -  NBITS OF THE RIGHT SIDE OF UNPK IS MOVED TO
!                 ARRAY PCKD. INOFST BITS ARE SKIPPED OVER BEFORE
!                 THE DATA IS MOVED, NBITS ARE STORED.
!    INOFST    -  A FULLWORD INTEGER SPECIFYING THE INITAL OFFSET
!                 IN BITS OF THE FIRST BYTE, COUNTED FROM THE
!                 LEFTMOST BIT IN PCKD.
!    NBITS     -  A FULLWORD INTEGER SPECIFYING THE NUMBER OF BITS
!                 IN EACH BYTE TO BE PACKED.  LEGAL BYTE WIDTHS
!                 ARE IN THE RANGE 1 - 32.
!   OUTPUT ARGUMENT LIST:
!    PCKD      -  THE FULLWORD IN MEMORY TO WHICH PACKING IS TO
!                 BEGIN STARTING AT BIT INOFST. THE INOSTAT BITS
!                 ARE NOT ALTERED.
!
  INTEGER    IN
  INTEGER    IOUT(*)
#if defined (CRAY) || defined (BIT64)
  INTEGER    MASKS(64)
!
  DATA  NBITSW/64/
!
!     MASKS TABLE PUT IN DECIMAL SO IT WILL COMPILE ON ANY 64 BIT
!     COMPUTER
!
  DATA  MASKS / 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047,   &
       & 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287,	      &
       & 1048575, 2097151, 4194303, 8388607, 16777215, 33554431,	      &
       & 67108863, 134217727, 268435455, 536870911, 1073741823,	      &
       & 2147483647, 4294967295, 8589934591, 17179869183,		      &
       & 34359738367, 68719476735, 137438953471, 274877906943,	      &
       & 549755813887, 1099511627775, 2199023255551, 4398046511103,     &
       & 8796093022207, 17592186044415, 35184372088831,		      &
       & 70368744177663, 140737488355327, 281474976710655,	      &
       & 562949953421311, 1125899906842623, 2251799813685247,	      &
       & 4503599627370495, 9007199254740991, 18014398509481983,	      &
       & 36028797018963967, 72057594037927935, 144115188075855871,      &
       & 288230376151711743, 576460752303423487, 1152921504606846975,   &
       & 2305843009213693951, 4611686018427387903, 9223372036854775807, &
       & -1/
#else
  INTEGER    MASKS(32)
!
  DATA  NBITSW/32/
!
!     MASKS TABLE PUT IN DECIMAL SO IT WILL COMPILE ON ANY 32 BIT
!     COMPUTER
!
  DATA  MASKS / 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047,   &
       & 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287,       &
       & 1048575, 2097151, 4194303, 8388607, 16777215, 33554431,        &
       & 67108863, 134217727, 268435455, 536870911, 1073741823,         &
       & 2147483647, -1/
#endif
!
! NBYTE MUST BE LESS THAN OR EQUAL TO NBITSW
!
  ICON  = NBITSW - NBYTE
  IF (ICON.LT.0) RETURN
  MASK  = MASKS(NBYTE)
!
! INDEX TELLS HOW MANY WORDS INTO IOUT THE NEXT BYTE IS TO BE STORED.
!
  INDEX = ISKIP / NBITSW
!
! II TELLS HOW MANY BITS IN FROM THE LEFT SIDE OF THE WORD TO STORE IT.
!
  II    = MOD(ISKIP,NBITSW)
!
  J     = IAND(MASK,IN)
  MOVEL = ICON - II
!
! BYTE IS TO BE STORED IN MIDDLE OF WORD.  SHIFT LEFT.
!
  IF (MOVEL.GT.0) THEN
     MSK           = ISHFT(MASK,MOVEL)
     IOUT(INDEX+1) = IOR(IAND(NOT(MSK),IOUT(INDEX+1)),   &
          &    ISHFT(J,MOVEL))
!
! THE BYTE IS TO BE SPLIT ACROSS A WORD BREAK.
!
  ELSE IF (MOVEL.LT.0) THEN
     MSK           = MASKS(NBYTE+MOVEL)
     IOUT(INDEX+1) = IOR(IAND(NOT(MSK),IOUT(INDEX+1)),    &
          &    ISHFT(J,MOVEL))
     ITEMP         = IAND(MASKS(NBITSW+MOVEL),IOUT(INDEX+2))
     IOUT(INDEX+2) = IOR(ITEMP,ISHFT(J,NBITSW+MOVEL))
!
! BYTE IS TO BE STORED RIGHT-ADJUSTED.
!
  ELSE
     IOUT(INDEX+1) = IOR(IAND(NOT(MASK),IOUT(INDEX+1)),J)
  ENDIF
!
END SUBROUTINE SBYTE
!
! +------------------------------------------------------------------+
SUBROUTINE SBYTES(IOUT,IN,ISKIP,NBYTE,NSKIP,N)
! THIS PROGRAM WRITTEN BY.....
!             DR. ROBERT C. GAMMILL, CONSULTANT
!             NATIONAL CENTER FOR ATMOSPHERIC RESEARCH
!             JULY 1972
! THIS IS THE FORTRAN VERSIONS OF SBYTES.
!
!             FORTRAN 90
!             AUGUST 1990  RUSSELL E. JONES
!             NATIONAL WEATHER SERVICE
!
! USAGE:    CALL SBYTES (PCKD,UNPK,INOFST,NBIT, NSKIP,ITER)
!
!   INPUT ARGUMENT LIST:
!     UNPK     -  NBITS OF THE RIGHT SIDE OF EACH WORD OF ARRAY
!                 UNPK IS MOVED TO ARRAY PCKD. INOFST BITS ARE
!                 SKIPPED OVER BEFORE THE 1ST DATA IS MOVED, NBITS
!                 ARE STORED, NSKIP BITS ARE SKIPPED OVER, THE NEXT
!                 NBITS ARE MOVED,  BIT ARE SKIPPED OVER, ETC. UNTIL
!                 ITER GROUPS OF BITS ARE PACKED.
!    INOFST    -  A FULLWORD INTEGER SPECIFYING THE INITAL OFFSET
!                 IN BITS OF THE FIRST BYTE, COUNTED FROM THE
!                 LEFTMOST BIT IN PCKD.
!    NBITS     -  A FULLWORD INTEGER SPECIFYING THE NUMBER OF BITS
!                 IN EACH BYTE TO BE PACKED.  LEGAL BYTE WIDTHS
!                 ARE IN THE RANGE 1 - 32.
!    NSKIP     -  A FULLWORD INTEGER SPECIFYING THE NUMBER OF BITS
!                 TO SKIP BETWEEN SUCCESSIVE BYTES.  ALL NON-NEGATIVE
!                 SKIP COUNTS ARE LEGAL.
!    ITER      -  A FULLWORD INTEGER SPECIFYING THE TOTAL NUMBER OF
!                 BYTES TO BE PACKED, AS CONTROLLED BY INOFST,
!                 NBIT AND NSKIP ABOVE.   ALL NON-NEGATIVE ITERATION
!                 COUNTS ARE LEGAL.
!
!   OUTPUT ARGUMENT LIST:
!    PCKD      -  THE FULLWORD IN MEMORY TO WHICH PACKING IS TO
!                 BEGIN STARTING AT BIT INOFST. THE INOSTAT BITS
!                 ARE NOT ALTERED. NSKIP BITS ARE NOT ALTERED.
!
  INTEGER    IN(*)
  INTEGER    IOUT(*)
#if defined (CRAY) || defined (BIT64)
  INTEGER    MASKS(64)
!
  DATA  NBITSW/64/
!
!     MASKS TABLE PUT IN DECIMAL SO IT WILL COMPILE ON ANY 64 BIT
!     COMPUTER
!
  DATA  MASKS / 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047,     &
       & 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287,		&
       & 1048575, 2097151, 4194303, 8388607, 16777215, 33554431,		&
       & 67108863, 134217727, 268435455, 536870911, 1073741823,		&
       & 2147483647, 4294967295, 8589934591, 17179869183,			&
       & 34359738367, 68719476735, 137438953471, 274877906943,		&
       & 549755813887, 1099511627775, 2199023255551, 4398046511103,	&
       & 8796093022207, 17592186044415, 35184372088831,			&
       & 70368744177663, 140737488355327, 281474976710655,		&
       & 562949953421311, 1125899906842623, 2251799813685247,		&
       & 4503599627370495, 9007199254740991, 18014398509481983,		&
       & 36028797018963967, 72057594037927935, 144115188075855871,	&
       & 288230376151711743, 576460752303423487, 1152921504606846975,	&
       & 2305843009213693951, 4611686018427387903, 9223372036854775807,   &
       & -1/
#else
  INTEGER    MASKS(32)
!
  DATA  NBITSW/32/
!
!     MASKS TABLE PUT IN DECIMAL SO IT WILL COMPILE ON ANY 32 BIT
!     COMPUTER
!
  DATA  MASKS / 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047,   &
       & 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287,       &
       & 1048575, 2097151, 4194303, 8388607, 16777215, 33554431,        &
       & 67108863, 134217727, 268435455, 536870911, 1073741823,         &
       & 2147483647, -1/
#endif
!
! NBYTE MUST BE LESS THAN OR EQUAL TO NBITSW
!
  ICON = NBITSW - NBYTE
  IF (ICON.LT.0) RETURN
  MASK   = MASKS(NBYTE)
!
! INDEX TELLS HOW MANY WORDS INTO IOUT THE NEXT BYTE IS TO BE STORED.
!
  INDEX  = ISKIP / NBITSW
!
! II TELLS HOW MANY BITS IN FROM THE LEFT SIDE OF THE WORD TO STORE IT.
!
  II     = MOD(ISKIP,NBITSW)
!
! ISTEP IS THE DISTANCE IN BITS FROM ONE BYTE POSITION TO THE NEXT.
!
  ISTEP  = NBYTE + NSKIP
!
! IWORDS TELLS HOW MANY WORDS TO SKIP FROM ONE BYTE TO THE NEXT.
!
  IWORDS = ISTEP / NBITSW
!
! IBITS TELLS HOW MANY BITS TO SKIP AFTER SKIPPING IWORDS.
!
  IBITS  = MOD(ISTEP,NBITSW)
!
  DO I = 1,N
     J     = IAND(MASK,IN(I))
     MOVEL = ICON - II
!
! BYTE IS TO BE STORED IN MIDDLE OF WORD.  SHIFT LEFT.
!
     IF (MOVEL.GT.0) THEN
        MSK           = ISHFT(MASK,MOVEL)
        IOUT(INDEX+1) = IOR(IAND(NOT(MSK),IOUT(INDEX+1)),   &
             &    ISHFT(J,MOVEL))
!
! THE BYTE IS TO BE SPLIT ACROSS A WORD BREAK.
!
     ELSE IF (MOVEL.LT.0) THEN
        MSK           = MASKS(NBYTE+MOVEL)
        IOUT(INDEX+1) = IOR(IAND(NOT(MSK),IOUT(INDEX+1)),    &
             &    ISHFT(J,MOVEL))
        ITEMP         = IAND(MASKS(NBITSW+MOVEL),IOUT(INDEX+2))
        IOUT(INDEX+2) = IOR(ITEMP,ISHFT(J,NBITSW+MOVEL))
!
! BYTE IS TO BE STORED RIGHT-ADJUSTED.
!
     ELSE
        IOUT(INDEX+1) = IOR(IAND(NOT(MASK),IOUT(INDEX+1)),J)
     ENDIF
!
     II    = II + IBITS
     INDEX = INDEX + IWORDS
     IF (II.GE.NBITSW) THEN
        II    = II - NBITSW
        INDEX = INDEX + 1
     ENDIF
!
  END DO
END SUBROUTINE SBYTES
