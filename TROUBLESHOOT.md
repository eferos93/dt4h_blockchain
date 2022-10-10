# TROUBLESHOOT

## Error: 403 56 "Identity removal is disabled"
#### NODE SDK DOES NOT PROVIDE IDENTITY REMOVE FUNCTIONALITY YET
Delete User or Authentication Failure on node sdk
2022/01/20 11:16:09 [INFO] 172.18.0.1:40652 DELETE /identities/test_03?ca=ca-lynkeus-users&force=false

need to add allowremoval on ca_config.yaml
```yaml
cfg:
  identities:
    passwordattempts: 10
    allowremoval: true
```

## Error: ChannelCredentials

Solution from internet: 
This state requires the containing project to match the same grpc version in the generated code (that is usually a different node module).

Firstly, you should uninstall your current version grpc. Then, check grpc versions to match or be close and install.


## Error: [Error [ERR_TLS_CERT_ALTNAME_INVALID]: Hostname/IP does not match certificate's altnames: IP: XXXXXXXXXXXX is not in the cert's list: 

The URL HOSTNAME in *ccp.yaml* must be included in fabric-ca-org-config.yaml file at:

```yaml
csr:
   cn: fabric-ca-server
   keyrequest:
     algo: ecdsa
     size: 256
   names:
      - C: IT
        ST: ITST
        L:
        O: Hyperledger
        OU: Fabric
   hosts:
     - XXXXXXXXXX
   ca:
      expiry: 131400h
      pathlength: 1 
```

## Error: Identity expired XXh ago. (Expired Node MSP Certificates)

1. If MSPs are expired, renew MSPs (IDentity CA only) and restart Node

## Error: CA Bad TLS Certificate

It fabric-ca-server/tls-cert.pem has expired, renew it by deleting it and restarting the server.


## Update Orderer TLS Certificates
*A network with no way to restore the orderer certs cannot operate again, because channel updates cannot be issued with expired certs.*

1. If TLS are expired, renew TLS but don't restart Orderer, keep old certs.
2. For every Orderer separately, Start with system channel and then every application channel
3. Fetch channel config
4. Put new TLS Cert in .groups. ... .consenters.client_tls_certs and server_tls_certs
5. Create Update configuration TX.
6. Sign TX according to policy (Most likely majority admins)
7. Submit channel update.
8. Restart orderer (only on first update needed to restart)


## Expired Orderer TLS Certificates

Since CA 1.5.1, reenroll command can reuse existing private/public key pair. So the cert expiration date is updated and the key is kept, meaning that Orderer TLS Certs can be renewed with no need to perform channel updates. This happens because orderers check only the private/public key pair for validity in the channel and since this stays the same, the new cert is approved. So using reenroll to renew the certs the Ordering Service will be able to reach consensus after node restart. 

## Never UPDATE Deployed Chaincode struct field type

Let's say we have stored assets inside blockchain of type
struct Asset = {
  int a
  int b
}

If we change int a to float a, since the implementation (functions etc) always expect arguments or return values of type Asset most likely, all the assets prior to the update will fail to unmarshall, so everything will be frozen. For example, if we have a function getAsset returns Asset, Asset is now 
Asset {
  float a
  int b
}

and the item we fetch is of type 
Asset {
  int a
  int b
}

so it will fail. There is no workaround for this, so never update a struct field type on a deployed version