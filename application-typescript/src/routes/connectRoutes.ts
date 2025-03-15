import { Express, Request, Response } from 'express';
import { connectToNetwork } from '../services/fabricService';

interface ConnectRequest {
  certPath: string;
  keyPath: string;
}

export const setConnectRoutes = (app: Express): void => {
  app.post('/connect', async (req: Request, res: Response) => {
    try {
      const { certPath, keyPath } = req.body as ConnectRequest;
      
      if (!certPath || !keyPath) {
        return res.status(400).json({ 
          error: 'Missing required parameters',
          message: 'Both certPath and keyPath are required' 
        });
      }

      await connectToNetwork(certPath, keyPath);
      res.status(200).json({ 
        message: 'Successfully connected to Hyperledger Fabric network'
      });
    } catch (error) {
      console.error('Failed to connect to network:', error);
      res.status(500).json({ 
        error: 'Failed to connect to network',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
};