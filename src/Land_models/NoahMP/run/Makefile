.SUFFIXES:
.SUFFIXES: .o .f

ifeq ($(WRF_HYDRO_RAPID),1)
include ${TAO_DIR}/bmake/tao_common
endif

include ../user_build_options

ifeq ($(WRF_HYDRO_RAPID),1)
PHDF5_INC=-I ${TACC_HDF5_INC}
RAPID_MACRO = ${TAO_FORTRAN_LIB} ${TAO_LIB} ${PETSC_LIB} ${PHDF5_INC} \
        -Wl,-rpath,${TACC_HDF5_LIB} -L${TACC_HDF5_LIB} -lhdf5 -lz
RAPID_LIB =  -lrapid
else
RAPID_MACRO =
RAPID_LIB =
endif

OBJS_NoahMP = ../IO_code/module_NoahMP_hrldas_driver.o

OBJS := \
	../IO_code/main_hrldas_driver.o \
	../IO_code/module_hrldas_netcdf_io.o \
	../phys/module_sf_noahmpdrv.o \
	../phys/module_sf_noahmplsm.o \
	../phys/module_sf_noahmp_glacier.o \
	../phys/module_sf_noahmp_groundwater.o \
	../Utility_routines/module_wrf_utilities.o \
	../Utility_routines/module_model_constants.o \
	../Utility_routines/module_date_utilities.o \
	../Utility_routines/kwm_string_utilities.o\
	../phys/surfex/modd_csts.o\
	../phys/surfex/tridiag_ground_snowcro.o\
	../phys/surfex/mode_surf_coefs.o\
	../phys/surfex/mode_snow3l.o\
	../phys/surfex/modd_snow_par.o\
	../phys/surfex/ini_csts.o\
	../phys/surfex/module_snowcro.o\
	../phys/surfex/module_snowcro_intercept.o\
	../phys/surfex/mode_thermos.o\
	../phys/surfex/modd_surf_atm.o\
	../phys/surfex/modd_snow_metamo.o

# Check whether or not to build Crocus
ifndef BUILD_CROCUS
BUILD_CROCUS:=1
endif
ifeq ($(BUILD_CROCUS), 1)
        OBJS := $(filter-out ../phys/surfex/module_snowcro_intercept.o, $(OBJS))
else
        OBJS := $(filter-out ../phys/surfex/module_snowcro.o, $(OBJS))
endif

CMD = hrldas.exe
all:	$(CMD)

### default we create the exe based on NoahMP
hrldas.exe: $(OBJS)
	@echo ""
	echo "${TAO_FORTRAN_LIB} ${TAO_LIB} ${PETSC_LIB} ${PHDF5_INC} -Wl,-rpath,${TACC_HDF5_LIB} -L${TACC_HDF5_LIB} -lhdf5 -lz"
# We have to include the modules built in ../IO_code
	$(COMPILERF90) -o $(@) -I../IO_code -I../phys $(OBJS) $(OBJS_NoahMP) $(HYDRO_LIB) $(RAPID_LIB) $(NETCDFLIB) $(RAPID_MACRO) $(LDFLAGS) $(LIBS)

	@echo ""

# Template to create the exe file based on different land model. Such as NoahMP
NoahMP: $(OBJS)
	@echo ""
	$(COMPILERF90) -o hrldas.exe -I../IO_code -I../phys $(OBJS) $(OBJS_NoahMP)  $(HYDRO_LIB) $(NETCDFLIB) $(LDFLAGS) $(LIBS)
	@echo ""

# This command cleans up
clean:
	$(RM) *~ $(CMD)
