import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

// Add these imports
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class IpoResultScreen extends StatefulWidget {
  @override
  _IpoResultScreenState createState() => _IpoResultScreenState();
}

class _IpoResultScreenState extends State<IpoResultScreen> {
  final _dio = Dio();
  final _searchController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _currentIpos = [];
  List<Map<String, dynamic>> _upcomingIpos = [];
  List<Map<String, dynamic>> _pastIpos = [];
  
  // Result checking
  String _boid = '';
  Map<String, dynamic>? _resultData;
  bool _checkingResult = false;
  bool _isBoidSaved = false;
  
  // WebView controller
  WebViewController? _webViewController;
  bool _webViewLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadIpoData();
    _loadSavedBoid();
    
    // Initialize WebView - simplified approach
    _initializeWebView();
  }
  
  void _initializeWebView() {
    if (kIsWeb) {
      setState(() {
        _errorMessage = 'WebView is not supported on web platform';
      });
      return;
    }
    
    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() => _webViewLoading = true);
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() => _webViewLoading = false);
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _webViewLoading = false;
                  _errorMessage = 'WebView error: ${error.description}';
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse('https://iporesult.cdsc.com.np/'));
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing WebView: $e';
      });
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSavedBoid() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBoid = prefs.getString('saved_boid');
    if (savedBoid != null && savedBoid.isNotEmpty) {
      setState(() {
        _boid = savedBoid;
        _searchController.text = savedBoid;
        _isBoidSaved = true;
      });
    }
  }
  
  Future<void> _saveBoid() async {
    if (_boid.length == 16) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_boid', _boid);
      setState(() {
        _isBoidSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BOID saved successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 16-digit BOID')),
      );
    }
  }
  
  Future<void> _clearSavedBoid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_boid');
    setState(() {
      _isBoidSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved BOID removed')),
    );
  }

  Future<void> _loadIpoData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // This is a placeholder. In a real app, you would fetch from your API
      await Future.delayed(Duration(seconds: 1));
      
      _currentIpos = [
        {
          'company': 'Nepal Bank Ltd.',
          'type': 'Right Share',
          'price': 100,
          'units': 10000000,
          'openDate': '2025-05-01',
          'closeDate': '2025-05-15',
          'id': 'nbl-right',
        },
        {
          'company': 'Himalayan Bank Ltd.',
          'type': 'IPO',
          'price': 100,
          'units': 5000000,
          'openDate': '2025-04-25',
          'closeDate': '2025-05-10',
          'id': 'hbl-ipo',
        },
      ];
      
      _upcomingIpos = [
        {
          'company': 'NIC Asia Bank',
          'type': 'FPO',
          'price': 100,
          'units': 15000000,
          'openDate': '2025-05-20',
          'closeDate': '2025-06-05',
          'id': 'nica-fpo',
        },
        {
          'company': 'Nepal Life Insurance',
          'type': 'Right Share',
          'price': 100,
          'units': 8000000,
          'openDate': '2025-05-25',
          'closeDate': '2025-06-10',
          'id': 'nli-right',
        },
      ];
      
      _pastIpos = [
        {
          'company': 'Global IME Bank',
          'type': 'IPO',
          'price': 100,
          'units': 10000000,
          'openDate': '2025-03-01',
          'closeDate': '2025-03-15',
          'result': 'Announced',
          'id': 'global-ipo',
        },
        {
          'company': 'Nabil Bank',
          'type': 'Right Share',
          'price': 100,
          'units': 12000000,
          'openDate': '2025-02-15',
          'closeDate': '2025-03-01',
          'result': 'Announced',
          'id': 'nabil-right',
        },
      ];
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load IPO data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIpoResult() async {
    if (_boid.isEmpty || _boid.length != 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 16-digit BOID')),
      );
      return;
    }
    
    setState(() {
      _checkingResult = true;
      _resultData = null;
    });
    
    try {
      // This is a placeholder. In a real app, you would check against your API
      await Future.delayed(Duration(seconds: 1));
      
      // Simulate an allotment for demo purposes (50% chance)
      bool isAllotted = DateTime.now().millisecondsSinceEpoch % 2 == 0;
      
      if (isAllotted) {
        _resultData = {
          'allotted': true,
          'company': 'Global IME Bank',
          'units': 10,
          'appliedUnits': 20,
        };
      } else {
        _resultData = {
          'allotted': false,
          'company': 'Global IME Bank',
        };
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking result: $e')),
      );
    } finally {
      setState(() {
        _checkingResult = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IPO Results'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).primaryColor,
                        tabs: [
                          Tab(text: 'Check Result'),
                          Tab(text: 'Current'),
                          Tab(text: 'Upcoming'),
                          Tab(text: 'Past'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildCheckResultTab(),
                            _buildIpoListTab(_currentIpos, 'Current Issues'),
                            _buildIpoListTab(_upcomingIpos, 'Upcoming Issues'),
                            _buildIpoListTab(_pastIpos, 'Past Issues'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCheckResultTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check IPO Result',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _boid = value;
                      });
                    },
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                    decoration: InputDecoration(
                      labelText: 'Enter your BOID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card),
                      helperText: 'Enter your 16-digit BOID number',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_boid.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.copy),
                              tooltip: 'Copy BOID',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _boid));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('BOID copied to clipboard')),
                                );
                              },
                            ),
                          if (_boid.length == 16)
                            IconButton(
                              icon: Icon(_isBoidSaved ? Icons.bookmark : Icons.bookmark_border),
                              tooltip: _isBoidSaved ? 'BOID Saved' : 'Save BOID',
                              onPressed: _isBoidSaved ? _clearSavedBoid : _saveBoid,
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _checkingResult ? null : _checkIpoResult,
                          child: _checkingResult
                              ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Text('Check Result'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                          ),
                        ),
                      ),
                      if (_boid.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _boid = '';
                            });
                          },
                          tooltip: 'Clear',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          if (_resultData != null) _buildResultCard(),
          
          // Updated WebView Card with proper error handling
          Card(
            margin: EdgeInsets.only(top: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'CDSC IPO Result Portal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  height: 500,
                  child: _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _webViewController == null
                      ? Center(child: Text('WebView not available on this platform'))
                      : Stack(
                          children: [
                            WebViewWidget(controller: _webViewController!),
                            if (_webViewLoading)
                              Center(
                                child: CircularProgressIndicator(),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Result',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('BOID: $_boid'),
            SizedBox(height: 8),
            Text('Company: ${_resultData!['company']}'),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _resultData!['allotted'] ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _resultData!['allotted'] ? Colors.green : Colors.red,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _resultData!['allotted'] ? 'Congratulations!' : 'Better luck next time!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _resultData!['allotted'] ? Colors.green : Colors.red,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _resultData!['allotted']
                        ? 'You have been allotted ${_resultData!['units']} units out of ${_resultData!['appliedUnits']} applied units.'
                        : 'You have not been allotted any units in this issue.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpoListTab(List<Map<String, dynamic>> ipos, String title) {
    if (ipos.isEmpty) {
      return Center(child: Text('No $title available'));
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: ipos.length,
      itemBuilder: (context, index) {
        final ipo = ipos[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ipo['company'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ipo['type'],
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildIpoDetailRow('Price:', 'Rs. ${ipo['price']}'),
                _buildIpoDetailRow('Units:', '${ipo['units']}'),
                _buildIpoDetailRow('Open Date:', '${ipo['openDate']}'),
                _buildIpoDetailRow('Close Date:', '${ipo['closeDate']}'),
                if (ipo['result'] != null) _buildIpoDetailRow('Result:', '${ipo['result']}'),
                SizedBox(height: 16),
                if (title == 'Current Issues')
                  ElevatedButton(
                    onPressed: () {
                      // Open apply for IPO screen
                    },
                    child: Text('Apply Now'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                if (title == 'Past Issues' && ipo['result'] == 'Announced')
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        DefaultTabController.of(context).index = 0;
                      });
                    },
                    child: Text('Check Result'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIpoDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}