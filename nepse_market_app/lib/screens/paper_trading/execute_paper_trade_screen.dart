import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/paper_trading_provider.dart';
import 'package:nepse_market_app/providers/market_provider.dart';

class ExecutePaperTradeScreen extends StatefulWidget {
  final int portfolioId;
  
  const ExecutePaperTradeScreen({
    Key? key,
    required this.portfolioId,
  }) : super(key: key);

  @override
  _ExecutePaperTradeScreenState createState() => _ExecutePaperTradeScreenState();
}

class _ExecutePaperTradeScreenState extends State<ExecutePaperTradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  
  String _tradeType = 'BUY';
  bool _isSubmitting = false;
  bool _useMarketPrice = true;
  String? _errorMessage;
  List<String> _symbolSuggestions = [];
  double? _currentMarketPrice;
  
  @override
  void initState() {
    super.initState();
    _loadSymbols();
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
    await marketProvider.loadLiveTrading();
    
    setState(() {
      _symbolSuggestions = marketProvider.liveTrading
          .map((stock) => stock.symbol)
          .toList();
    });
  }
  
  void _updateMarketPrice() {
    final symbol = _symbolController.text.trim().toUpperCase();
    
    if (symbol.isNotEmpty && _symbolSuggestions.contains(symbol)) {
      try {
        final marketProvider = Provider.of<MarketProvider>(context, listen: false);
        final price = marketProvider.getStockPrice(symbol);
        
        setState(() {
          _currentMarketPrice = price;
          if (_useMarketPrice) {
            _priceController.text = price.toString();
          }
        });
      } catch (e) {
        setState(() {
          _currentMarketPrice = null;
        });
      }
    } else {
      setState(() {
        _currentMarketPrice = null;
      });
    }
  }

  Future<void> _executeTrade() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    
    final symbol = _symbolController.text.trim().toUpperCase();
    final quantity = double.parse(_quantityController.text);
    final price = _useMarketPrice ? null : double.parse(_priceController.text);
    
    try {
      final success = await Provider.of<PaperTradingProvider>(context, listen: false)
          .executePaperTrade(
            widget.portfolioId,
            symbol,
            _tradeType,
            quantity,
            price,
          );
      
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = 'Failed to execute trade. Please try again.';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Execute Paper Trade'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Trade type selection
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('Buy'),
                      value: 'BUY',
                      groupValue: _tradeType,
                      onChanged: (value) {
                        setState(() {
                          _tradeType = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('Sell'),
                      value: 'SELL',
                      groupValue: _tradeType,
                      onChanged: (value) {
                        setState(() {
                          _tradeType = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Symbol field with autocomplete
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _symbolSuggestions.where((symbol) {
                    return symbol.contains(textEditingValue.text.toUpperCase());
                  });
                },
                onSelected: (String selection) {
                  _symbolController.text = selection;
                  _updateMarketPrice();
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController controller,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  _symbolController.text = controller.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (value) {
                      _updateMarketPrice();
                    },
                    decoration: InputDecoration(
                      labelText: 'Symbol',
                      hintText: 'E.g. NABIL',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a stock symbol';
                      }
                      if (!_symbolSuggestions.contains(value.toUpperCase())) {
                        return 'Please enter a valid stock symbol';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.characters,
                  );
                },
              ),
              
              if (_currentMarketPrice != null)
                Padding(
                  padding: EdgeInsets.only(top: 8, left: 8),
                  child: Text(
                    'Current Market Price: Rs. ${_currentMarketPrice!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
              SizedBox(height: 16),
              
              // Quantity field
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'E.g. 10',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the quantity';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Quantity must be greater than 0';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Use market price checkbox
              CheckboxListTile(
                title: Text('Use current market price'),
                value: _useMarketPrice,
                onChanged: (value) {
                  setState(() {
                    _useMarketPrice = value ?? true;
                    if (_useMarketPrice && _currentMarketPrice != null) {
                      _priceController.text = _currentMarketPrice.toString();
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              
              SizedBox(height: 8),
              
              // Price field
              TextFormField(
                controller: _priceController,
                enabled: !_useMarketPrice,
                decoration: InputDecoration(
                  labelText: 'Price per Share',
                  hintText: 'E.g. 1000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (!_useMarketPrice) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the price';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) <= 0) {
                      return 'Price must be greater than 0';
                    }
                  }
                  return null;
                },
              ),
              
              // Error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).errorColor),
                  ),
                ),
              
              SizedBox(height: 24),
              
              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _executeTrade,
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text('Execute ${_tradeType.toLowerCase()} Trade'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _tradeType == 'BUY' ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}