import copy
import datetime as dt
import os
import pathlib
import pickle
import sys
import warnings
import pandas as pd
import pytest
import wrfhydropy
import xarray as xr

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from utilities import wait_job, print_diffs, plot_diffs

# #################################
# Setup the test with a domain, a candidate, and a reference.
# Get domain, reference, candidate, and optional output directory from command line arguments
# Setup a domain

#List variabls to ignore in tests, primarily accumulation variables
EXCLUDE_VARS = [
    'ACMELT',
    'ACSNOW',
    'SFCRUNOFF',
    'UDRUNOFF',
    'ACCPRCP',
    'ACCECAN',
    'ACCEDIR',
    'ACCETRAN',
    'qstrmvolrt',
    'QSTRMVOLRT',
    'reference_time',
    'lake_inflort'
]

# #################################
# Define tests


def test_compile_candidate(candidate_sim, output_dir):
    print("\nQuestion: The candidate compiles?\n", end='')
    print('\n')

    compile_dir = output_dir / 'compile_candidate'
    if compile_dir.exists():
        pytest.skip('Candidate compile dir exists, skipping candidate compile test')

    # Compile the model, catch warnings related to non-existant compile directory
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        candidate_sim.model.compile(compile_dir=compile_dir)

    # Check compilation status
    assert candidate_sim.model.compile_log.returncode == 0, \
        "Candidate code did not compile correctly."


def test_compile_reference(reference_sim, output_dir):
    print("\nQuestion: The reference compiles?\n", end='')
    print('\n')

    compile_dir = output_dir / 'compile_reference'
    if compile_dir.exists():
        pytest.skip('Reference compile dir exists, skipping reference compile')

    # Compile the model, catch warnings related to non-existant compile directory
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        reference_sim.model.compile(compile_dir=compile_dir)

    # Check compilation status
    assert reference_sim.model.compile_log.returncode == 0, \
        "Reference code did not compile correctly"


def test_run_candidate(candidate_sim, output_dir, ncores, exe_cmd):
    print("\nQuestion: The candidate runs successfully?\n", end='')
    print('\n')

    candidate_sim_copy = copy.deepcopy(candidate_sim)

    # Set run directory and change working directory to run dir for simulation
    run_dir = output_dir / 'run_candidate'
    if run_dir.exists():
        pytest.skip('Candidate run dir exists, skipping candidate run test')

    run_dir.mkdir(parents=True)
    os.chdir(str(run_dir))

    # Job
    exe_command = exe_cmd.format(str(ncores))
    out_dt = 1 if 'channel' in candidate_sim.model.model_config else 24
    job = wrfhydropy.Job(
        job_id='run_candidate',
        exe_cmd=exe_command,
        restart_freq_hr=24,
        output_freq_hr=out_dt
    )
    candidate_sim_copy.add(job)

    # Run, catch warnings related to missing start and end job times
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        candidate_sim_copy.compose()

    print('\nwaiting for job to complete...', end='')
    candidate_sim_copy.run()
    # Wait to collect until job has finished. All test runs are performed on a single job with
    # job_id='test_job'
    wait_job(candidate_sim_copy)

    candidate_sim_copy.collect()
    candidate_sim_copy.pickle(run_dir.joinpath('WrfHydroSim_collected.pkl'))

    # Check job run statuses
    for job in candidate_sim_copy.jobs:
        assert job.exit_status == 0, \
            "Candidate code run exited with non-zero status"


# Run questions
def test_run_reference(reference_sim, output_dir, ncores, exe_cmd):
    print("\nQuestion: The reference runs successfully?\n", end='')
    print('\n')

    reference_sim_copy = copy.deepcopy(reference_sim)

    # Set run directory and change working directory to run dir for simulation
    run_dir = output_dir / 'run_reference'
    if run_dir.exists():
        pytest.skip('Reference run dir exists, skipping reference run')
    run_dir.mkdir(parents=True)
    os.chdir(str(run_dir))

    # Job
    exe_command = exe_cmd.format(str(ncores))
    out_dt = 1 if 'channel' in reference_sim.model.model_config else 24
    job = wrfhydropy.Job(
        job_id='run_reference',
        exe_cmd=exe_command,
        restart_freq_hr=24,
        output_freq_hr=out_dt
    )
    reference_sim_copy.add(job)

    # Run, catch warnings related to missing start and end job times
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        reference_sim_copy.compose()

    print('\nwaiting for job to complete...', end='')
    reference_sim_copy.run()

    # Wait to collect until job has finished. All test runs are performed on a single job with
    # job_id='test_job'
    wait_job(reference_sim_copy)

    reference_sim_copy.collect()
    reference_sim_copy.pickle(run_dir.joinpath('WrfHydroSim_collected.pkl'))

    # Check job run statuses
    for job in reference_sim_copy.jobs:
        assert job.exit_status == 0, \
            "Reference code run exited with non-zero status"


