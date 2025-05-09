/**
 * Cross-platform bcrypt wrapper that falls back to bcryptjs if native bcrypt is unavailable
 */
let bcrypt;

try {
  // Try to use the native bcrypt module first (faster)
  bcrypt = require('bcrypt');
  console.log('Using native bcrypt module');
} catch (err) {
  // Fall back to pure JS implementation
  try {
    bcrypt = require('bcryptjs');
    console.log('Using bcryptjs module (pure JS implementation)');
  } catch (e) {
    console.error('ERROR: Neither bcrypt nor bcryptjs is installed. Please run: npm install bcryptjs');
    // Create minimal API to prevent crashes, but operations will fail
    bcrypt = {
      genSalt: () => Promise.reject(new Error('bcrypt not available')),
      hash: () => Promise.reject(new Error('bcrypt not available')),
      compare: () => Promise.reject(new Error('bcrypt not available'))
    };
  }
}

module.exports = bcrypt;
