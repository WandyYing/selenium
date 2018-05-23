import argparse
import os
import re

import requests

from subprocess import call as command_call
# from invoke import task
from reportportal_client.service import ReportPortalService
from reportportal_listener.service import timestamp


def run__tests(report_portal_params=None):
    """Run tests.

    Args:
        additional_params: additional parameters.
        report_portal_params (list): parameters of report portal.

    Returns:
        tests results.
    """
    # with tc_log('Run  tests'):
    pabot = ["pabot",
             "--pabotlib",
             "--processes", "10",
             "--outputdir", "report-demo",
             "--reporttitle", " TEST REPORT",
             "--log", "log.html",
             "--report", "report.html",
             "--output", "output.xml",
             "--xunit", "xunit.xml",
             "--xunitskipnoncritical",
             "--exclude", "develop",
             "--exclude", "selftest",
             "--reportbackground", "white:white:white",
             "--noncritical", "noncritical",
             "--randomize", "suites",
             "--consolewidth", "150",
             "--removekeywords", "WUKS",
             "--removekeywords", "FOR",
             "--tagstatexclude", "testrailid=*"
             ]  # yapf: disable

        # Extending with report portal parameters
    if report_portal_params:
        pabot.extend(report_portal_params)

    # pabot.append(".")
    result = command_call(pabot, shell = False)
    # result = command_call(pabot, env=environment_variables())
    # remove_duplicated_messages(output_dir(), pabot)
    return result

def parse_arguments():
    """Parse passed arguments using argument parser.

    Returns:
        Object with parsed arguments.
    """
    parser = argparse.ArgumentParser(description='Prepare server')

    # register additional parameters for Report Portal integration
    parser.add_argument('--rp_endpoint', action="store", dest='rp_endpoint', default=None,
                        help="Endpoint of Report Portal. E.g.: http://reportportalhost.ru:8080")
    parser.add_argument('--rp_project', action="store", dest='rp_project', default=None,
                        help="Project name of Report Portal.")
    parser.add_argument('--rp_uuid', action="store", dest='rp_uuid', default=None,
                        help="Unique identifier of user to log data in Report Portal.")
    parser.add_argument('--rp_launch_doc', action="store", dest='rp_launch_doc', default=None,
                        help="Launch description in Report Portal. E.g.: you can paste here link to teamcity build.")
    parser.add_argument('--rp_launch_tags', action="store", dest='rp_launch_tags', default=None,
                        help="Launch additional tags to filter launches in Report Portal.")
    parser.add_argument('--rp_launch_name', action="store", dest='rp_launch_name', default=None,
                        help="Report name of Report Portal.")
    parser.add_argument('--tests_folder_name', action="store", dest='tests_folder_name', default="tests",
                        help="tests root folder name.")

    return parser.parse_args()

def _rp_register_launch(rp_service_instance, rp_launch_name, rp_launch_doc="", rp_launch_tags=""):
    """Register new launch using report portal HTTP API.

    Args:
        rp_service_instance (ReportPortalService): Report Portal Robot Service instance.
        rp_launch_name: Launch name to be registered in Report Portal to serve logs from test run.
        rp_launch_doc: Additional information to be set up under RP launch.
        rp_launch_tags: comma separated tags for launch.
    Returns:
        str: Report Portal Launch ID or it silently returns None if any error occurs.
    """
    # with tc_log("Register Report Portal Launch"):
    new_launch_id = None
    try:
        new_launch_id = rp_service_instance.start_launch(name=rp_launch_name, start_time=timestamp(),
                                                         description=rp_launch_doc, tags=rp_launch_tags.split(','),
                                                         mode='DEFAULT')
        # tc_message("New Report Portal launch id: {}".format(new_launch_id))
    except Exception as e:
        print("Report Portal launch was not created due to issue: ")
        print(e)
        # tc_message("Report Portal launch was not created due to issue:", status='WARNING')
        # tc_message(e, status='WARNING')
    return new_launch_id

def run__tests_with_report_portal(args):
    """Run tests with report portal integration.

    This function creates a new launch in Report Portal and
    passes it into the test runner method.

    Args:
        args: parsed arguments using argparse.

    Returns:
        Exit code as an execution result of test run script.
    """
    # init report portal service to create new launch
    rp_service = ReportPortalService(endpoint=args.rp_endpoint, project=args.rp_project, token=args.rp_uuid)
    # register new launch to serve test results
    launch_name = args.rp_launch_name or " TEST REPORT"
    launch_id = _rp_register_launch(rp_service_instance=rp_service, rp_launch_name=launch_name,
                                    rp_launch_doc=args.rp_launch_doc, rp_launch_tags=args.rp_launch_tags)
    print("**"*60)
    print("launch_id: %r" % launch_id)
    # register params to pass
    rp_params = [
        '--listener', 'reportportal_listener:{launch_id}'.format(launch_id=launch_id),
        '--variable', 'RP_ENDPOINT:{rp_endpoint}'.format(rp_endpoint=args.rp_endpoint),
        '--variable', 'RP_UUID:{rp_uuid}'.format(rp_uuid=args.rp_uuid),
        '--variable', 'RP_LAUNCH:\'{rp_launch_name}\''.format(rp_launch_name=launch_name),
        '--variable', 'RP_PROJECT:{rp_project}'.format(rp_project=args.rp_project),
        '--variable', 'RP_LAUNCH_TAGS:{rp_launch_tags}'.format(rp_launch_tags=args.rp_launch_tags),
        '--variable', 'RP_LAUNCH_DOC:\'{rp_launch_doc}\''.format(rp_launch_doc=args.rp_launch_doc),
        args.tests_folder_name,
    ]  # yapf: disable
    # run pabot execution with parameters of report portal integration
    rt_code = run__tests(rp_params)
    # close report portal launch after script ends up with running tests
    print("**"*60)
    print("_rp_close_launch: %r" % launch_id)
    _rp_close_launch(rp_service_instance=rp_service)
    return rt_code

def _rp_close_launch(rp_service_instance):
    """Close Report Portal launch.

    Args:
        rp_service_instance (ReportPortalService): Report Portal Robot Service instance.
    """
    # with tc_log("Closing Report Portal Launch"):
    rp_service_instance.finish_launch(end_time=timestamp(), status=None)
        # tc_message("Report Portal Launch is closed")

def main(args):
    """Script entry point.

    Args:
        args: parsed arguments using argparse.
    """
    # If Report Portal endpoint parameter is provided
    if args.rp_endpoint:
        # checking if Report Portal is available
        rp_resp = requests.head(args.rp_endpoint)
        if rp_resp.ok:
            rt_code = run__tests_with_report_portal(args)
        else:
            error_msg = 'Report Portal is not available. Error: {code} {reason}'.format(
                code=rp_resp.status_code, reason=rp_resp.reason)

    exit(rt_code)

if __name__ == "__main__":
    arguments = parse_arguments()
    # print(arguments)
    main(arguments)