from st2actions.runners.pythonrunner import Action
from st2client.client import Client

# Keep Compatability with 0.8 and 0.11 until st2build is upgraded
try:
    from st2client.models.datastore import KeyValuePair
except ImportError:
    from st2client.models.keyvalue import KeyValuePair


class KVPAction(Action):

    def run(self, key, action, st2host='localhost', value=""):

        try:
            client = Client()
        except Exception as e:
            return e

        if action == 'get':
            kvp = client.keys.get_by_name(key)

            if not kvp:
                raise Exception('Key error with %s.' % key)

            return kvp.value
        else:
            instance = client.keys.get_by_name(key) or KeyValuePair()
            instance.id = key
            instance.name = key
            instance.value = value

            kvp = client.keys.update(instance) if action in ['create', 'update'] else None

            if action == 'delete':
                return kvp
            else:
                return kvp.serialize()
