#!/usr/bin/env python3

import os
import sys
from io import StringIO
from optparse import OptionParser

import numpy as np

import damask

scriptName = os.path.splitext(os.path.basename(__file__))[0]
scriptID   = ' '.join([scriptName,damask.version])

#--------------------------------------------------------------------------------------------------
#                                MAIN
#--------------------------------------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog options [file[s]]', description = """
Create seed file taking material indices from given geom file.
Indices can be black-listed or white-listed.

""", version = scriptID)

parser.add_option('-w',
                  '--white',
                  action = 'extend', metavar = '<int LIST>',
                  dest   = 'whitelist',
                  help   = 'whitelist of grain IDs')
parser.add_option('-b',
                  '--black',
                  action = 'extend', metavar = '<int LIST>',
                  dest   = 'blacklist',
                  help   = 'blacklist of grain IDs')

parser.set_defaults(whitelist = [],
                    blacklist = [],
                   )

(options,filenames) = parser.parse_args()
if filenames == []: filenames = [None]

options.whitelist = [int(i) for i in options.whitelist]
options.blacklist = [int(i) for i in options.blacklist]

for name in filenames:
    damask.util.report(scriptName,name)

    geom = damask.Geom.load_ASCII(StringIO(''.join(sys.stdin.read())) if name is None else name)
    materials = geom.materials.reshape((-1,1),order='F')

    mask = np.logical_and(np.in1d(materials,options.whitelist,invert=False) if options.whitelist else \
                          np.full(geom.grid.prod(),True,dtype=bool),
                          np.in1d(materials,options.blacklist,invert=True)  if options.blacklist else \
                          np.full(geom.grid.prod(),True,dtype=bool))

    seeds = damask.grid_filters.cell_coord0(geom.grid,geom.size).reshape(-1,3,order='F')

    comments = geom.comments \
             + [scriptID + ' ' + ' '.join(sys.argv[1:]),
                'grid\ta {}\tb {}\tc {}'.format(*geom.grid),
                'size\tx {}\ty {}\tz {}'.format(*geom.size),
                'origin\tx {}\ty {}\tz {}'.format(*geom.origin),
                ]

    damask.Table(seeds[mask],{'pos':(3,)},comments)\
          .add('material',materials[mask].astype(int))\
          .save(sys.stdout if name is None else os.path.splitext(name)[0]+'.seeds',legacy=True)
