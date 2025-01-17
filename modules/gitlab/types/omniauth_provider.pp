# SPDX-License-Identifier: Apache-2.0
type Gitlab::Omniauth_provider = Variant[
    Gitlab::Omniauth_provider::Cas3,
    Gitlab::Omniauth_provider::OIDC,
]
