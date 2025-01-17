type Haproxy::Sticktable = Struct[{
    'name'      => String,
    'type'      => Enum['ipv6'],  # TODO add more but this is all we need for now
    'size'      => String,  # e.g. "1m"
    'expire'    => Optional[String],  # e.g. "60s"
    'store'     => Array[String],  # e.g. "conn_rate(10s)" or "http_req_rate(20s)" or "gpc0_rate(1m)"
}]
