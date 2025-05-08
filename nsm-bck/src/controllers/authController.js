const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { db } = require('../config/database');
const { users } = require('../models/schema');
const { eq } = require('drizzle-orm');

const authController = {
  register: async (req, res) => {
    try {
      console.log('Registration request received:', req.body);
      const { name, email, password } = req.body;
      
      if (!email || !password) {
        return res.status(400).json({ error: 'Email and password are required' });
      }
      
      console.log('Checking if user exists...');
      // Check if user already exists
      const existingUser = await db.query.users.findFirst({
        where: eq(users.email, email)
      });
      
      console.log('Existing user check result:', existingUser);
      if (existingUser) {
        return res.status(400).json({ error: 'User already exists' });
      }
      
      console.log('Hashing password...');
      // Hash password
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(password, salt);
      
      console.log('Creating new user...');
      // Create new user
      const [newUser] = await db.insert(users).values({
        name,
        email,
        password: hashedPassword
      }).returning();
      
      console.log('User created:', newUser);
      
      // Generate JWT
      const token = jwt.sign(
        { user: { id: newUser.id } },
        process.env.JWT_SECRET,
        { expiresIn: '24h' }
      );
      
      // Store session data
      req.session.userId = newUser.id;
      
      // Set HTTP-only cookie with the token
      res.cookie('auth_token', token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        maxAge: 24 * 60 * 60 * 1000 // 24 hours
      });
      
      res.status(201).json({
        token,
        user: {
          id: newUser.id,
          name: newUser.name,
          email: newUser.email
        }
      });
    } catch (error) {
      console.error('Register error details:', error);
      res.status(500).json({ error: error.message });
    }
  },
  
  login: async (req, res) => {
    try {
      const { email, password } = req.body;
      
      if (!email || !password) {
        return res.status(400).json({ error: 'Email and password are required' });
      }
      
      // Find user by email
      const user = await db.query.users.findFirst({
        where: eq(users.email, email)
      });
      
      if (!user) {
        return res.status(400).json({ error: 'Invalid credentials' });
      }
      
      // Compare passwords
      const isMatch = await bcrypt.compare(password, user.password);
      
      if (!isMatch) {
        return res.status(400).json({ error: 'Invalid credentials' });
      }
      
      // Generate JWT
      const token = jwt.sign(
        { user: { id: user.id } },
        process.env.JWT_SECRET,
        { expiresIn: '24h' }
      );
      
      // Store session data
      req.session.userId = user.id;
      
      // Set HTTP-only cookie with the token
      res.cookie('auth_token', token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        maxAge: 24 * 60 * 60 * 1000 // 24 hours
      });
      
      res.json({
        token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email
        }
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ error: error.message });
    }
  },
  
  getMe: async (req, res) => {
    try {
      // req.user is set by auth middleware
      if (!req.user?.id) {
        return res.status(401).json({ error: 'Not authenticated' });
      }
      
      const user = await db.query.users.findFirst({
        where: eq(users.id, req.user.id)
      });
      
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      // Don't return the password
      const { password, ...userData } = user;
      
      res.json(userData);
    } catch (error) {
      console.error('Get user error:', error);
      res.status(500).json({ error: error.message });
    }
  },

  updateProfile: async (req, res) => {
    try {
      // req.user is set by auth middleware
      if (!req.user?.id) {
        return res.status(401).json({ error: 'Not authenticated' });
      }
      
      const { name } = req.body;
      
      if (!name) {
        return res.status(400).json({ error: 'Name is required' });
      }
      
      // Update the user in the database
      const [updatedUser] = await db.update(users)
        .set({ name })
        .where(eq(users.id, req.user.id))
        .returning();
      
      if (!updatedUser) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      // Don't return the password
      const { password, ...userData } = updatedUser;
      
      res.json({ user: userData });
    } catch (error) {
      console.error('Update profile error:', error);
      res.status(500).json({ error: error.message });
    }
  },

  logout: async (req, res) => {
    try {
      // Clear session
      req.session.destroy();
      
      // Clear cookie
      res.clearCookie('auth_token');
      
      res.json({ success: true, message: 'Logged out successfully' });
    } catch (error) {
      console.error('Logout error:', error);
      res.status(500).json({ error: error.message });
    }
  },
  
  checkSession: async (req, res) => {
    if (req.session.userId) {
      try {
        const user = await db.query.users.findFirst({
          where: eq(users.id, req.session.userId)
        });
        
        if (user) {
          const { password, ...userData } = user;
          return res.json({ isLoggedIn: true, user: userData });
        }
      } catch (err) {
        console.error('Session check error:', err);
      }
    }
    
    res.json({ isLoggedIn: false });
  }
};

module.exports = authController;