Using dev mode
==============

Open 3 Terminals:

Terminal 1:

```bash
cd fabric/chaincode-docker-dev
docker-compose -f docker-compose-simple.yaml up
```

Terminal 2:

```bash
docker exec -it -u root chaincode sh
go build && ./chaincode -peer.address peer:7052
```

Terminal 3:

```bash
docker exec -it cli sh
peer chaincode install -p chaincode -n mycc -v 0
peer chaincode instantiate -n mycc -v 0 -c '{"Args":[]}' -C myc
```

