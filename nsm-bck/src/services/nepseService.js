const axios = require('axios');

const ENDPOINTS = {
  GAINERS: 'https://nepse-top-gainers.onrender.com/api/gainers',
  LIVE_TRADING: 'https://nepse-top-gainers.onrender.com/api/live-trading',
  INDICES: 'https://nepse-top-gainers.onrender.com/api/indices',
  COMPANY_DETAILS: 'https://nepse-top-gainers.onrender.com/api/company' // New endpoint
};

const nepseService = {
  getTopGainers: async () => {
    try {
      const response = await axios.get(ENDPOINTS.GAINERS);
      return response.data;
    } catch (error) {
      console.error('Error fetching top gainers:', error.message);
      throw error;
    }
  },

  getLiveTrading: async () => {
    try {
      const response = await axios.get(ENDPOINTS.LIVE_TRADING);
      return response.data;
    } catch (error) {
      console.error('Error fetching live trading data:', error.message);
      throw error;
    }
  },

  getIndices: async () => {
    try {
      const response = await axios.get(ENDPOINTS.INDICES);
      return response.data;
    } catch (error) {
      console.error('Error fetching indices data:', error.message);
      throw error;
    }
  },

  getCompanyDetails: async (symbol) => {
    try {
      if (!symbol) {
        throw new Error('Symbol is required');
      }
      
      const response = await axios.get(`${ENDPOINTS.COMPANY_DETAILS}/${symbol}`);
      return response.data;
    } catch (error) {
      console.error(`Error fetching details for company ${symbol}:`, error.message);
      throw error;
    }
  }
};

module.exports = nepseService;