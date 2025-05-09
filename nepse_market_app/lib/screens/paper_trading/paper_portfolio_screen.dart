import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:your_app/providers/paper_trading_provider.dart';

class PaperPortfolioScreen extends StatefulWidget {
  final String portfolioId;

  const PaperPortfolioScreen({Key? key, required this.portfolioId}) : super(key: key);

  @override
  _PaperPortfolioScreenState createState() => _PaperPortfolioScreenState();
}

class _PaperPortfolioScreenState extends State<PaperPortfolioScreen> {
  // Add this method to display a fix button when needed
  Widget _buildFixBalanceButton(BuildContext context, PaperTradingProvider provider) {
    // Only show the button if there's an error that suggests balance issues
    final errorMsg = provider.errorMessage;
    if (errorMsg == null || 
        (!errorMsg.contains('balance') && !errorMsg.contains('invalid'))) {
      return SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Issue Detected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your portfolio balance appears to be in an invalid format. This can happen due to database inconsistencies.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: provider.isLoading ? null : () async {
                final success = await provider.fixBalanceIssue(widget.portfolioId);
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Portfolio balance fixed successfully!')),
                  );
                }
              },
              child: provider.isLoading 
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Fix Portfolio Balance'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaperTradingProvider>(
      builder: (context, provider, _) {
        List<Widget> children = [];

        // Add the fix balance button near the error message display
        if (provider.errorMessage != null) {
          // Add the fix button below the error message
          children.add(_buildFixBalanceButton(context, provider));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Paper Portfolio'),
          ),
          body: ListView(
            children: children,
          ),
        );
      },
    );
  }
}