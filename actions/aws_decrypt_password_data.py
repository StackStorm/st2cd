#!/usr/bin/env python

import base64
import rsa
import six

from st2common.runners.base_action import Action


class AwsDecryptPassworData(Action):

    def run(self, keyfile, password_data):
        # copied from:
        # https://github.com/aws/aws-cli/blob/master/awscli/customizations/ec2/decryptpassword.py#L96-L122

        self.logger.debug("Decrypting password data using: %s", keyfile)
        value = password_data

        if not value:
            return ''

        # Hack because somewhere in the Mistral parameter "publish" pipeline, we
        # strip trailing and leading whitespace from a string which results in
        # an invalid base64 string
        if not value.startswith('\r\n'):
            value = '\r\n' + value

        if not value.endswith('\r\n'):
            value = value + '\r\n'

        self.logger.debug('Encrypted value: "%s"' % (value))
        value = base64.b64decode(value)

        try:
            with open(keyfile) as pk_file:
                pk_contents = pk_file.read()
                private_key = rsa.PrivateKey.load_pkcs1(six.b(pk_contents))
                value = rsa.decrypt(value, private_key)
                return value.decode('utf-8')
        except Exception:
            msg = ('Unable to decrypt password data using '
                   'provided private key file: {}').format(keyfile)
            self.logger.debug(msg, exc_info=True)
            raise ValueError(msg)
