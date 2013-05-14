#!/usr/bin/env python
# -*- coding: UTF-8 no BOM -*-

import os,sys,string,re,math,numpy
from optparse import OptionParser, OptionGroup, Option, SUPPRESS_HELP

#--------------------------------------------------------------------------------------------------
class extendedOption(Option):
#--------------------------------------------------------------------------------------------------
# used for definition of new option parser action 'extend', which enables to take multiple option arguments
# taken from online tutorial http://docs.python.org/library/optparse.html
    
    ACTIONS = Option.ACTIONS + ("extend",)
    STORE_ACTIONS = Option.STORE_ACTIONS + ("extend",)
    TYPED_ACTIONS = Option.TYPED_ACTIONS + ("extend",)
    ALWAYS_TYPED_ACTIONS = Option.ALWAYS_TYPED_ACTIONS + ("extend",)

    def take_action(self, action, dest, opt, value, values, parser):
        if action == "extend":
            lvalue = value.split(",")
            values.ensure_value(dest, []).extend(lvalue)
        else:
            Option.take_action(self, action, dest, opt, value, values, parser)


#--------------------------------------------------------------------------------------------------
#                                MAIN
#--------------------------------------------------------------------------------------------------
identifiers = {
        'grid':   ['a','b','c'],
        'size':   ['x','y','z'],
        'origin': ['x','y','z'],
          }
mappings = {
        'grid':            lambda x: int(x),
        'size':            lambda x: float(x),
        'origin':          lambda x: float(x),
        'homogenization':  lambda x: int(x),
        'microstructures': lambda x: int(x),
          }

parser = OptionParser(option_class=extendedOption, usage='%prog options [file[s]]', description = """
Scales a geometry description independently in x, y, and z direction in terms of grid and/or size.
""" + string.replace('$Id$','\n','\\n')
)

parser.add_option('-g', '--grid', dest='grid', type='int', nargs = 3, \
                  help='a,b,c grid of hexahedral box [unchanged]')
parser.add_option('-s', '--size', dest='size', type='float', nargs = 3, \
                  help='x,y,z size of hexahedral box [unchanged]')
parser.add_option('-2', '--twodimensional', dest='twoD', action='store_true', \
                  help='output geom file with two-dimensional data arrangement [%default]')

parser.set_defaults(grid = [0,0,0])
parser.set_defaults(size  = [0.0,0.0,0.0])
parser.set_defaults(twoD = False)

(options, filenames) = parser.parse_args()

#--- setup file handles ---------------------------------------------------------------------------
files = []
if filenames == []:
  files.append({'name':'STDIN',
                'input':sys.stdin,
                'output':sys.stdout,
                'croak':sys.stderr,
               })
else:
  for name in filenames:
    if os.path.exists(name):
      files.append({'name':name,
                    'input':open(name),
                    'output':open(name+'_tmp','w'),
                    'croak':sys.stdout,
                    })

#--- loop over input files ------------------------------------------------------------------------
for file in files:
  if file['name'] != 'STDIN': file['croak'].write(file['name']+'\n')

  firstline = file['input'].readline()
  m = re.search('(\d+)\s*head', firstline.lower())
  if m:
    headerlines = int(m.group(1))
    headers  = [file['input'].readline() for i in range(headerlines)]
  else:
    headerlines = 1
    headers = firstline

  content = file['input'].readlines()
  file['input'].close()

