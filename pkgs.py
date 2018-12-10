#!/usr/bin/env python3
#
# This is a replacement for the formerly bash-written function pl_parsePkgs ()
#
# Usage: $0  [-a arch] default_arch keyword fcdistro pldistro pkgs-file[..s]
# default_arch is $pl_DISTRO_ARCH, but can be overridden
#

#################### original language was (in this example, keyword=package)
## to add to all distros
# package: p1 p2
## to add in one distro
# package+f12: p1 p2
## to remove in one distro
# package-f10: p1 p2
#################### replacement language
## add in distro f10
# +package=f10: p1 p2
# or simply
# package=f10: p1 p2
## add in fedora distros starting with f10
# +package>=f10: p1 p2
# or simply
# package>=f10: p1 p2
## ditto but remove instead
# -package=centos5: p1 p2
# -package<=centos5: p1 p2

# pylint: disable=c0111


import sys
from sys import stderr
from optparse import OptionParser
import re

default_arch = 'x86_64'
known_arch = ['i386', 'i686', 'x86_64']
default_fcdistro = 'f29'
known_fcdistros = [
    'centos5', 'centos6',
    # oldies but we have references to that in the pkgs files
    'f8', 'f10', 'f12', 'f14', 'f16', 'f18', 'f20', 'f21', 'f22', 'f23', 'f24',
    # these ones are still relevant
    'f25', 'f27', 'f29',
    # scientific linux
    'sl6',
    # debians
    'wheezy', 'jessie',
    # ubuntus
    'trusty',  # 14.04 LTS
    'xenial',  # 16.04 LTS
]
default_pldistro = 'onelab'

known_keywords = [
    'group', 'groupname', 'groupdesc',
     'package', 'pip', 'gem',
    'nodeyumexclude', 'plcyumexclude', 'yumexclude',
    'precious', 'junk', 'mirror',
]


m_fcdistro_cutter = re.compile('([a-z]+)([0-9]+)')
re_ident = '[a-z]+'

