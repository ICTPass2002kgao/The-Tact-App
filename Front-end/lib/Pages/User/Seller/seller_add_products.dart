import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class SellerAddProductTab extends StatefulWidget {
  final String userId;
  final bool isVerified;
  final Map<String, dynamic> userData;

  const SellerAddProductTab({
    super.key,
    required this.userId,
    required this.isVerified,
    required this.userData,
  });

  @override
  State<SellerAddProductTab> createState() => _SellerAddProductTabState();
}

class _SellerAddProductTabState extends State<SellerAddProductTab> {
  final priceController = TextEditingController();
  final locationController = TextEditingController();
  List<String> _selectedColors = [];
  List<String> _selectedSizes = [];
  String? _selectedSizeType;

  // Data Lists (Same as before)
  final List<String> _colors = ['Black', 'White', 'Grey', 'Red', 'Blue', 'Green', 'Yellow'];
  final List<String> _sizesStd = ['S', 'M', 'L', 'XL', 'XXL'];
  final List<String> _sizeTypes = ['Standard Sizes', 'Numeric Sizes', 'Suit Sizes'];

  Future<void> addProduct(String prodId, String name, String desc, dynamic img) async {
    if(priceController.text.isEmpty || locationController.text.isEmpty) {
        Api().showMessage(context, "Fill Price & Location", "Error", Colors.red); return;
    }
    // ... (Backend Add Logic maintained from previous iterations)
    try {
        await FirebaseFirestore.instance.collection('seller_products').add({
            'productId': prodId,
            'sellerId': widget.userId,
            'price': double.parse(priceController.text),
            'location': locationController.text,
            'productName': name,
            'imageUrl': (img is List) ? img[0] : img,
            'availableColors': _selectedColors,
            'availableSizes': _selectedSizes,
            // ... add other fields needed by backend
            'views': 0,
            'createdAt': FieldValue.serverTimestamp(),
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Published!")));
    } catch(e) { print(e); }
  }

  void _openAddModal(Map<String, dynamic> data, String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Text("Sell ${data['name']}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Responsive Row for inputs
                      LayoutBuilder(builder: (ctx, constraints) {
                        return constraints.maxWidth > 600 
                        ? Row(children: [
                            Expanded(child: NeumorphicUtils.buildTextField(controller: priceController, placeholder: "Price", prefixIcon: Icons.attach_money, context: context, keyboardType: TextInputType.number)),
                            const SizedBox(width: 15),
                            Expanded(child: NeumorphicUtils.buildTextField(controller: locationController, placeholder: "Location", prefixIcon: Icons.pin_drop, context: context)),
                          ])
                        : Column(children: [
                            NeumorphicUtils.buildTextField(controller: priceController, placeholder: "Price", prefixIcon: Icons.attach_money, context: context, keyboardType: TextInputType.number),
                            NeumorphicUtils.buildTextField(controller: locationController, placeholder: "Location", prefixIcon: Icons.pin_drop, context: context),
                          ]);
                      }),
                      const SizedBox(height: 20),
                      // Simplified Selectors for brevity in UI
                      _buildSelector("Colors", _colors, _selectedColors, (v) => setStateModal(() => _selectedColors.contains(v) ? _selectedColors.remove(v) : _selectedColors.add(v))),
                      const SizedBox(height: 20),
                      _buildSelector("Sizes", _sizesStd, _selectedSizes, (v) => setStateModal(() => _selectedSizes.contains(v) ? _selectedSizes.remove(v) : _selectedSizes.add(v))),
                      const SizedBox(height: 30),
                      GestureDetector(
                        onTap: () => addProduct(id, data['name'], data['desc']??'', data['imageUrl']),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: NeumorphicUtils.decoration(context: context).copyWith(color: Theme.of(context).primaryColor),
                          child: const Center(child: Text("PUBLISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelector(String title, List<String> opts, List<String> selected, Function(String) toggle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: opts.map((o) {
            final isSel = selected.contains(o);
            return GestureDetector(
                onTap: () => toggle(o),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: NeumorphicUtils.decoration(context: context, isPressed: isSel, radius: 8).copyWith(color: isSel ? Theme.of(context).primaryColor.withOpacity(0.1) : null),
                    child: Text(o, style: TextStyle(fontSize: 12, color: isSel ? Theme.of(context).primaryColor : null, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                ),
            );
        }).toList())
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVerified) return const Center(child: Text("Pending Verification"));
    
    // Using Grid on Desktop for Product List
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('products').get(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isDesktop 
            ? GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.5, mainAxisSpacing: 15, crossAxisSpacing: 15),
                itemCount: docs.length,
                itemBuilder: (c, i) => _buildAddCard(docs[i], i),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (c, i) => _buildAddCard(docs[i], i),
              ),
          ),
        );
      },
    );
  }

  Widget _buildAddCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final accent = NeumorphicUtils.getAccentColor(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: NeumorphicUtils.decoration(context: context, isDark: Theme.of(context).brightness == Brightness.dark),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 5, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)))),
            const SizedBox(width: 10),
            CircleAvatar(backgroundImage: NetworkImage(data['imageUrl'] is List ? data['imageUrl'][0] : data['imageUrl']), radius: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.add_circle), color: accent, onPressed: () => _openAddModal(data, doc.id))
          ],
        ),
      ),
    );
  }
}