#--- interprete header ----------------------------------------------------------------------------
  info = {
          'grid':    numpy.zeros(3,'i'),
          'size':    numpy.zeros(3,'d'),
          'origin':  numpy.zeros(3,'d'),
          'microstructures': 0,
          'homogenization':  0
         }
  newInfo = {
          'grid':   numpy.array(options.grid),
          'size':   numpy.array(options.size),
          'microstructures': 0,
         }

  new_header = []
  for header in headers:
    headitems = map(str.lower,header.split())
    if headitems[0] == 'resolution': headitems[0] = 'grid'
    if headitems[0] == 'dimension':  headitems[0] = 'size'
    if headitems[0] in mappings.keys():
      if headitems[0] in identifiers.keys():
        for i in xrange(len(identifiers[headitems[0]])):
          info[headitems[0]][i] = \
            mappings[headitems[0]](headitems[headitems.index(identifiers[headitems[0]][i])+1])
      else:
        info[headitems[0]] = mappings[headitems[0]](headitems[1])
    else:
      new_header.append(header)

  file['croak'].write('grid     a b c:  %s\n'%(' x '.join(map(str,info['grid']))) + \
                      'size     x y z:  %s\n'%(' x '.join(map(str,info['size']))) + \
                      'origin   x y z:  %s\n'%(' : '.join(map(str,info['origin']))) + \
                      'homogenization:  %i\n'%info['homogenization'] + \
                      'microstructures: %i\n\n'%info['microstructures'])
  
  if numpy.any(info['grid'] < 1):
    file['croak'].write('no valid grid info found.\n')
    sys.exit()
  if numpy.any(info['size'] <= 0.0):
    file['croak'].write('no valid size info found.\n')
    sys.exit()

  if numpy.all(info['grid'] == 0):
    newInfo['grid'] = info['grid']
  if numpy.all(info['size'] == 0.0)::
    newInfo['size'] = info['size']

#--- read data ------------------------------------------------------------------------------------
  microstructure = numpy.zeros(info['grid'],'i')
  i = 0
  for line in content:  
    for item in map(int,line.split()):
      microstructure[i%info['grid'][0],
                    (i/info['grid'][0])%info['grid'][1],
                     i/info['grid'][0] /info['grid'][1]] = item
      i += 1
  newInfo['microstructures'] = microstructure.max()
  formatwidth = 1+int(math.floor(math.log10(microstructure.max())))
  
  if (any(newInfo['grid'] != info['grid'])):
    file['croak'].write('--> grid     a b c:  %s\n'%(' x '.join(map(str,newInfo['grid']))))
  if (any(newInfo['size'] != info['size'])):
    file['croak'].write('--> size     x y z:  %s\n'%(' x '.join(map(str,newInfo['size']))))
  if (newInfo['microstructures'] != info['microstructures']):
    file['croak'].write('--> microstructures: %i\n'%newInfo['microstructures'])
  
  if numpy.any(newInfo['grid'] < 1):
    file['croak'].write('no valid new grid info found.\n')
    sys.exit()
  if numpy.any(newInfo['size'] <= 0.0):
    file['croak'].write('no valid new size info found.\n')
    sys.exit()

#--- assemble header ------------------------------------------------------------------------------
  new_header.append('$Id$\n')
  new_header.append("grid\ta %i\tb %i\tc %i\n"%(newInfo['grid'][0],newInfo['grid'][1],newInfo['grid'][2]))
  new_header.append("size\tx %f\ty %f\tz %f\n"%(newInfo['size'][0],newInfo['size'][1],newInfo['size'][2]))
  new_header.append("origin\tx %f\ty %f\tz %f\n"%(info['origin'][0],info['origin'][1],info['origin'][2]))
  new_header.append("microstructures\t%i\n"%newInfo['microstructures'])
  new_header.append("homogenization\t%i\n"%info['homogenization'])
  output  = '%i\theader\n'%(len(new_header))
  output += ''.join(new_header)
  
#--- scale microstructure -------------------------------------------------------------------------
  for c in xrange(newInfo['grid'][2]):
    z = int(info['grid'][2]*(c+0.5)/newInfo['grid'][2])%info['grid'][2]
    for b in xrange(newInfo['grid'][1]):
      y = int(info['grid'][1]*(b+0.5)/newInfo['grid'][1])%info['grid'][1]
      for a in xrange(newInfo['grid'][0]):
        x = int(info['grid'][0]*(a+0.5)/newInfo['grid'][0])%info['grid'][0]
        output += str(microstructure[x,y,z]).rjust(formatwidth) + {True:' ',False:'\n'}[options.twoD]
      output += {True:'\n',False:''}[options.twoD]
  file['output'].write(output)

#--- output finalization --------------------------------------------------------------------------
  if file['name'] != 'STDIN':
    file['output'].close()
    os.rename(file['name']+'_tmp',file['name'])
    
