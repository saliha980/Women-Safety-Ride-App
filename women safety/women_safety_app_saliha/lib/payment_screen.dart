import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to open top-up dialog
  void _showAddMoneyDialog(DocumentReference userDocRef) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Money to Wallet"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the amount you wish to deposit:"),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Amount (Rs.)",
                prefixText: "Rs. ",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              double? amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid amount")),
                );
                return;
              }

              Navigator.pop(ctx);

              try {
                // Increment wallet balance in Firestore
                await userDocRef.set({
                  'walletBalance': FieldValue.increment(amount),
                }, SetOptions(merge: true));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Successfully added Rs. ${amount.toStringAsFixed(2)}!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error adding money: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("ADD"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Payments")),
        body: const Center(child: Text("Please log in to view wallet.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payments", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE91E63),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // Determine whether user is in 'users_data' or 'riders_data'
        future: _firestore
            .collection('women_safety_data')
            .doc('users_data')
            .collection('profiles')
            .doc(currentUser.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
          }

          bool isUserDoc = snapshot.hasData && snapshot.data!.exists;

          DocumentReference userDocRef = isUserDoc
              ? _firestore
                  .collection('women_safety_data')
                  .doc('users_data')
                  .collection('profiles')
                  .doc(currentUser.uid)
              : _firestore
                  .collection('women_safety_data')
                  .doc('riders_data')
                  .collection('profiles')
                  .doc(currentUser.uid);

          return StreamBuilder<DocumentSnapshot>(
            stream: userDocRef.snapshots(),
            builder: (context, walletSnapshot) {
              if (walletSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
              }

              double walletBalance = 0.0;
              bool hasUsedFirstRideDiscount = false;

              if (walletSnapshot.hasData && walletSnapshot.data!.exists) {
                var data = walletSnapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  if (data.containsKey('walletBalance')) {
                    walletBalance = (data['walletBalance'] as num).toDouble();
                  }
                  hasUsedFirstRideDiscount = data['hasUsedFirstRideDiscount'] ?? false;
                }
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text("Wallet Balance", style: TextStyle(color: Colors.white, fontSize: 18)),
                        const SizedBox(height: 10),
                        Text(
                          "Rs. ${walletBalance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Promotional indicator widget inside Payment section
                  if (!hasUsedFirstRideDiscount)
                    Container(
                      width: double.infinity,
                      color: Colors.pink.shade50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: const [
                          Icon(Icons.local_offer, color: Color(0xFFE91E63)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "First Ride Offer Available: 20% OFF will automatically apply to your next trip!",
                              style: TextStyle(
                                color: Color(0xFFC2185B),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet, color: Colors.purple),
                      title: const Text("Add Money"),
                      onTap: () => _showAddMoneyDialog(userDocRef),
                    ),
                  ),
                  const Divider(),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.credit_card, color: Colors.purple),
                      title: const Text("Linked Cards"),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Linked Cards coming soon!")),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}