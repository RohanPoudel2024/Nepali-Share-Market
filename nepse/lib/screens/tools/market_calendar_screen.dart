import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MarketCalendarScreen extends StatefulWidget {
  @override
  _MarketCalendarScreenState createState() => _MarketCalendarScreenState();
}

class _MarketCalendarScreenState extends State<MarketCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // This is placeholder data. In a real app, you would fetch from your API
      await Future.delayed(Duration(milliseconds: 800));
      
      _events = [
        {
          'title': 'Book Closure - NTC',
          'date': DateTime(2025, 5, 10),
          'type': 'book_closure',
          'company': 'Nepal Telecom',
          'description': 'Book closure for 20% dividend',
        },
        {
          'title': 'AGM - NABIL',
          'date': DateTime(2025, 5, 15),
          'type': 'agm',
          'company': 'Nabil Bank Ltd.',
          'description': 'Annual General Meeting for FY 2023-24',
          'venue': 'Hotel Yak & Yeti, Kathmandu',
          'time': '11:00 AM',
        },
        {
          'title': 'IPO Issue - GBIME',
          'date': DateTime(2025, 5, 5),
          'type': 'ipo',
          'company': 'Global IME Bank Ltd.',
          'description': 'IPO Issue of 10,000,000 units',
        },
        {
          'title': 'Right Share Issue - NLI',
          'date': DateTime(2025, 5, 25),
          'type': 'right',
          'company': 'Nepal Life Insurance',
          'description': '1:1 Right Share Issue',
        },
        {
          'title': 'Dividend Distribution - NIFRA',
          'date': DateTime(2025, 5, 20),
          'type': 'dividend',
          'company': 'Nepal Infrastructure Bank',
          'description': 'Distribution of 15% cash dividend',
        },
        {
          'title': 'Book Closure - NICA',
          'date': DateTime(2025, 6, 5),
          'type': 'book_closure',
          'company': 'NIC Asia Bank',
          'description': 'Book closure for 18% dividend',
        },
      ];
      
      _filterEventsByMonth();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load events: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterEventsByMonth() {
    setState(() {
      _filteredEvents = _events.where((event) => 
        event['date'].year == _selectedDate.year && 
        event['date'].month == _selectedDate.month
      ).toList();
      
      _filteredEvents.sort((a, b) => a['date'].compareTo(b['date']));
    });
  }
  
  Color _getEventColor(String type) {
    switch (type) {
      case 'book_closure':
        return Colors.purple;
      case 'agm':
        return Colors.blue;
      case 'ipo':
        return Colors.green;
      case 'right':
        return Colors.orange;
      case 'dividend':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'book_closure':
        return Icons.book;
      case 'agm':
        return Icons.groups;
      case 'ipo':
        return Icons.monetization_on;
      case 'right':
        return Icons.add_chart;
      case 'dividend':
        return Icons.account_balance_wallet;
      default:
        return Icons.event;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Market Calendar'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    _buildMonthPicker(),
                    Expanded(child: _buildEventsList()),
                  ],
                ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                _filterEventsByMonth();
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedDate),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                _filterEventsByMonth();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    if (_filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No events this month',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _filteredEvents.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final event = _filteredEvents[index];
        final eventDate = event['date'] as DateTime;
        final isToday = eventDate.year == DateTime.now().year && 
                         eventDate.month == DateTime.now().month && 
                         eventDate.day == DateTime.now().day;
        
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showEventDetails(context, event),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: isToday ? Theme.of(context).primaryColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('dd').format(eventDate),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(eventDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: isToday ? Colors.white : Colors.black87,
                          ),
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
                            Icon(
                              _getEventIcon(event['type']),
                              size: 16,
                              color: _getEventColor(event['type']),
                            ),
                            SizedBox(width: 8),
                            Text(
                              event['type'].toString().toUpperCase(),
                              style: TextStyle(
                                color: _getEventColor(event['type']),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          event['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          event['company'],
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEventDetails(BuildContext context, Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getEventIcon(event['type']),
                    color: _getEventColor(event['type']),
                  ),
                  SizedBox(width: 12),
                  Text(
                    event['title'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildDetailRow('Date', DateFormat('EEEE, MMMM d, yyyy').format(event['date'])),
              _buildDetailRow('Company', event['company']),
              _buildDetailRow('Description', event['description']),
              if (event['venue'] != null) _buildDetailRow('Venue', event['venue']),
              if (event['time'] != null) _buildDetailRow('Time', event['time']),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Add to calendar functionality would go here
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Event reminder set')),
                  );
                },
                child: Text('Add to Calendar'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}