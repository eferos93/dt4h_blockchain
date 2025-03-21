package main

import (
	"fmt"
	"rest-api-go/web"
)

func main() {
	//Initialize setup for bsc
	cryptoPath := "identities/blockClient/"
	orgConfig := web.OrgSetup{
		OrgName:      "bsc",
		MSPID:        "BscMSP",
		CertPath:     cryptoPath + "msp/signcerts/cert.pem",
		KeyPath:      cryptoPath + "msp/keystore/",
		TLSCertPath:  cryptoPath + "tls/tlscacerts/ca.crt",
		PeerEndpoint: "dns:///localhost:9051",
		GatewayPeer:  "peer0.bsc.domain.com",
	}

	fmt.Printf("")
	orgSetup, err := web.Initialize(orgConfig)
	if err != nil {
		fmt.Println("Error initializing setup for bsc: ", err)
	}
	web.Serve(web.OrgSetup(*orgSetup))
}
