import express, { Request, Response, NextFunction } from 'express';
import { json } from 'body-parser';
import logQueryRoutes from './routes/logRoutes';
import historyRoutes from './routes/historyRoutes';
import connectRoutes from './routes/connectRoutes';
import { isConnected } from './services/fabricService';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(json());

// Set up connect route first
app.use('/connect', connectRoutes)

// Middleware to check if connected to Fabric network
const requireConnection = (req: Request, res: Response, next: NextFunction): void => {
  if (!isConnected()) {
    res.status(401).json({ 
      error: 'Not connected to Hyperledger Fabric network',
      message: 'Please connect first using the /connect endpoint'
    });
    return;
  }
  next();
};

app.use('/logQuery', requireConnection, logQueryRoutes);
app.use('/queryHistory', requireConnection, historyRoutes);

app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});