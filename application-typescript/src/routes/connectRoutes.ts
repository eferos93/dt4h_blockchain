import { Request, Response, Router } from 'express';
import { connectToNetwork } from '../services/fabricService';

const router = Router();

interface NetworkSetup {
  peerEndpoint: string,
  tlsRootCertPath: string,
  mspId: string,
  channelName: string

}

interface ConnectRequest {
  certPath: string;
  keyPath: string;
  config: NetworkSetup;
}


  router.post('/', async (req: Request, res: Response) => {
    try {
      const { certPath, keyPath, config } = req.body as ConnectRequest;
      
      if (!certPath || !keyPath || !config) {
        res.status(400).json({ 
          error: 'Missing required parameters',
          message: 'Both certPath and keyPath are required' 
        });
      }

      await connectToNetwork(certPath, keyPath, config);
      res.status(200).json({ 
        message: 'Successfully connected to Hyperledger Fabric network',
      });
    } catch (error) {
      console.error('Failed to connect to network:', error);
      res.status(500).json({ 
        error: 'Failed to connect to network',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });

export default router;