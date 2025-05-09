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
  
  // Order book simulation data
  List<Map<String, dynamic>> _buyOrders = [];
  List<Map<String, dynamic>> _sellOrders = [];
  
  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(text: widget.preSelectedSymbol ?? '');
    _quantityController = TextEditingController();
    _priceController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSymbols();
      
      if (widget.preSelectedSymbol != null) {
        _loadStockData(widget.preSelectedSymbol!);
      }
      
      // Start simulated price updates
      _simulatePriceUpdates();
    });
  }
  
  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }
  
  // Simulate real-time price updates
  void _simulatePriceUpdates() {
    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      
      if (_stockData != null && _stockData!['currentPrice'] != null) {
        setState(() {
          // Randomly tick the price up or down slightly
          final currentPrice = _stockData!['currentPrice'] as double;
          final change = (currentPrice * 0.0005) * (DateTime.now().second % 2 == 0 ? 1 : -1);
          _stockData!['currentPrice'] = currentPrice + change;
          _lastPriceUpdate = DateTime.now();
          
          // Update price field if using current price
          if (_useCurrentPrice) {
            _priceController.text = _stockData!['currentPrice'].toString();
          }
          
          // Update chart with new point
          if (_pricePoints.isNotEmpty) {
            final newSpot = FlSpot(_pricePoints.last.x + 0.1, currentPrice + change);
            _pricePoints = [..._pricePoints.skipWhile((spot) => spot.x < newSpot.x - 10), newSpot];
          }
          
          // Update order book
          _updateSimulatedOrderBook(currentPrice + change);
        });
      }
      
      // Continue simulation if still on screen
      _simulatePriceUpdates();
    });
  }
  
  void _updateSimulatedOrderBook(double currentPrice) {
    // Generate realistic order book
    _buyOrders = List.generate(5, (i) {
      final priceDiff = (i + 1) * 0.5;
      final price = currentPrice - priceDiff;
      return {
        'price': price,
        'quantity': (200 - (i * 25) + (DateTime.now().millisecond % 100)).toDouble(),
      };
    });
    
    _sellOrders = List.generate(5, (i) {
      final priceDiff = (i + 1) * 0.5;
      final price = currentPrice + priceDiff;
      return {
        'price': price,
        'quantity': (150 - (i * 20) + (DateTime.now().millisecond % 50)).toDouble(),
      };
    });
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
      _pricePoints = [];
    });
    
    try {
      final marketProvider = Provider.of<MarketProvider>(context, listen: false);
      
      // Get current price and update price controller
      final currentPrice = marketProvider.getStockPrice(symbol);
      if (currentPrice != null && _useCurrentPrice) {
        _priceController.text = currentPrice.toString();
      }
      
      // Load historical data if available
      await marketProvider.loadStockHistoricalData(symbol);
      
      if (!mounted) return;
      
      final historicalData = marketProvider.getStockHistoricalData(symbol);
      if (historicalData != null && historicalData.isNotEmpty) {
        // Convert historical data to chart points
        final points = <FlSpot>[];
        for (int i = 0; i < historicalData.length && i < 30; i++) {
          points.add(FlSpot(i.toDouble(), double.parse(historicalData[i]['close'].toString())));
        }
        
        setState(() {
          _stockData = {
            'symbol': symbol,
            'data': historicalData,
            'currentPrice': currentPrice,
          };
          _pricePoints = points;
          _isLoadingStockData = false;
          
          // Initialize order book with the current price
          if (currentPrice != null) {
            _updateSimulatedOrderBook(currentPrice);
          }
        });
      } else {
        // If no historical data, create a simple chart with the current price
        if (currentPrice != null) {
          setState(() {
            _stockData = {
              'symbol': symbol,
              'currentPrice': currentPrice,
            };
            _pricePoints = List.generate(10, (i) {
              // Generate slightly realistic price movement
              final basePrice = currentPrice;
              final change = (i % 3 == 0 ? 1 : -1) * (i / 20.0) * basePrice * 0.01;
              return FlSpot(i.toDouble(), basePrice + change);
            });
            _isLoadingStockData = false;
            
            // Initialize order book with the current price
            _updateSimulatedOrderBook(currentPrice);
          });
        } else {
          setState(() {
            _isLoadingStockData = false;
          });
        }
      }
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

  Future<void> _executeTrade() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isExecuting = true;
      _errorMessage = null;
    });
    
    final symbol = _symbolController.text.trim().toUpperCase();
    final quantity = double.parse(_quantityController.text);
    final price = _useCurrentPrice ? null : double.parse(_priceController.text);
    
    try {
      final paperTradingProvider = Provider.of<PaperTradingProvider>(context, listen: false);
      final success = await paperTradingProvider.executePaperTrade(
        widget.portfolioId,
        symbol,
        _selectedType,
        quantity,
        price,
      );
      
      if (!mounted) return;
      
      if (success) {
        // Ensure data is refreshed before returning
        await Future.delayed(Duration(milliseconds: 500));
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
                final success = await provider.fixPortfolioBalance(widget.portfolioId);
                
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
  
  double _calculateTradeTotal() {
    try {
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      final price = double.tryParse(_priceController.text) ?? 0;
      return quantity * price;
    } catch (_) {
      return 0;
    }
  }
  
  Widget _buildBalanceSummary(dynamic portfolio, double tradeTotal) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    final isBuy = _selectedType == 'Buy';
    final remainingBalance = isBuy 
        ? portfolio.currentBalance - tradeTotal 
        : portfolio.currentBalance + tradeTotal;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trade Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
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
              SizedBox(height: 4),
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
            ],
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final paperTradingProvider = Provider.of<PaperTradingProvider>(context);
    final portfolio = paperTradingProvider.selectedPaperPortfolio;
    final formatter = NumberFormat("#,##0.00", "en_US");
    final tradeTotal = _calculateTradeTotal();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Execute Paper Trade'),
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
                              Text(
                                'Updated: ${DateFormat('HH:mm:ss').format(_lastPriceUpdate)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Divider(height: 24),
                      
                      // Stock chart
                      Container(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: (_stockData!['currentPrice'] as double) * 0.01,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.withOpacity(0.15),
                                  strokeWidth: 1,
                                  dashArray: [5, 5],
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: false,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      formatter.format(value),
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _pricePoints,
                                isCurved: true,
                                color: Theme.of(context).primaryColor,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).primaryColor.withOpacity(0.3),
                                      Theme.of(context).primaryColor.withOpacity(0.0),
                                    ],
                                    stops: [0.5, 1.0],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                            minY: _pricePoints
                                .map((spot) => spot.y)
                                .reduce((a, b) => a < b ? a : b) * 0.995,
                            maxY: _pricePoints
                                .map((spot) => spot.y)
                                .reduce((a, b) => a > b ? a : b) * 1.005,
                          ),
                        ),
                      ),
                      
                      // Order book section - Professional trading vibe
                      SizedBox(height: 20),
                      Text(
                        'Order Book',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          // Buy orders
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('BUY', style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    )),
                                    Text('Qty', style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    )),
                                  ],
                                ),
                                Divider(height: 8),
                                ..._buyOrders.map((order) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatter.format(order['price']),
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      order['quantity'].toStringAsFixed(0),
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )).toList(),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          // Sell orders
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('SELL', style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    )),
                                    Text('Qty', style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    )),
                                  ],
                                ),
                                Divider(height: 8),
                                ..._sellOrders.map((order) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatter.format(order['price']),
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      order['quantity'].toStringAsFixed(0),
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )).toList(),
                              ],
                            ),
                          ),
                        ],
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