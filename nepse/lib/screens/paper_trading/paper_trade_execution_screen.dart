import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/market_provider.dart';
import 'package:nepse_market_app/providers/paper_trading_provider.dart';
import 'package:intl/intl.dart';

class PaperTradeExecutionScreen extends StatefulWidget {
  final int portfolioId;
  final String? preSelectedSymbol;
  
  const PaperTradeExecutionScreen({
    Key? key, 
    required this.portfolioId,
    this.preSelectedSymbol,
  }) : super(key: key);

  @override
  _PaperTradeExecutionScreenState createState() => _PaperTradeExecutionScreenState();
}

class _PaperTradeExecutionScreenState extends State<PaperTradeExecutionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _symbolController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  String _selectedType = 'Buy';
  bool _isExecuting = false;
  String? _errorMessage;
  bool _useCurrentPrice = true;
  List<String> _availableSymbols = [];
  DateTime _lastPriceUpdate = DateTime.now();
  
  // Stock data for chart
  Map<String, dynamic>? _stockData;
  bool _isLoadingStockData = false;
  List<FlSpot> _pricePoints = [];
  
  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(text: widget.preSelectedSymbol ?? '');
    _quantityController = TextEditingController();
    _priceController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Force refresh at startup to ensure we have latest data
      final provider = Provider.of<PaperTradingProvider>(context, listen: false);
      await provider.forcePaperPortfolioRefresh(widget.portfolioId);
      
      _loadSymbols();
      
      if (widget.preSelectedSymbol != null) {
        _loadStockData(widget.preSelectedSymbol!);
      }
    });
  }
  
  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadSymbols() async {
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);
    
    // Load live trading stocks to get available symbols
    await marketProvider.loadLiveTrading();
    
    if (!mounted) return;
    
    setState(() {
      _availableSymbols = marketProvider.liveTrading
        .map((stock) => stock.symbol)
        .toList();
    });
  }
  
  Future<void> _loadStockData(String symbol) async {
    if (symbol.isEmpty) return;
    
    setState(() {
      _isLoadingStockData = true;
      _stockData = null;
    });
    
    try {
      final marketProvider = Provider.of<MarketProvider>(context, listen: false);
      
      // Get current price and update price controller
      final currentPrice = marketProvider.getStockPrice(symbol);
      if (currentPrice != null && _useCurrentPrice) {
        _priceController.text = currentPrice.toString();
      }
      
      if (!mounted) return;
      
      // Simplified stock data without historical chart
      setState(() {
        _stockData = {
          'symbol': symbol,
          'currentPrice': currentPrice ?? 0.0,
        };
        _isLoadingStockData = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingStockData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load stock data: $e')),
      );
    }
  }

  double _calculateTradeTotal() {
    try {
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      final price = double.tryParse(_priceController.text) ?? 0;
      
      // Use proper rounding to avoid floating point errors
      return (quantity * price * 100).round() / 100;
    } catch (e) {
      print('Error calculating trade total: $e');
      return 0;
    }
  }

  Future<void> _executeTrade() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isExecuting = true;
      _errorMessage = null;
    });
    
    try {
      final paperTradingProvider = Provider.of<PaperTradingProvider>(context, listen: false);
      
      // Verify the portfolio has a valid balance
      final portfolio = paperTradingProvider.getPortfolio(widget.portfolioId);
      
      // CRITICAL FIX: Check for valid balance before executing trade
      if (portfolio.currentBalance.isNaN || 
          portfolio.currentBalance.isInfinite ||
          portfolio.currentBalance < 0) {
        // Portfolio has invalid balance, try to fix it
        final repaired = await paperTradingProvider.fixBalanceIssue(widget.portfolioId);
        
        if (!repaired) {
          setState(() {
            _errorMessage = 'Portfolio has invalid balance. Please try again later.';
            _isExecuting = false;
          });
          return;
        }
      }
      
      // Proceed with trade using VALIDATED numbers only
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      if (quantity <= 0) {
        setState(() {
          _errorMessage = 'Please enter a valid quantity';
          _isExecuting = false;
        });
        return;
      }
      
      final price = double.tryParse(_priceController.text) ?? 0;
      if (price <= 0) {
        setState(() {
          _errorMessage = 'Please enter a valid price';
          _isExecuting = false;
        });
        return;
      }
      
      final success = await paperTradingProvider.executePaperTrade(
        widget.portfolioId,
        _symbolController.text.trim(),
        _selectedType,
        quantity,
        price,
      );
      
      if (!mounted) return;
      
      // After successful trade execution
      if (success) {
        // Ensure data is refreshed before returning
        setState(() {
          _errorMessage = 'Trade successful! Refreshing portfolio...';
        });
        
        // Force a fresh reload of data from server
        await paperTradingProvider.forcePaperPortfolioRefresh(widget.portfolioId);
        
        Navigator.pop(context, true);
      } else {
        final errorMessage = paperTradingProvider.errorMessage;
        
        // Check if this is a balance format error that we can help recover from
        if (errorMessage != null && 
            (errorMessage.contains('invalid') || errorMessage.contains('repair'))) {
          // Show a dialog offering to fix the balance
          _showBalanceRepairDialog(paperTradingProvider);
        } else {
          setState(() {
            _errorMessage = errorMessage ?? 'Failed to execute trade';
            _isExecuting = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = e.toString();
        _isExecuting = false;
      });
    }
  }
  
  void _showBalanceRepairDialog(PaperTradingProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Portfolio Balance Issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your portfolio balance appears to be in an invalid format.'),
              SizedBox(height: 8),
              Text('Would you like to automatically repair it?'),
              SizedBox(height: 16),
              Text(
                'Note: This will recalculate your balance based on your initial deposit and trade history.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isExecuting = false;
                  _errorMessage = "Portfolio balance needs repair. Please try the 'Repair Balance' option.";
                });
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                setState(() {
                  _errorMessage = 'Repairing portfolio balance...';
                });
                
                // Attempt to fix the balance
                final success = await provider.fixBalanceIssue(widget.portfolioId);
                
                if (!mounted) return;
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Portfolio balance repaired successfully!'))
                  );
                  
                  setState(() {
                    _errorMessage = null;
                    _isExecuting = false;
                  });
                  
                  // Retry the trade
                  _executeTrade();
                } else {
                  setState(() {
                    _errorMessage = 'Failed to repair portfolio balance. Please try again later.';
                    _isExecuting = false;
                  });
                }
              },
              child: Text('Repair Balance'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildBalanceSummary(dynamic portfolio, double tradeTotal) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    final isBuy = _selectedType == 'Buy';
    final remainingBalance = isBuy 
        ? (portfolio.currentBalance - tradeTotal)
        : (portfolio.currentBalance + tradeTotal);
    
    // Show warning if buy order would result in negative balance
    final isInsufficientFunds = isBuy && remainingBalance < 0;
    
    // For sell orders, calculate potential profit/loss if we have the stock data
    Widget? profitLossSection;
  
    if (!isBuy && _symbolController.text.isNotEmpty) {
      try {
        // Get current holding details if available
        final holding = portfolio.holdings.firstWhere(
          (h) => h.symbol == _symbolController.text,
        );
        
        final quantity = double.tryParse(_quantityController.text) ?? 0;
        final sellPrice = double.tryParse(_priceController.text) ?? 0;
        
        // Calculate trade profit/loss
        if (quantity > 0 && sellPrice > 0) {
          final profitPerShare = sellPrice - holding.averageBuyPrice;
          final totalProfit = profitPerShare * quantity;
          final profitPercent = holding.averageBuyPrice > 0 
              ? (profitPerShare / holding.averageBuyPrice) * 100 
              : 0.0;
          
          final isProfit = totalProfit >= 0;
          
          profitLossSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Avg. Buy Price:'),
                  Text('Rs. ${formatter.format(holding.averageBuyPrice)}'),
                ],
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profit/Loss:'),
                  Text(
                    '${isProfit ? '+' : ''}Rs. ${formatter.format(totalProfit)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isProfit ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Return:'),
                  Text(
                    '${isProfit ? '+' : ''}${profitPercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isProfit ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ],
          );
        }
      } catch (e) {
        print('Error calculating sell profit: $e');
      }
    }
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(top: 16, bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isInsufficientFunds 
          ? BorderSide(color: Colors.red, width: 1)
          : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trade Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Balance:'),
                Text(
                  'Rs. ${formatter.format(portfolio.currentBalance)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trade Amount:'),
                Text(
                  'Rs. ${formatter.format(tradeTotal)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBuy ? Colors.red[700] : Colors.green[700],
                  ),
                ),
              ],
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Balance After Trade:'),
                Text(
                  'Rs. ${formatter.format(remainingBalance)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remainingBalance >= 0 ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ],
            ),
            
            // Add profit/loss section for sell orders
            if (profitLossSection != null) profitLossSection,
            
            // Show warning if insufficient funds
            if (isInsufficientFunds)
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient funds for this trade',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = Provider.of<PaperTradingProvider>(context).getPortfolio(widget.portfolioId);
    final tradeTotal = _calculateTradeTotal();
    final formatter = NumberFormat("#,##0.00", "en_US");
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Paper Trade Execution'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (_symbolController.text.isNotEmpty) {
                _loadStockData(_symbolController.text.trim());
              }
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portfolio summary card
            if (portfolio != null)
              Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Balance',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            'Rs. ${formatter.format(portfolio.currentBalance)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
            // Stock chart and info section
            if (_stockData != null && !_isLoadingStockData)
              Card(
                elevation: 3,
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stock title and current price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _symbolController.text,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs. ${formatter.format(_stockData!['currentPrice'])}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Divider(height: 24),
                      
                      // Simple stock info instead of chart
                      Text(
                        'Current Market Price',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use this price for your paper trade or enter a custom price below.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            if (_isLoadingStockData)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading stock data...'),
                    ],
                  ),
                ),
              ),
              
            // Trade execution form
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trade Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Symbol field
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _availableSymbols.where((symbol) {
                            return symbol.contains(textEditingValue.text.toUpperCase());
                          });
                        },
                        onSelected: (String selection) {
                          _symbolController.text = selection;
                          _loadStockData(selection);
                        },
                        fieldViewBuilder: (
                          BuildContext context,
                          TextEditingController controller,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          _symbolController = controller;
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Stock Symbol',
                              hintText: 'E.g. NABIL',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.search),
                                onPressed: () {
                                  _loadStockData(controller.text.trim());
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a stock symbol';
                              }
                              return null;
                            },
                            textCapitalization: TextCapitalization.characters,
                          );
                        },
                      ),
                      SizedBox(height: 16),
                      
                      // Trade type toggle - Better styled
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedType = 'Buy'),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedType == 'Buy' 
                                      ? Colors.green.withOpacity(0.2) 
                                      : Colors.transparent,
                                    borderRadius: BorderRadius.horizontal(
                                      left: Radius.circular(7),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'BUY',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _selectedType == 'Buy' 
                                          ? Colors.green[800] 
                                          : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedType = 'Sell'),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedType == 'Sell' 
                                      ? Colors.red.withOpacity(0.2) 
                                      : Colors.transparent,
                                    borderRadius: BorderRadius.horizontal(
                                      right: Radius.circular(7),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'SELL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _selectedType == 'Sell' 
                                          ? Colors.red[800] 
                                          : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Quantity field
                      TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          hintText: 'Enter number of shares',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a quantity';
                          }
                          try {
                            final quantity = double.parse(value);
                            if (quantity <= 0) {
                              return 'Quantity must be greater than zero';
                            }
                          } catch (e) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          // Update state to recalculate trade total
                          setState(() {});
                        },
                      ),
                      SizedBox(height: 16),
                      
                      // Price field
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Price (Rs.)',
                          hintText: 'Price per share',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.attach_money),
                          enabled: !_useCurrentPrice,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a price';
                          }
                          try {
                            final price = double.parse(value);
                            if (price <= 0) {
                              return 'Price must be greater than zero';
                            }
                          } catch (e) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          // Update state to recalculate trade total
                          setState(() {});
                        },
                      ),
                      
                      // Use current price checkbox
                      CheckboxListTile(
                        title: Text('Use current market price'),
                        value: _useCurrentPrice,
                        onChanged: (value) {
                          setState(() {
                            _useCurrentPrice = value ?? true;
                            if (_useCurrentPrice && _stockData != null) {
                              _priceController.text = _stockData!['currentPrice'].toString();
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                      
                      // Trade summary
                      if (portfolio != null)
                        _buildBalanceSummary(portfolio, tradeTotal),
                      
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                      SizedBox(height: 24),
                      
                      // Execute button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isExecuting ? null : _executeTrade,
                          child: _isExecuting
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Execute ${_selectedType} Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedType == 'Buy' ? Colors.green[700] : Colors.red[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}