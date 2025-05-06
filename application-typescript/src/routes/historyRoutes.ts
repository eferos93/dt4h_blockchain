import { Request, Response, Router } from 'express';
import { getQueryHistory } from '../services/fabricService';

const router = Router();

router.get('/', async (req: Request, res: Response) => {
    try {
      const key = req.query.key as string;
      
      if (!key) {
        res.status(400).json({ 
          error: 'Missing required parameter',
          message: 'Key parameter is required' 
        });
        return 
      }
      
      const history = await getQueryHistory(key);
      console.log("query history for client ", req.query.key, ": ", history)
      res.status(200).json({ history });
    } catch (error) {
      console.error('Error getting query history:', error);
      res.status(500).json({ 
        error: 'Failed to get query history',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });

export default router;