#!/usr/bin/env python3

import os
import sys
from optparse import OptionParser

import numpy as np

import damask


scriptName = os.path.splitext(os.path.basename(__file__))[0]
scriptID   = ' '.join([scriptName,damask.version])

def operator(stretch,strain,eigenvalues):
  """Albrecht Bertram: Elasticity and Plasticity of Large Deformations An Introduction (3rd Edition, 2012), p. 102."""
  return {
    'V#ln':    np.log(eigenvalues)                      ,
    'U#ln':    np.log(eigenvalues)                      ,
    'V#Biot':  ( np.ones(3,'d') - eigenvalues**-1.0)    ,
    'U#Biot':  ( eigenvalues**1.0  - np.ones(3,'d'))    ,
    'V#Green': ( np.ones(3,'d') - eigenvalues**-2.0)*0.5,
    'U#Green': ( eigenvalues**2.0 - np.ones(3,'d')) *0.5,
         }[stretch+'#'+strain]


# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog options [ASCIItable(s)]', description = """
Add column(s) containing given strains based on given stretches of requested deformation gradient column(s).

""", version = scriptID)

parser.add_option('-u','--right',
                  dest = 'right',
                  action = 'store_true',
                  help = 'material strains based on right Cauchy--Green deformation, i.e., C and U')
parser.add_option('-v','--left',
                  dest = 'left',
                  action = 'store_true',
                  help = 'spatial strains based on left Cauchy--Green deformation, i.e., B and V')
parser.add_option('-0','--logarithmic',
                  dest = 'logarithmic',
                  action = 'store_true',
                  help = 'calculate logarithmic strain tensor')
parser.add_option('-1','--biot',
                  dest = 'biot',
                  action = 'store_true',
                  help = 'calculate biot strain tensor')
parser.add_option('-2','--green',
                  dest = 'green',
                  action = 'store_true',
                  help = 'calculate green strain tensor')
parser.add_option('-f','--defgrad',
                  dest = 'defgrad',
                  action = 'extend',
                  metavar = '<string LIST>',
                  help = 'heading(s) of columns containing deformation tensor values [%default]')

parser.set_defaults(
                    defgrad     = ['f'],
                   )

(options,filenames) = parser.parse_args()

if len(options.defgrad) > 1:
  options.defgrad = options.defgrad[1:]

stretches = []
strains = []

if options.right: stretches.append('U')
if options.left:  stretches.append('V')
if options.logarithmic: strains.append('ln')
if options.biot:        strains.append('Biot')
if options.green:       strains.append('Green')

if options.defgrad is None:
  parser.error('no data column specified.')

# --- loop over input files -------------------------------------------------------------------------

if filenames == []: filenames = [None]

for name in filenames:
  try:
    table = damask.ASCIItable(name = name,
                              buffered = False)
  except IOError: continue
  damask.util.report(scriptName,name)

# ------------------------------------------ read header ------------------------------------------

  table.head_read()

# ------------------------------------------ sanity checks ----------------------------------------

  items = {
            'tensor': {'dim': 9, 'shape': [3,3], 'labels':options.defgrad, 'column': []},
          }
  errors  = []
  remarks = []
  
  for type, data in items.items():
    for what in data['labels']:
      dim = table.label_dimension(what)
      if dim != data['dim']: remarks.append('column {} is not a {}...'.format(what,type))
      else:
        items[type]['column'].append(table.label_index(what))
        for theStretch in stretches:
          for theStrain in strains:
            table.labels_append(['{}_{}({}){}'.format(i+1,                                          # extend ASCII header with new labels  
                                                      theStrain,
                                                      theStretch,
                                                      what if what != 'f' else '') for i in range(9)])

  if remarks != []: damask.util.croak(remarks)
  if errors  != []:
    damask.util.croak(errors)
    table.close(dismiss = True)
    continue

# ------------------------------------------ assemble header --------------------------------------

  table.info_append(scriptID + '\t' + ' '.join(sys.argv[1:]))
  table.head_write()

# ------------------------------------------ process data ------------------------------------------

  stretch = {}
  outputAlive = True

  while outputAlive and table.data_read():                                                          # read next data line of ASCII table
    for column in items['tensor']['column']:                                                        # loop over all requested defgrads
      F = np.array(list(map(float,table.data[column:column+items['tensor']['dim']])),'d').reshape(items['tensor']['shape'])
      (U,S,Vh) = np.linalg.svd(F)                                                                   # singular value decomposition
      R_inv = np.dot(U,Vh).T                                                                        # rotation of polar decomposition
      stretch['U'] = np.dot(R_inv,F)                                                                # F = RU
      stretch['V'] = np.dot(F,R_inv)                                                                # F = VR

      for theStretch in stretches:
        (D,V) = np.linalg.eigh((stretch[theStretch]+stretch[theStretch].T)*0.5)                     # eigen decomposition (of symmetric(ed) matrix)
        for theStrain in strains:
          d = operator(theStretch,theStrain,D)                                                      # operate on eigenvalues of U or V
          eps = np.dot(V,np.dot(np.diag(d),V.T)).reshape(9)                                         # build tensor back from eigenvalue/vector basis

          table.data_append(list(eps))

# ------------------------------------------ output result -----------------------------------------

    outputAlive = table.data_write()                                                                # output processed line

# ------------------------------------------ output finalization -----------------------------------  

  table.close()                                                                                     # close ASCII tables
