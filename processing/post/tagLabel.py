#!/usr/bin/env python
# -*- coding: UTF-8 no BOM -*-

import os,re,sys,math,string
import damask
from optparse import OptionParser

scriptID   = string.replace('$Id$','\n','\\n')
scriptName = os.path.splitext(scriptID.split()[1])[0]

# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog [options] dfile[s]', description = """
Tag scalar, vectorial, and/or tensorial data header labels by specified suffix.

""", version = scriptID)

parser.add_option('-l','--tag',         dest='tag', \
                                        help='tag to use as suffix for labels')
parser.add_option('-v','--vector',      dest='vector', action='extend', \
                                        help='heading of columns containing 3x1 vector field values')
parser.add_option('-t','--tensor',      dest='tensor', action='extend', \
                                        help='heading of columns containing 3x3 tensor field values')
parser.add_option('-s','--special',     dest='special', action='extend', \
                                        help='heading of columns containing field values of special dimension')
parser.add_option('-d','--dimension',   dest='N', type='int', \
                                        help='dimension of special field values [%default]')

parser.set_defaults(tag = '')
parser.set_defaults(vector = [])
parser.set_defaults(tensor = [])
parser.set_defaults(special = [])
parser.set_defaults(N = 1)

(options,filenames) = parser.parse_args()

datainfo = {                                                               # list of requested labels per datatype
             'vector':     {'len':3,
                            'label':[]},
             'tensor':     {'len':9,
                            'label':[]},
             'special':    {'len':options.N,
                            'label':[]},
           }


if options.vector  != None:    datainfo['vector']['label']  += options.vector
if options.tensor  != None:    datainfo['tensor']['label']  += options.tensor
if options.special != None:    datainfo['special']['label'] += options.special


# ------------------------------------------ setup file handles ---------------------------------------  

files = []
if filenames == []:
  files.append({'name':'STDIN', 'input':sys.stdin, 'output':sys.stdout})
else:
  for name in filenames:
    if os.path.exists(name):
      files.append({'name':name, 'input':open(name), 'output':open(name+'_tmp','w')})

# ------------------------------------------ loop over input files ---------------------------------------  

for file in files:
  if file['name'] != 'STDIN': print file['name']

  table = damask.ASCIItable(file['input'],file['output'],False)             # make unbuffered ASCII_table
  table.head_read()                                                         # read ASCII header info
  table.info_append(string.replace('$Id$','\n','\\n') + \
                    '\t' + ' '.join(sys.argv[1:]))

# ------------------------------------------ process labels ---------------------------------------  

  if options.vector == [] and options.tensor == [] and options.special == []: # default to tagging all labels
    for i,label in enumerate(table.labels):
      table.labels[i] += options.tag
  else:                                                                       # tag individual candidates
    for datatype,info in datainfo.items():
      for label in info['label']:
        key = '1_%s' if [info['len']>1]%label else '%'
        if key not in table.labels:
          sys.stderr.write('column %s not found...\n'%key)
        else:
          offset = table.labels.index(key)
          for i in xrange(info['len']):
            table.labels[offset+i] += options.tag

# ------------------------------------------ assemble header ---------------------------------------  

  table.head_write()

# ------------------------------------------ process data ---------------------------------------  

  outputAlive = True
  while outputAlive and table.data_read():                                  # read next data line of ASCII table
    outputAlive = table.data_write()                                        # output processed line

# ------------------------------------------ output result ---------------------------------------  

  outputAlive and table.output_flush()                                      # just in case of buffered ASCII table

  table.input_close()                                                       # close input ASCII table
  if file['name'] != 'STDIN':
    file['output'].close                                                    # close output ASCII table
    os.rename(file['name']+'_tmp',file['name'])                             # overwrite old one with tmp new