class PkgsParser:

    def __init__(self, arch, fcdistro, pldistro, keyword, inputs, options):
        self.arch = arch
        self.fcdistro = fcdistro
        self.pldistro = pldistro
        self.keyword = keyword
        self.inputs = inputs
        # for verbose, new_line, and the like
        self.options = options
        ok = False
        for known in known_fcdistros:
            if fcdistro == known:
                try:
                    (distro, version) = m_fcdistro_cutter.match(fcdistro).groups()
                # debian-like names can't use numbering
                except:
                    distro = fcdistro
                    version = 0
                ok = True
        if ok:
            self.distro = distro
            self.version = int(version)
        else:
            print('unrecognized fcdistro', fcdistro, file=stderr)
            sys.exit(1)

    # qualifier is either '>=','<=', or '='
    def match(self, qualifier, version):
        if qualifier == '=':
            return self.version == version
        elif qualifier == '>=':
            return self.version >= version
        elif qualifier == '<=':
            return self.version <= version
        else:
            raise Exception(
                'Internal error - unexpected qualifier {}'.format(qualifier))

    m_comment = re.compile(r'\A\s*#')
    m_blank = re.compile(r'\A\s*\Z')

    m_ident = re.compile(r'\A'+re_ident+r'\Z')
    re_qualified = r'\s*'
    re_qualified += r'(?P<plus_minus>[+-]?)'
    re_qualified += r'\s*'
    re_qualified += r'(?P<keyword>{re_ident})'.format(re_ident=re_ident)
    re_qualified += r'\s*'
    re_qualified += r'(?P<qualifier>>=|<=|=)'
    re_qualified += r'\s*'
    re_qualified += r'(?P<fcdistro>{re_ident}[0-9]+)'.format(re_ident=re_ident)
    re_qualified += r'\s*'
    m_qualified = re.compile(r'\A{}\Z'.format(re_qualified))

    re_old = '[a-z]+[+-][a-z]+[0-9]+'
    m_old = re.compile(r'\A{}\Z'.format(re_old))

    # returns a tuple (included, excluded)
    def parse(self, filename):
        ok = True
        included = []
        excluded = []
        try:
            with open(filename) as feed:
                for lineno, line in enumerate(feed, 1):
                    line = line.strip()
                    if self.m_comment.match(line) or self.m_blank.match(line):
                        continue
                    try:
                        lefts, rights = line.split(':', 1)
                        for left in lefts.split():
                            ########## single ident
                            if self.m_ident.match(left):
                                if left not in known_keywords:
                                    raise Exception("Unknown keyword {left}".format(**locals()))
                                elif left == self.keyword:
                                    included += rights.split()
                            else:
                                m = self.m_qualified.match(left)
                                if m:
                                    (plus_minus, kw, qual, fcdistro) = m.groups()
                                    if kw not in known_keywords:
                                        raise Exception("Unknown keyword in {left}".format(**locals()))
                                    if fcdistro not in known_fcdistros:
                                        raise Exception('Unknown fcdistro {fcdistro}'.format(**locals()))
                                    # skip if another keyword
                                    if kw != self.keyword: continue
                                    # does this fcdistro match ?
                                    (distro, version) = m_fcdistro_cutter.match(fcdistro).groups()
                                    version = int (version)
                                    # skip if another distro family
                                    if distro != self.distro: continue
                                    # skip if the qualifier does not fit
                                    if not self.match (qual, version):
                                        if self.options.verbose:
                                            print('{filename}:{lineno}:qualifer {left} does not apply'
                                                  .format(**locals()), file=stderr)
                                        continue
                                    # we're in, let's add (default) or remove (if plus_minus is minus)
                                    if plus_minus == '-':
                                        if self.options.verbose:
                                            print('{filename}:{lineno}: from {left}, excluding {rights}'
                                                  .format(**locals()), file=stderr)
                                        excluded += rights.split()
                                    else:
                                        if self.options.verbose:
                                            print('{filename}:{lineno}: from {left}, including {rights}'\
                                                  .format(**locals()), file=stderr)
                                        included += rights.split()
                                elif self.m_old.match(left):
                                    raise Exception('Old-fashioned syntax not supported anymore {left}'.\
                                                    format(**locals()))
                                else:
                                    raise Exception('error in left expression {left}'.format(**locals()))

                    except Exception as e:
                        ok = False
                        print("{filename}:{lineno}:syntax error: {e}".format(**locals()), file=stderr)
        except Exception as exc:
            ok = False
            print('Could not parse file', filename, exc, file=stderr)
        return (ok, included, excluded)

    def run (self):
        ok = True
        included = []
        excluded = []
        for input in self.inputs:
            (o, i, e) = self.parse (input)
            included += i
            excluded += e
            ok = ok and o
        # avoid set operations that would not preserve order
        results = [x for x in included if x not in excluded]

        results = [x.replace('@arch@', self.arch)
                   .replace('@fcdistro@', self.fcdistro)
                   .replace('@pldistro@', self.pldistro) for x in results]
        if self.options.sort_results:
            results.sort()
        # default is space-separated
        if not self.options.new_line:
            print(" ".join(results))
        # but for tests results are printed each on a line
        else:
            for result in results:
                print(result)
        return ok

def main ():
    usage = "Usage: %prog [options] keyword input[...]"
    parser = OptionParser(usage=usage)
    parser.add_option(
        '-a', '--arch', dest='arch', action='store', default=default_arch,
        help='target arch, e.g. i386 or x86_64, default={}'.format(default_arch))
    parser.add_option(
        '-f', '--fcdistro', dest='fcdistro', action='store', default=default_fcdistro,
        help='fcdistro, e.g. f12 or centos5')
    parser.add_option(
        '-d', '--pldistro', dest='pldistro', action='store', default=default_pldistro,
        help='pldistro, e.g. onelab or planetlab')
    parser.add_option(
        '-v', '--verbose', dest='verbose', action='store_true', default=False,
        help='verbose when using qualifiers')
    parser.add_option(
        '-n', '--new-line', dest='new_line', action='store_true', default=False,
        help='print outputs separated with newlines rather than with a space')
    parser.add_option(
        '-u', '--no-sort', dest='sort_results', default=True, action='store_false',
        help='keep results in the same order as in the inputs')
    (options, args) = parser.parse_args()

    if len(args) <= 1:
        parser.print_help(file=stderr)
        sys.exit(1)
    keyword = args[0]
    inputs = args[1:]
    if not options.arch in known_arch:
        print('Unsupported arch', options.arch, file=stderr)
        parser.print_help(file=stderr)
        sys.exit(1)
    if options.arch == 'i686':
        options.arch = 'i386'
    if not options.fcdistro in known_fcdistros:
        print('Unsupported fcdistro', options.fcdistro, file=stderr)
        parser.print_help(file=stderr)
        sys.exit(1)

    pkgs = PkgsParser(options.arch, options.fcdistro, options.pldistro,
                      keyword, inputs, options)

    if pkgs.run():
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    if main():
        sys.exit(0)
    else:
        sys.exit(1)
