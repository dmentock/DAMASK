#!/usr/bin/env python
# -*- coding: UTF-8 no BOM -*-

import os,sys,string
import numpy as np
from collections import defaultdict
from optparse import OptionParser
import damask

scriptID   = string.replace('$Id$','\n','\\n')
scriptName = os.path.splitext(scriptID.split()[1])[0]

# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog options [file[s]]', description = """
Add column(s) containing divergence of requested column(s).
Operates on periodic ordered three-dimensional data sets.
Deals with both vector- and tensor-valued fields.

""", version = scriptID)

accuracyChoices = ['2','4','6','8']
parser.add_option('--fdm',              dest='accuracy', action='extend', metavar='<int LIST>',
                                        help='degree of central difference accuracy (%s)'%(','.join(accuracyChoices)))
parser.add_option('--fft',              dest='fft', action='store_true',
                                        help='calculate divergence in Fourier space')
parser.add_option('-c','--coordinates', dest='coords', metavar = 'string',
                                        help='column heading for coordinates [%default]')
parser.add_option('-v','--vector',      dest='vector', action='extend', metavar='<string LIST>',
                                        help='heading of columns containing vector field values')
parser.add_option('-t','--tensor',      dest='tensor', action='extend', metavar='<string LIST>',
                                        help='heading of columns containing tensor field values')
parser.set_defaults(coords = 'ip')
parser.set_defaults(accuracy = [])
parser.set_defaults(fft = False)
parser.set_defaults(vector = [])
parser.set_defaults(tensor = [])

(options,filenames) = parser.parse_args()

if len(options.vector) + len(options.tensor) == 0:
  parser.error('no data column specified...')
if not set(options.accuracy).issubset(set(accuracyChoices)):
  parser.error('accuracy must be chosen from %s...'%(', '.join(accuracyChoices)))

if options.fft: options.accuracy.append('FFT')
if not options.accuracy:
  parser.error('no accuracy selected')

datainfo = {                                                               # list of requested labels per datatype
             'vector':     {'len':3,
                            'label':[]},
             'tensor':     {'len':9,
                            'label':[]},
           }

if options.vector != None:    datainfo['vector']['label'] += options.vector
if options.tensor != None:    datainfo['tensor']['label'] += options.tensor

# ------------------------------------------ setup file handles ------------------------------------
files = []
for name in filenames:
  if os.path.exists(name):
    files.append({'name':name, 'input':open(name), 'output':open(name+'_tmp','w'), 'croak':sys.stderr})

#--- loop over input files -------------------------------------------------------------------------
for file in files:
  file['croak'].write('\033[1m'+scriptName+'\033[0m: '+file['name']+'\n')

  table = damask.ASCIItable(file['input'],file['output'],True)                                      # make unbuffered ASCII_table
  table.head_read()                                                                                 # read ASCII header info
  table.info_append(scriptID + '\t' + ' '.join(sys.argv[1:]))

# --------------- figure out size and grid ---------------------------------------------------------
  try:
    locationCol = table.labels.index('1_%s'%options.coords)                                         # columns containing location data
  except ValueError:
    try:
      locationCol = table.labels.index('%s.x'%options.coords)                                       # columns containing location data (legacy naming scheme)
    except ValueError:
      file['croak'].write('no coordinate data (1_%s/%s.x) found...\n'%(options.coords,options.coords))
      continue

  coords = [{},{},{}]
  while table.data_read():                                                                          # read next data line of ASCII table
    for j in xrange(3):
      coords[j][str(table.data[locationCol+j])] = True                                              # remember coordinate along x,y,z
  grid = np.array([len(coords[0]),\
                   len(coords[1]),\
                   len(coords[2]),],'i')                                                            # grid is number of distinct coordinates found
  size = grid/np.maximum(np.ones(3,'d'),grid-1.0)* \
            np.array([max(map(float,coords[0].keys()))-min(map(float,coords[0].keys())),\
                      max(map(float,coords[1].keys()))-min(map(float,coords[1].keys())),\
                      max(map(float,coords[2].keys()))-min(map(float,coords[2].keys())),\
                      ],'d')                                                                        # size from bounding box, corrected for cell-centeredness

  for i, points in enumerate(grid):
    if points == 1:
      mask = np.ones(3,dtype=bool)
      mask[i]=0
      size[i] = min(size[mask]/grid[mask])                                                          # third spacing equal to smaller of other spacing
  
  N = grid.prod()

# --------------- figure out columns to process  ---------------------------------------------------
  active     = defaultdict(list)
  column     = defaultdict(dict)
  values     = defaultdict(dict)
  divergence = defaultdict(dict)

  for datatype,info in datainfo.items():
    for label in info['label']:
      key = '1_%s'%label
      if key not in table.labels:
        file['croak'].write('column %s not found...\n'%key)
      else:
        active[datatype].append(label)
        column[datatype][label] = table.labels.index(key)                                           # remember columns of requested data
        values[datatype][label] = np.array([0.0 for i in xrange(N*datainfo[datatype]['len'])]).\
                                           reshape(list(grid)+[datainfo[datatype]['len']//3,3])
        if label not in divergence[datatype]: divergence[datatype][label] = {}
        for accuracy in options.accuracy:
          divergence[datatype][label][accuracy] = np.array([0.0 for i in xrange(N*datainfo[datatype]['len']//3)]).\
                                                           reshape(list(grid)+[datainfo[datatype]['len']//3])
        
# ------------------------------------------ assemble header ---------------------------------------
  for datatype,labels in active.items():                                                            # loop over vector,tensor
    for label in labels:
      for accuracy in options.accuracy:
        table.labels_append({True: ['%i_div%s(%s)'%(i+1,accuracy,label) for i in xrange(3)],       # extend ASCII header with new labels
                             False:['div%s(%s)'%(accuracy,label)]} [datatype == 'tensor'])
  table.head_write()

# ------------------------------------------ read value field --------------------------------------
  table.data_rewind()
  idx = 0
  while table.data_read():                                                                          # read next data line of ASCII table
    (x,y,z) = damask.util.gridLocation(idx,grid)                                                    # figure out (x,y,z) position from line count
    idx += 1
    for datatype,labels in active.items():                                                          # loop over vector,tensor
      for label in labels:                                                                          # loop over all requested curls
        values[datatype][label][x,y,z] = np.array(
                map(float,table.data[column[datatype][label]:
                                     column[datatype][label]+datainfo[datatype]['len']]),'d') \
                                     .reshape(datainfo[datatype]['len']//3,3)

# ------------------------------------------ process value field -----------------------------------
  for datatype,labels in active.items():                                                            # loop over vector,tensor
    for label in labels:                                                                            # loop over all requested divergencies
      for accuracy in options.accuracy:
        if accuracy == 'FFT':
          divergence[datatype][label][accuracy] =\
            damask.core.math.divergenceFFT(size,values[datatype][label])
        else:
          divergence[datatype][label][accuracy] =\
            damask.core.math.divergenceFDM(size,eval(accuracy)//2-1,values[datatype][label])

# ------------------------------------------ process data ------------------------------------------
  table.data_rewind()
  idx = 0
  outputAlive = True
  while outputAlive and table.data_read():                                                          # read next data line of ASCII table
    (x,y,z) = damask.util.gridLocation(idx,grid)                                                    # figure out (x,y,z) position from line count
    idx += 1
    for datatype,labels in active.items():                                                          # loop over vector,tensor
      for label in labels:                                                                          # loop over all requested 
        for accuracy in options.accuracy:
          table.data_append(list(divergence[datatype][label][accuracy][x,y,z].reshape(datainfo[datatype]['len']//3)))
    outputAlive = table.data_write()                                                                # output processed line

# ------------------------------------------ output result -----------------------------------------
  outputAlive and table.output_flush()                                                              # just in case of buffered ASCII table

  table.input_close()                                                                               # close input ASCII table
  table.output_close()                                                                              # close output ASCII table
  os.rename(file['name']+'_tmp',file['name'])                                                       # overwrite old one with tmp new
