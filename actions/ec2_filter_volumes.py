import datetime

from st2actions.runners.pythonrunner import Action


class FilterAction(Action):

    def _convert_dt(self, value):
        return datetime.datetime.strptime(value, '%Y-%m-%dT%H:%M:%S.%fZ')

    def run(self, volumes, status, age):
        timestamp = datetime.datetime.utcnow() - datetime.timedelta(seconds=age)

        filtered = [
            volume for volume in volumes
            if (volume.get('status') == status and
                    self._convert_dt(volume.get('create_time')) < timestamp)
        ]

        return filtered
