import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BrokerInfoScreen extends StatefulWidget {
  const BrokerInfoScreen({Key? key}) : super(key: key);

  @override
  _BrokerInfoScreenState createState() => _BrokerInfoScreenState();
}

class _BrokerInfoScreenState extends State<BrokerInfoScreen> {
  List<Map<String, dynamic>> _brokers = [];
  List<Map<String, dynamic>> _filteredBrokers = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadBrokers();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrokers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // This is placeholder data. In a real app, you would fetch from your API
      await Future.delayed(Duration(seconds: 1));
      
      _brokers = [
        {
          'id': 1,
          'name': 'Bhrikuti Stock Broking Co. Pvt. Ltd.',
          'number': '01',
          'phone': '01-4535351',
          'address': 'Kamaladi, Kathmandu',
          'email': 'bhrikutisharecentre@gmail.com',
          'website': 'https://bhrikutisecurities.com',
        },
        {
          'id': 2,
          'name': 'Market Securities Exchange',
          'number': '02',
          'phone': '01-4224549',
          'address': 'Anamnagar, Kathmandu',
          'email': 'market@wlink.com.np',
          'website': 'http://www.marketsecurities.com.np',
        },
        {
          'id': 3,
          'name': 'Nepal Stock House',
          'number': '03',
          'phone': '01-4247530',
          'address': 'Putalisadak, Kathmandu',
          'email': 'nepalstockhouse@gmail.com',
          'website': 'https://www.nepalstockhouse.com.np',
        },
        {
          'id': 4,
          'name': 'Arun Securities',
          'number': '04',
          'phone': '01-4222529',
          'address': 'Putalisadak, Kathmandu',
          'email': 'arunsecu@gmail.com',
          'website': 'https://www.arunsecurities.com.np',
        },
        {
          'id': 5,
          'name': 'Malla & Malla Stock Broking',
          'number': '05',
          'phone': '01-4782675',
          'address': 'Kuleshwor-14, Kathmandu',
          'email': 'mallabroker@gmail.com',
          'website': 'https://www.mallasecurities.com.np',
        },
        {
          'id': 6,
          'name': 'Dynamic Money Managers Securities',
          'number': '06',
          'phone': '01-4113073',
          'address': 'Kantipath, Kathmandu',
          'email': 'dmmsecurities@gmail.com',
          'website': 'https://www.dmmsnepal.com.np',
        },
      ];
      
      setState(() {
        _filteredBrokers = List.from(_brokers);
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load broker data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterBrokers(String query) {
    setState(() {
      _filteredBrokers = _brokers
          .where((broker) => 
              broker['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
              broker['number'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _copyToClipboard(String text, String type) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$type copied to clipboard')),
    );
  }

  void _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $urlString')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Broker Information'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name or number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: _filterBrokers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _filteredBrokers.isEmpty
                        ? Center(child: Text('No brokers found'))
                        : ListView.builder(
                            itemCount: _filteredBrokers.length,
                            itemBuilder: (context, index) {
                              final broker = _filteredBrokers[index];
                              return Card(
                                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    child: Text(broker['number']),
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  title: Text(
                                    broker['name'],
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildInfoRow(Icons.phone, broker['phone'], 'Phone', () {
                                            _copyToClipboard(broker['phone'], 'Phone number');
                                          }),
                                          _buildInfoRow(Icons.location_on, broker['address'], 'Address', () {
                                            _copyToClipboard(broker['address'], 'Address');
                                          }),
                                          _buildInfoRow(Icons.email, broker['email'], 'Email', () {
                                            _copyToClipboard(broker['email'], 'Email');
                                          }),
                                          _buildInfoRow(Icons.web, broker['website'], 'Website', () {
                                            _copyToClipboard(broker['website'], 'Website');
                                            _launchURL(broker['website']);
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 18),
            onPressed: onTap,
            tooltip: 'Copy $label',
          ),
        ],
      ),
    );
  }
}