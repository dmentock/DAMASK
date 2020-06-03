import subprocess
import shlex
import string
from pathlib import Path

from .._environment import Environment

class Marc:
    """Wrapper to run DAMASK with MSCMarc."""

    def __init__(self,version=Environment().options['MARC_VERSION']):
        """
        Create a Marc solver object.

        Parameters
        ----------
        version : float
            Marc version

        """
        self.solver  = 'Marc'
        self.version = version

    @property
    def library_path(self):

        path_MSC = Environment().options['MSC_ROOT']
        path_lib = Path('{}/mentat{}/shlib/linux64'.format(path_MSC,self.version))

        return path_lib if path_lib.is_file() else None


    @property
    def tools_path(self):

        path_MSC   = Environment().options['MSC_ROOT']
        path_tools = Path('{}/marc{}/tools'.format(path_MSC,self.version))

        return path_tools if path_tools.is_file() else None


#--------------------------
    def submit_job(self,
                   model,
                   job          = 'job1',
                   logfile      = False,
                   compile      = False,
                   optimization = '',
                  ):


        env = Environment()

        user = env.root_dir/Path('src/DAMASK_marc{}'.format(self.version)).with_suffix('.f90' if compile else '.marc')
        if not user.is_file():
            raise FileNotFoundError("DAMASK4Marc ({}) '{}' not found".format(('source' if compile else 'binary'),user))

        # Define options [see Marc Installation and Operation Guide, pp 23]
        script = 'run_damask_{}mp'.format(optimization)

        cmd = str(self.tools_path/Path(script)) + \
              ' -jid ' + model + '_' + job + \
              ' -nprocd 1  -autorst 0 -ci n  -cr n  -dcoup 0 -b no -v no'

        if compile: cmd += ' -u ' + str(user) + ' -save y'
        else:       cmd += ' -prog ' + str(user.with_suffix(''))

        print('job submission {} compilation: {}'.format('with' if compile else 'without',user))
        if logfile: log = open(logfile, 'w')
        print(cmd)
        process = subprocess.Popen(shlex.split(cmd),stdout = log,stderr = subprocess.STDOUT)
        log.close()
        process.wait()

#--------------------------
    def exit_number_from_outFile(self,outFile=None):
        exitnumber = -1
        with open(outFile,'r') as fid_out:
            for line in fid_out:
                if (string.find(line,'tress iteration') != -1):
                    print(line)
                elif (string.find(line,'Exit number')   != -1):
                    substr = line[string.find(line,'Exit number'):len(line)]
                    exitnumber = int(substr[12:16])

        return exitnumber
