#!/usr/bin/python

import re
import sys
import os, os.path
import ConfigParser

try:
    from Cheetah.Template import Template
except ImportError:
    print >>sys.stderr, 'ERROR: requires Cheetah templates'
    sys.exit(1)

try:
    import argparse
except ImportError:
    print >>sys.stderr, 'ERROR: requires argparse'
    sys.exit(1)

CONFIG_FILE = "/usr/local/share/easy/skeleton.conf"

def main(args):
    
    # Much of the argparse/configparser parts taken from 
    # http://blog.vwelch.com/2011/04/combining-configparser-and-argparse.html

    conf_parser = argparse.ArgumentParser(
        # Turn off help, so we print all options in response to -h
        add_help=False
    )

    conf_parser.add_argument(
        "-t", "--template-file", 
        dest="templatefile", 
        help="Use template file"
    )

    conf_parser.add_argument(
        "-c", "--config-file", 
        dest="configfile", 
        help="Use a different config file than %s" % CONFIG_FILE
    )

    args, remaining_argv = conf_parser.parse_known_args()

    if args.configfile:
        configfile = args.configfile
    else:
        configfile = CONFIG_FILE

    templatefile = args.templatefile

    # Make sure the configfile is a file
    if not os.path.isfile(configfile):
        print >>sys.stderr, 'ERROR: %s is not a file' % configfile
        sys.exit(1)

    if not os.path.isfile(templatefile):
        print >>sys.stderr, 'ERROR: %s is not a file' % templatefile
        sys.exit(1)

    config = ConfigParser.SafeConfigParser()
    try:
        config.read([configfile])
    except:
        print >>sys.stderr, 'ERROR: There is an error in the config file'
        sys.exit(1)

    defaults = dict(config.items("default"))

    parser = argparse.ArgumentParser(
        # Inherit options from config_parser
        parents=[conf_parser],
        # print script description with -h/--help
        description=__doc__,
        # Don't mess with format of description
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.set_defaults(**defaults)

    parser.add_argument("--server_name", dest="server_name", help="server_name")
    parser.add_argument("--domain", dest="domain", help="domain")
    parser.add_argument("--location_path", dest="location_path", help="location_path")
    parser.add_argument("--location_target", dest="location_target", help="location_target")

    #
    # Done with arguments
    #---------------------------------------------------------------------------

    # Capture args
    args = parser.parse_args(remaining_argv)

    # Makes args into a dictionary to feed to searchList
    d = args.__dict__

    # Create template object
    # - the searchList=[d] is the best!
    t = Template(file=templatefile, searchList=[d])

    print(t.respond())
    sys.exit(0)
    
if __name__ == '__main__':
    main(sys.argv)
