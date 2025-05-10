import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/paper_trading_provider.dart';

class CreatePaperPortfolioScreen extends StatefulWidget {
  const CreatePaperPortfolioScreen({Key? key}) : super(key: key);

  @override
  _CreatePaperPortfolioScreenState createState() => _CreatePaperPortfolioScreenState();
}

class _CreatePaperPortfolioScreenState extends State<CreatePaperPortfolioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _balanceController = TextEditingController();
  
  bool _isSubmitting = false;
  String? _errorMessage;
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _balanceController.dispose();
    super.dispose();
  }
  
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final initialBalance = double.parse(_balanceController.text);
    
    try {
      final success = await Provider.of<PaperTradingProvider>(context, listen: false)
          .createPaperPortfolio(name, description.isNotEmpty ? description : null, initialBalance);
      
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = 'Failed to create paper portfolio';
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
        title: Text('Create Paper Portfolio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Portfolio Name',
                  hintText: 'E.g. My Paper Trading',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'E.g. My practice portfolio for learning',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                decoration: InputDecoration(
                  labelText: 'Initial Balance (NPR)',
                  hintText: 'E.g. 100000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an initial balance';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Balance must be greater than 0';
                  }
                  return null;
                },
              ),
              
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              
              SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text('Create Portfolio'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}