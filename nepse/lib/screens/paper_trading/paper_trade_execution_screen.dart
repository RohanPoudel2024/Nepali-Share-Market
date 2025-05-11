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
    final theme = Theme.of(context);
    final formatter = NumberFormat("#,##0.00", "en_US");
    final paperTradingProvider = Provider.of<PaperTradingProvider>(context);
    final portfolio = paperTradingProvider.getPortfolio(widget.portfolioId);
    final isBuy = _selectedType == 'Buy';
    final tradeTotal = _calculateTradeTotal();
    double? newBalance;
    if (portfolio != null && (_quantityController.text.isNotEmpty && _priceController.text.isNotEmpty)) {
      newBalance = isBuy
        ? (portfolio.currentBalance - tradeTotal)
        : (portfolio.currentBalance + tradeTotal);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Execute Paper Trade'),
        backgroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(18),
          child: Center(
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trade Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedType == 'Buy' ? Colors.green[600] : Colors.grey[200],
                                foregroundColor: _selectedType == 'Buy' ? Colors.white : Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: () => setState(() => _selectedType = 'Buy'),
                              child: Text('Buy'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedType == 'Sell' ? Colors.red[600] : Colors.grey[200],
                                foregroundColor: _selectedType == 'Sell' ? Colors.white : Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: () => setState(() => _selectedType = 'Sell'),
                              child: Text('Sell'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 22),
                      Text('Stock Symbol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 8),
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<String>.empty();
                          }
                          return _availableSymbols.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        initialValue: TextEditingValue(text: _symbolController.text),
                        onSelected: (String selection) {
                          _symbolController.text = selection;
                          _loadStockData(selection);
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Enter or select symbol',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              suffixIcon: _isLoadingStockData ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              ) : null,
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Symbol required' : null,
                            onChanged: (val) {
                              _symbolController.text = val;
                              _loadStockData(val);
                              setState(() {}); // update new balance
                            },
                          );
                        },
                      ),
                      SizedBox(height: 18),
                      if (_stockData != null)
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[400], size: 18),
                            SizedBox(width: 6),
                            Text('Current Price: रु ${formatter.format(_stockData!['currentPrice'] ?? 0)}', style: TextStyle(fontSize: 13, color: Colors.blue[700])),
                          ],
                        ),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                SizedBox(height: 8),
                                TextFormField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 10',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (value) {
                                    final qty = double.tryParse(value ?? '');
                                    if (qty == null || qty <= 0) return 'Enter valid quantity';
                                    return null;
                                  },
                                  onChanged: (_) => setState(() {}), // update new balance
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    SizedBox(width: 4),
                                    Checkbox(
                                      value: _useCurrentPrice,
                                      onChanged: (val) {
                                        setState(() {
                                          _useCurrentPrice = val ?? true;
                                          if (_useCurrentPrice && _stockData != null) {
                                            _priceController.text = (_stockData!['currentPrice'] ?? '').toString();
                                          }
                                        });
                                      },
                                    ),
                                    Text('Current', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 500',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (value) {
                                    final price = double.tryParse(value ?? '');
                                    if (price == null || price <= 0) return 'Enter valid price';
                                    return null;
                                  },
                                  onChanged: (_) => setState(() {}), // update new balance
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.orange[700], size: 18),
                          SizedBox(width: 6),
                          Text('Total: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('रु ${formatter.format(tradeTotal)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.primaryColor)),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        SizedBox(height: 14),
                        Text(_errorMessage!, style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                      ],
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedType == 'Buy' ? Colors.green[700] : Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isExecuting ? null : _executeTrade,
                          child: _isExecuting
                              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(_selectedType == 'Buy' ? 'Buy' : 'Sell'),
                        ),
                      ),
                      if (newBalance != null && _quantityController.text.isNotEmpty && _priceController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet, size: 18, color: newBalance >= (portfolio?.currentBalance ?? 0) ? Colors.green : Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Balance after trade: ',
                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                              Text(
                                'रु ${formatter.format(newBalance)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: newBalance >= (portfolio?.currentBalance ?? 0) ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}