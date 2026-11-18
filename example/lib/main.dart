import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:suggestion_input_field/suggestion_input_field.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suggestion Input Field',
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const MyHomePage(title: 'Suggestion Input Field'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Customer? selectedCustomer;

  /// Stands in for a database or API.
  static final List<Customer> _allCustomers = List.generate(
    20,
    (index) => Customer(
      id: 'C${index + 1}',
      name: 'Customer ${index + 1}',
      mobile: '555-555-${(1000 + index).toString()}',
    ),
  );

  Future<List<Customer>> fetchCustomerData(String filterText) async {
    // Simulate network latency.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _allCustomers
        .where((c) => c.name.toLowerCase().contains(filterText.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton(
                onPressed: () => setState(() => selectedCustomer = null),
                child: const Text('Clear customer from outside'),
              ),
              TextButton(
                onPressed: () => setState(
                  () => selectedCustomer = Customer(
                    id: '100',
                    name: 'Outside Customer',
                    mobile: '555-555-5555',
                  ),
                ),
                child: const Text('Set customer from outside'),
              ),
              SuggestionTextField<Customer>(
                value: selectedCustomer,
                debounceDuration: const Duration(milliseconds: 250),
                suggestionFetch: (textEditingValue) =>
                    fetchCustomerData(textEditingValue.text),
                textFieldContent: const TextFieldContent(
                  decoration: InputDecoration(labelText: 'Select Customer'),
                ),
                displayStringForOption: (option) => option.name,
                itemBuilder: (customer) => ListTile(
                  title: Text(customer.name),
                  subtitle: Text(customer.mobile),
                ),
                onSelected: (option) =>
                    setState(() => selectedCustomer = option),
                // The user edited the text away from the selected customer.
                onSelectionCleared: () =>
                    setState(() => selectedCustomer = null),
                // The clear button was tapped.
                onClose: () => setState(() => selectedCustomer = null),
              ),
              const SizedBox(height: 16),
              Text('Selected: ${selectedCustomer?.name ?? 'none'}'),
            ],
          ),
        ),
      ),
    );
  }
}

class Customer {
  final String id;
  final String name;
  final String mobile;
  Customer({required this.id, required this.name, required this.mobile});
}
