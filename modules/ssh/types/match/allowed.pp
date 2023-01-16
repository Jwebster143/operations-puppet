# SPDX-License-Identifier: Apache-2.0
type Ssh::Match::Allowed = Enum[
    'AllowAgentForwarding',
    'AllowTcpForwarding',
    'Banner',
    'ChrootDirectory',
    'ForceCommand',
    'GatewayPorts',
    'GSSAPIAuthentication',
    'HostbasedAuthentication',
    'KbdInteractiveAuthentication',
    'KerberosAuthentication',
    'KerberosUseKuserok',
    'MaxAuthTries',
    'MaxSessions',
    'PubkeyAuthentication',
    'AuthorizedKeysCommand',
    'AuthorizedKeysCommandRunAs',
    'PasswordAuthentication',
    'PermitEmptyPasswords',
    'PermitOpen',
    'PermitRootLogin',
    'RequiredAuthentications1',
    'RequiredAuthentications2',
    'RhostsRSAAuthentication',
    'RSAAuthentication',
    'X11DisplayOffset',
    'X11Forwarding',
    'X11UseLocalHost',
]