require('dotenv').config();
const express = require('express');
const cors = require('cors');
const session = require('express-session');
const cookieParser = require('cookie-parser');
const authMiddleware = require('./middleware/auth');
const authRoutes = require('./routes/auth');
const marketRoutes = require('./routes/market');
const portfolioRoutes = require('./routes/portfolio');
const paperTradingRoutes = require('./routes/paperTradingRoutes');
const runMigrations = require('./config/run-migrations');
const { fixAllPortfolioBalances } = require('./config/fix-balances'); // Add near the beginning of server startup

const app = express();
const PORT = process.env.PORT || 9090;

// Configure CORS properly for credentials - REPLACE existing CORS config
const corsOptions = {
  origin: function(origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    const allowedOrigins = [
      'http://localhost:3000',
      'http://localhost:5000', 
      'http://localhost',
      'http://localhost:54597', // Flutter web default port
      'http://127.0.0.1:54597',
      undefined // For requests without Origin header
    ];
    
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(null, true); // Allow all origins in development
      // In production you might want to be more restrictive:
      // callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true, // Important for authentication
  maxAge: 86400 // Cache preflight request for 1 day
};

// Apply CORS middleware BEFORE other middleware
app.use(cors(corsOptions));
app.options('*', cors(corsOptions)); // Handle OPTIONS preflight requests

// Cookie parser middleware
app.use(cookieParser());

// Session middleware
app.use(session({
  secret: process.env.JWT_SECRET, // Use your existing JWT secret
  resave: false,
  saveUninitialized: false,
  cookie: { 
    secure: process.env.NODE_ENV === 'production', // Only secure in production
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));

app.use(express.json());

// Public routes
app.use('/api/auth', authRoutes);
app.use('/api/market', marketRoutes);

// Protected routes
app.use('/api/portfolio', authMiddleware, portfolioRoutes);

// Paper trading routes
app.use('/api/paper-trading', paperTradingRoutes);

// Add a handler for the base API route
app.get('/api', (req, res) => {
  res.json({
    status: 'success',
    message: 'NEPSE Market App API is running',
    endpoints: {
      auth: '/api/auth',
      market: '/api/market',
      portfolio: '/api/portfolio'
    }
  });
});

app.get('/', (req, res) => {
  res.send('NEPSE Market App Backend API is running');
});

// Add this with your other routes
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Check database connection and start server in proper sequence
const { db, client } = require('./config/database');

const startServer = async (port) => {
  try {
    // 1. First check database connection
    console.log('Checking database connection...');
    await client.unsafe('SELECT 1');
    console.log('Database connection successful');
    
    // 2. Then run migrations
    console.log('Running migrations...');
    await runMigrations();
    console.log('Migrations completed');
    
    // 3. Fix any portfolio balance issues at startup
    console.log('Verifying portfolio balances...');
    await fixAllPortfolioBalances();
    console.log('Balance verification completed');
    
    // 4. Finally start the server
    app.listen(port, () => {
      console.log(`Server is running on port ${port}`);
    }).on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        console.log(`Port ${port} is busy, trying ${port + 1}`);
        startServer(port + 1);
      } else {
        console.error('Server error:', err);
      }
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Start the server
startServer(PORT);