def test_ncores_candidate(output_dir, exe_cmd, ncores, xrcmp_n_cores, feature_ids):
    print("\nQuestion: The candidate outputs from a ncores run match outputs from"
          " ncores-1 run?\n", end='')
    print('\n')

    candidate_sim_file = output_dir / 'run_candidate' / 'WrfHydroSim.pkl'
    candidate_collected_file = output_dir / 'run_candidate' / 'WrfHydroSim_collected.pkl'
    if candidate_collected_file.is_file() is False:
        pytest.skip('Candidate run object not found, skipping test.')

    # Load initial sim object, collect sim_object and copy for makign new sims
    candidate_sim = pickle.load(candidate_sim_file.open(mode="rb"))
    candidate_sim_expected = pickle.load(candidate_collected_file.open(mode="rb"))
    candidate_sim_ncores = copy.deepcopy(candidate_sim)

    # Set run directory
    run_dir = output_dir.joinpath('ncores_candidate')
    if not run_dir.exists():
        run_dir.mkdir(parents=True)
        os.chdir(str(run_dir))

        # Make a new job based on the old job but with a new job ID
        old_job = candidate_sim.jobs[0]
        out_dt = 1 if 'channel' in candidate_sim.model.model_config else 24
        new_job = wrfhydropy.Job(
            job_id='ncores_candidate',
            exe_cmd=exe_cmd,
            restart_freq_hr=24,
            output_freq_hr=out_dt
        )

        # Remove old job and add new job
        candidate_sim_ncores.jobs.pop(0)
        candidate_sim_ncores.add(new_job)

        # Edit the sim object number of cores
        if candidate_sim_ncores.scheduler is not None:
            core_reduction = 36 if int(ncores) >= 72 else 1
            candidate_sim_ncores.scheduler.nproc = candidate_sim_ncores.scheduler.nproc - core_reduction
        else:
            candidate_sim_ncores.jobs[0]._exe_cmd = exe_cmd.format(str(int(ncores)-1))

        # Recompose into new directory and run
        # catch warnings related to missing start and end job times
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            candidate_sim_ncores.compose(force=True)

        print('\nwaiting for job to complete...', end='')
        candidate_sim_ncores.run()

        # Wait to collect until job has finished. All test runs are performed on a single job with
        # job_id='test_job'
        wait_job(candidate_sim_ncores)

        candidate_sim_ncores.collect()
        candidate_sim_ncores.pickle(run_dir.joinpath('WrfHydroSim_collected.pkl'))

        # Check job run statuses
        for job in candidate_sim_ncores.jobs:
            assert job.exit_status == 0, \
                "Candidate code run exited with non-zero status"

    else:
        print('Candidate n_cores run dir exists, skipping n_cores candidate run...')
        candidate_sim_ncores = pickle.load(
            run_dir.joinpath('WrfHydroSim_collected.pkl').open(mode="rb"))

    # Check outputs
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        diffs = wrfhydropy.outputdiffs.OutputDataDiffs(
            candidate_sim_ncores.output,
            candidate_sim_expected.output,
            exclude_vars=EXCLUDE_VARS,
            xrcmp_n_cores=xrcmp_n_cores
        )

    # Assert all diff values are 0 and print diff stats if not
    has_diffs = any(value != 0 for value in diffs.diff_counts.values())
    if has_diffs:
        print_diffs(diffs)
        plot_diffs(output_dir, 'run_candidate', 'ncores_candidate', 'ncores', feature_ids)
    assert has_diffs is False, \
        'Outputs for candidate run with ncores do not match outputs with ncores-1'


