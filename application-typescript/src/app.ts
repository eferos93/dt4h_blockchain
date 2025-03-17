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

// Apply middleware to protected routes
app.use('/logQuery', requireConnection, logQueryRoutes);
app.use('/queryHistory', requireConnection, historyRoutes);
// Set up protected routes
// setLogRoutes(app);
// setHistoryRoutes(app);

app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});