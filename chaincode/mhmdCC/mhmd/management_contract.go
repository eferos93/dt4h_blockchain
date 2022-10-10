package mhmd

import (
	"crypto/sha256"
	"encoding/json"
	"encoding/hex"
	"log"
	// "strconv"
	"fmt"
	// "github.com/hyperledger/fabric-chaincode-go/pkg/cid"
	x509 "github.com/zmap/zcrypto/x509"
)

func isAuthorizedMSP(mspID string) bool {
	if _in(mspID, AUTHORIZED_MSPS[:]) {
		return true
	}

	return false
}

// UpdateCRL Store a CRL's Revoked Certificates on chain
func (s *ManagementContract) UpdateCRL(ctx TransactionContextInterface, crlPEM string) error {
	method := "UpdateCRL"

	log.Printf(crlPEM)
	// Get MSPID
	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	// Should be non User MSP
	// if !isAuthorizedMSP(mspID) {
	// 	return fmt.Errorf("%s - Not authorized to change agreement state", method)
	// }

	// // Admin only
	// hasOuValue, err := cid.HasOUValue(ctx.GetStub(), ADMIN)
	// if err != nil {
	// 	return fmt.Errorf("%s: %v", method, err)
	// }

	// if !hasOuValue {
	// 	return fmt.Errorf("%s - OU value is not %s", method, CLIENT)
	// }

	// Cert to bytes
	crlBytes := []byte(crlPEM)

	// Parse CRL to Struct Format
	crlData, err := x509.ParseCRL(crlBytes)
	if err != nil {
		log.Printf("Error parsing CRL: " + err.Error())
		return fmt.Errorf("%s: %v", method, err)
	}

	tbsCertsList := crlData.TBSCertList
	certsList := tbsCertsList.RevokedCertificates

	for i := 0; i < len(certsList); i++ {
		revokedCert := RevokedCertificate {
			MspID: mspID,
			SerialNumber: certsList[i].SerialNumber.String(),
			RevocationTime: certsList[i].RevocationTime,
		}

		log.Printf("SerialNumber: ", revokedCert.SerialNumber)
		
		err = s.putRevokedCertState(ctx, revokedCert)
		if err != nil {
			return fmt.Errorf("%s: %v", method, err)
		}
	}

	return nil

}

// putRevokedCertState Store a revoked certificate's state
func (s *ManagementContract) putRevokedCertState(ctx TransactionContextInterface, revokedCert RevokedCertificate) error {
	method := "putRevokedCertState"
	log.Printf("%s - Putting Revoked Certificate State... ", method)

	hash := makeCertHash(ctx, revokedCert.MspID, revokedCert.SerialNumber)
	key := makeCertKey(ctx, hash)

	/* Marshal User Inventory */
	revokedCert.ObjectType = REVOKED_CERT_OBJECT_TYPE
	revokedCert.Key = hash
	revokedCertJSON, err := json.Marshal(revokedCert)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* Put Cert State */
	err = ctx.GetStub().PutState(key, revokedCertJSON)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}	

	return nil
}


// makeCertHash Generate a hash for a certificate
func makeCertHash(ctx TransactionContextInterface, mspid string, serialNumber string) string {
	hashBytes := sha256.Sum256([]byte(mspid + serialNumber))
	hash := hex.EncodeToString(hashBytes[:])
	return hash
}

// makeCertKey Generate RevokedCert's key
func makeCertKey(ctx TransactionContextInterface, hash string) string {
	key, err := ctx.GetStub().CreateCompositeKey(REVOKED_CERT_OBJECT_TYPE, []string{hash})
	if err != nil {
		return EMPTY_STR
	}

	return key
}

// GetRevokedCert Get a revoked certificate's state
func (s *ManagementContract) GetRevokedCert(ctx TransactionContextInterface, ID string, mspID string) (*RevokedCertificate, error) {
	method := "GetRevokedCert"

	hash := makeCertKey(ctx, mspID)
	key := makeCertKey(ctx, hash)

	certJSON, err := ctx.GetStub().GetState(key)
	if certJSON == nil {
		return nil, nil
	}

	var revokedCert *RevokedCertificate
	err = json.Unmarshal(certJSON, revokedCert)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return revokedCert, nil
}

// GetRevokedCertificates Get All revoked certificates
func (s *ManagementContract) GetRevokedCertificates(ctx TransactionContextInterface) ([]*RevokedCertificate, error) {
	method := "GetRevokedCertificates"


	resultsIterator, err := ctx.GetStub().GetStateByPartialCompositeKey(REVOKED_CERT_OBJECT_TYPE, nil)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer resultsIterator.Close()

	var revokedCerts []*RevokedCertificate
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		var revokedCert *RevokedCertificate
		err = json.Unmarshal(queryResponse.Value, &revokedCert)
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}
		revokedCerts = append(revokedCerts, revokedCert)
	}

	return revokedCerts, nil
}	


// assertNotRevokedCertificate Assert a certificate is not revoked
func (s *ManagementContract) assertNotRevokedCertificate(ctx TransactionContextInterface, ID string, mspID string) error {
	method := "assertRevokedCertificate"

	cert, err := s.GetRevokedCert(ctx, ID, mspID)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	if cert == nil {
		return nil
	}

	if cert.Key != EMPTY_STR {
		return fmt.Errorf("%s: User's certificate is revoked", method)
	}

	return nil
}