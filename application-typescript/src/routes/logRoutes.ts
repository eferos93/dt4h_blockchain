import { Express, Request, Response, Router } from 'express';
import { executeQuery } from '../services/fabricService';

const router = Router(); 

interface LogQueryRequest {
  query: string;
}


router.post('/logQuery', async (req: Request, res: Response) => {
    try {
      const { query } = req.body as LogQueryRequest;
      
      if (!query) {
        res.status(400).json({ 
          error: 'Missing required parameter',
          message: 'Query string is required' 
        });
        return
      }
      
      const result = await executeQuery(query);
      res.status(200).json({ result });
    } catch (error) {
      console.error('Error executing query:', error);
      res.status(500).json({ 
        error: 'Failed to execute query',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
});

export default router;