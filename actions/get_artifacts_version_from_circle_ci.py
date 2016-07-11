import httplib
import requests

from st2actions.runners.pythonrunner import Action

API_URL = 'https://circle-artifacts.com/gh/'
HEADER_ACCEPT = 'application/json'
HEADER_CONTENT_TYPE = 'application/json'


class GetArtifactsInfo(Action):
    def _get_base_headers(self):
        headers = {}
        headers['Content-Type'] = HEADER_CONTENT_TYPE
        headers['Accept'] = HEADER_ACCEPT
        return headers

    def _get_auth_headers(self, token=None):
        headers = self._get_base_headers()

        if not token:
            raise Exception('Auth token invalid.')

        headers['circle-token'] = token
        return headers

    def run(self, project, build_number, distro, circle_token,
            artifacts_path='0/home/ubuntu/packages/payload.json'):

        path = '%s/%s/artifacts/%s' % (project, build_number,
                                       artifacts_path)
        url = API_URL + path
        self.logger.info('URL: %s', url)

        response = requests.get(
            url,
            headers=self._get_auth_headers(token=circle_token)
        )

        if response.status_code != httplib.OK:
            raise Exception('404 on URL %s.' % url)

        response = response.json()
        packages = response.get('packages', None)
        if not packages:
            msg = 'Incomaptible payload.json. "packages" field not found.'
            raise Exception(msg)

        for package in packages:
            if package.get("distro", None) == distro:
                return '%s-%s' % (package["version"], package["revision"])

        raise Exception('Distro not found in packages: %s.' % packages)
