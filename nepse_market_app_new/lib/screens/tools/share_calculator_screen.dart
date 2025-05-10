import 'package:flutter/material.dart';

class ShareCalculatorScreen extends StatefulWidget {
  @override
  _ShareCalculatorScreenState createState() => _ShareCalculatorScreenState();
}

class _ShareCalculatorScreenState extends State<ShareCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  
  double _quantity = 0;
  double _buyPrice = 0;
  double _sellPrice = 0;
  
  // Results
  double _investmentAmount = 0;
  double _returnAmount = 0;
  double _profitLoss = 0;
  double _profitLossPercentage = 0;
  double _seboCommission = 0;
  double _brokerCommission = 0;
  double _dpFee = 25; // Fixed DP fee in NPR
  double _netProfitLoss = 0;
  
  void _calculateResults() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _quantity = double.parse(_quantityController.text);
      _buyPrice = double.parse(_buyPriceController.text);
      _sellPrice = double.parse(_sellPriceController.text);
      
      // Calculate investment amount
      _investmentAmount = _quantity * _buyPrice;
      
      // Calculate return amount
      _returnAmount = _quantity * _sellPrice;
      
      // Calculate profit/loss before fees
      _profitLoss = _returnAmount - _investmentAmount;
      
      // Calculate profit/loss percentage
      _profitLossPercentage = (_profitLoss / _investmentAmount) * 100;
      
      // Calculate SEBON commission (0.015% on both buy and sell)
      _seboCommission = (_investmentAmount * 0.00015) + (_returnAmount * 0.00015);
      
      // Calculate broker commission (varies based on transaction amount)
      _brokerCommission = _calculateBrokerCommission(_investmentAmount) + 
                         _calculateBrokerCommission(_returnAmount);
      
      // Calculate net profit/loss after all fees
      _netProfitLoss = _profitLoss - _seboCommission - _brokerCommission - _dpFee;
    });
  }
  
  double _calculateBrokerCommission(double amount) {
    // Nepse broker commission slabs as per new rules
    if (amount <= 50000) {
      return amount * 0.004; // 0.4%
    } else if (amount <= 500000) {
      return amount * 0.0037; // 0.37%
    } else if (amount <= 2000000) {
      return amount * 0.0034; // 0.34%
    } else if (amount <= 10000000) {
      return amount * 0.003; // 0.30%
    } else {
      return amount * 0.0027; // 0.27%
    }
  }
  
  @override
  void dispose() {
    _quantityController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Calculator'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calculate Profit/Loss',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Please enter a valid quantity';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _buyPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Buy Price (Rs.)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.price_change),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter buy price';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _sellPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Sell Price (Rs.)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.price_check),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter sell price';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _calculateResults,
                        child: Text('Calculate'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            if (_investmentAmount > 0) _buildResultsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    bool isProfit = _netProfitLoss >= 0;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(height: 30),
            _buildResultRow('Investment Amount', 'Rs. ${_investmentAmount.toStringAsFixed(2)}'),
            _buildResultRow('Return Amount', 'Rs. ${_returnAmount.toStringAsFixed(2)}'),
            _buildResultRow('Gross Profit/Loss', 'Rs. ${_profitLoss.toStringAsFixed(2)}', 
                       color: _profitLoss >= 0 ? Colors.green : Colors.red),
            _buildResultRow('Profit/Loss %', '${_profitLossPercentage.toStringAsFixed(2)}%', 
                       color: _profitLossPercentage >= 0 ? Colors.green : Colors.red),
            Divider(height: 30),
            Text('Fees & Charges:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _buildResultRow('SEBON Commission', 'Rs. ${_seboCommission.toStringAsFixed(2)}'),
            _buildResultRow('Broker Commission', 'Rs. ${_brokerCommission.toStringAsFixed(2)}'),
            _buildResultRow('DP Fee', 'Rs. ${_dpFee.toStringAsFixed(2)}'),
            Divider(height: 30),
            _buildResultRow('Net Profit/Loss', 'Rs. ${_netProfitLoss.toStringAsFixed(2)}',
                      color: isProfit ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color, FontWeight? fontWeight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: fontWeight ?? FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}