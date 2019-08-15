#!/usr/bin/env python

import base64
import rsa
import six

from st2common.runners.base_action import Action


class AwsDecryptPassworData(Action):

    def run(self, private_key, password_data):
        # copied from:
        # https://github.com/aws/aws-cli/blob/master/awscli/customizations/ec2/decryptpassword.py#L96-L122

        self.logger.debug("Decrypting password data using private_key")
        value = password_data

        if not value:
            return ''

        # Note: Somewhere in the param transformation pipeline line break and
        # carrieage return characters get messed up
        value = value.strip('\\r').strip('\\n')

        self.logger.debug('Encrypted value: "%s"' % (value))
        value = base64.b64decode(value)

        try:
            rsa_private_key = rsa.PrivateKey.load_pkcs1(six.b(private_key))
            value = rsa.decrypt(value, rsa_private_key)
            return value.decode('utf-8')
        except Exception:
            msg = ('Unable to decrypt password data using provided private key')
            self.logger.debug(msg, exc_info=True)
            raise ValueError(msg)
