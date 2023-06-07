# TROUBLESHOOT

## Error: Cannot create newEndorsement of undefined

Wrong channel name in ccp.yaml or as argument

## Failed to connect before the deadline on Committer/Endorser

No hosts appended on /etc/hosts or node is down

## Fabric-ca request ENROLL failed with errors [[ { code: 20, message: 'Authentication failure' } ]]

Wrong secret for user enrolling

## Fabric-ca request REGISTER failed with errors [[ { code: 20, message: 'Authentication failure' } ]]

Wrong certificate for admin

## Channel-Credentials must be a ChannelCredetials object

2 different versions of GRPC on node_modules. 


#### Net suggestions
I had to:

remove node_modules
update dependencies
reinstall
as follows

cd functions
rm -rf node_modules
npm install -g npm-check-updates
ncu -u
npm install

TypeError: Channel's second argument must be a ChannelCredentials

We are affected by this bug as well. We have two modules that both require grpc. I was able to work around this by upgrading to npm 5.5.1 which performs deduping of modules that share the same version. Migrating to yarn should have the same effect.

I have solved this problem. Firstly, you should uninstall your current version grpc. Then, install older version grpc. In my case, now i install grpc@1.10.1



## Discovery Service: (channel name) error: access denied

Wrong certificate or wrong channel name

## Identity not found in wallet.

Not enrolled or enrollment failed and identity does not exist in wallet. Try to enroll the user.

## Chaincode error: cannot unmarshal string into Go struct

Wrong JSON format, meaning a field is not the right type for the contract. For example sending a string where it should be array of strings etc..

## RST STREAM ERROR

* Wrong values on metadata, maybe new line on a string.
* Grpc version mismatch, try other calls also to verify. If other calls work, then its metadata.