def test_perfrestart_candidate(output_dir, xrcmp_n_cores, feature_ids):
    print("\nQuestion: The candidate outputs from a restart run match the outputs from standard "
          "run?\n", end='')
    print('\n')

    candidate_sim_file = output_dir / 'run_candidate' / 'WrfHydroSim.pkl'
    candidate_collected_file = output_dir / 'run_candidate' / 'WrfHydroSim_collected.pkl'
    if candidate_collected_file.is_file() is False:
        pytest.skip('Candidate run object not found, skipping test.')

    # Load initial run model object and copy
    candidate_sim = pickle.load(candidate_sim_file.open(mode="rb"))
    candidate_sim_expected = pickle.load(candidate_collected_file.open(mode="rb"))

    # Set run directory
    run_dir = output_dir.joinpath('restart_candidate')
    if not run_dir.exists():
        candidate_sim_restart = copy.deepcopy(candidate_sim)
        run_dir.mkdir(parents=True)
        os.chdir(str(run_dir))

        # Get a new start time halfway along the run, make sure the restart frequency accomodates
        restart_job = candidate_sim_restart.jobs[0]
        duration = restart_job.model_end_time - restart_job.model_start_time
        delay_restart_hr = int((duration.total_seconds() / 3600)/2)

        # Want matching restart frequencies for this test...
        assert \
            candidate_sim_restart.jobs[0].restart_freq_hr_hydro == \
            candidate_sim_restart.jobs[0].restart_freq_hr_hrldas, \
            "Hydro and HRLDAS components do not have the same restart frequencies."

        assert delay_restart_hr % candidate_sim_restart.jobs[0].restart_freq_hr_hydro == 0, \
            "The restart delay is not a multiple of the hydro restart frequency."
        restart_job.model_start_time = \
            restart_job.model_start_time + dt.timedelta(hours=delay_restart_hr)

        # Get restart files from previous run and symlink into restart sim dir
        # (Remember that we are in the run/sim dir)
        # Hydro: Use actual time listed in meta data, not filename or positional list index
        # JLM: seems like these loops can be replaced with a pathlib.Path.glob(), the loop is confusing.
        for restart_file in candidate_sim_expected.output.restart_hydro:
            if isinstance(restart_file, pathlib.Path):
                restart_time = xr.open_dataset(restart_file).Restart_Time
            else:
                restart_time = restart_file.open().Restart_Time  # backwards compatible wrfhydropy
            restart_time = pd.to_datetime(restart_time, format='%Y-%m-%d_%H:%M:%S')
            if restart_time == restart_job.model_start_time:
                candidate_hydro_restart_file = pathlib.Path(restart_file.name)
                candidate_hydro_restart_file.symlink_to(restart_file)
                key1 = 'hydro_nlist'
                key2 = 'restart_file'
                restart_job._hydro_namelist[key1][key2] = str(candidate_hydro_restart_file)

        # LSM: Use actual time listed in meta data, not filename or positional list index
        for restart_file in candidate_sim_expected.output.restart_lsm:
            if isinstance(restart_file, pathlib.Path):
                restart_time = xr.open_dataset(restart_file).Times[0]
            else:
                restart_time = restart_file.open().Times[0]  # backwards compatible wrfhydropy
            restart_time = restart_time.astype(str).item(0)
            restart_time = pd.to_datetime(restart_time, format='%Y-%m-%d_%H:%M:%S')
            if restart_time == restart_job.model_start_time:
                candidate_lsm_restart_file = pathlib.Path(restart_file.name)
                candidate_lsm_restart_file.symlink_to(restart_file)
                key1 = 'noahlsm_offline'
                key2 = 'restart_filename_requested'
                restart_job._hrldas_namelist[key1][key2] = str(candidate_lsm_restart_file)

        # Nudging: Use actual time listed in meta data, not filename or positional list index
        if candidate_sim_expected.output.restart_nudging is not None:
            for restart_file in candidate_sim_expected.output.restart_nudging:
                if isinstance(restart_file, pathlib.Path):
                    restart_time = xr.open_dataset(restart_file).modelTimeAtOutput
                else:
                    restart_time = restart_file.open().modelTimeAtOutput  # backwards compatible wrfhydropy
                restart_time = pd.to_datetime(restart_time, format='%Y-%m-%d_%H:%M:%S')
                if restart_time == restart_job.model_start_time:
                    candidate_nudging_restart_file = pathlib.Path(restart_file.name)
                    candidate_nudging_restart_file.symlink_to(restart_file)
                    key1 = 'nudging_nlist'
                    key2 = 'nudginglastobsfile'
                    restart_job._hydro_namelist[key1][key2] = str(candidate_nudging_restart_file)

        # Compose and run
        # catch warnings related to missing start and end job times
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            candidate_sim_restart.compose(force=True)

        print('\nwaiting for job to complete...', end='')
        candidate_sim_restart.run()

        # Wait to collect until job has finished. All test runs are performed on a single job with
        wait_job(candidate_sim_restart)

        candidate_sim_restart.collect()
        candidate_sim_restart.pickle(run_dir.joinpath('WrfHydroSim_collected.pkl'))

        # Check job run statuses
        for job in candidate_sim_restart.jobs:
            assert job.exit_status == 0, \
                "Candidate restart run exited with non-zero status"

    else:
        print('Candidate channel-only perfect restart run dir exists, '
              'skipping perfect restart candidate channel-only run...')
        candidate_sim_restart = pickle.load(
            open(run_dir.joinpath('WrfHydroSim_collected.pkl'), 'rb'))

    # Check outputs
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        diffs = wrfhydropy.outputdiffs.OutputDataDiffs(
            candidate_sim_restart.output,
            candidate_sim_expected.output,
            exclude_vars=EXCLUDE_VARS,
            xrcmp_n_cores=xrcmp_n_cores
        )

    # Assert all diff values are 0 and print diff stats if not
    has_diffs = any(value != 0 for value in diffs.diff_counts.values())
    if has_diffs:
        print_diffs(diffs)
        plot_diffs(output_dir, 'run_candidate', 'restart_candidate', 'restart', feature_ids )
    assert has_diffs is False, \
        'Outputs for candidate run do not match outputs from candidate restart run'
